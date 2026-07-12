//go:build android

package main

// Android platform bridge.
//
// On Android the tunnel file descriptor is owned by the Java/Kotlin VpnService
// (VpnService.Builder.establish()). The core must not create its own TUN; it has
// to run over the descriptor handed down through SetTunFd. sing-box exposes this
// via platform.Interface, which we inject into the run context. The core reads
// it back with service.FromContext[platform.Interface].
//
// PLATFORM NETWORK MONITOR (Part 2)
// ---------------------------------
// Inside the VpnService sandbox the core cannot open the netlink sockets that
// route.NewNetworkManager normally uses to watch interfaces — that is what made
// NewNetworkManager panic. Instead the Kotlin NetworkStateMonitor observes
// ConnectivityManager and streams flat network state down through the JNI shim
// (libfastflow_jni.so) into the Netif* cgo exports in netif_export_android.go.
// Those exports feed the process-wide netifRegistry below, which backs both:
//
//   - UsePlatformInterfaceGetter  -> Interfaces()                (all networks)
//   - UsePlatformDefaultInterfaceMonitor -> CreateDefaultInterfaceMonitor()
//     -> androidInterfaceMonitor (the best underlying network + change callbacks)
//
// Upcalls go the other way: the shim hands Go two C function pointers via
// NetifRegisterPlatform — "protect" (VpnService.protect(fd) for upstream sockets)
// and "replay" (resend the full current state) — which we invoke through the
// ff_call_* trampolines in the cgo preamble. Go cannot call a C function pointer
// value directly, so the trampolines live here (a file WITHOUT //export, where
// preamble definitions are permitted) rather than in netif_export_android.go.
//
// NOTE ON VERSIONING: platform.Interface's method set tracks the sing-box
// release pinned in go.mod. When bumping sing-box, reconcile this type against
// experimental/libbox/platform/interface.go and the tun.DefaultInterfaceMonitor
// interface for that tag — added methods must be implemented here.

/*
#cgo CFLAGS: -I${SRCDIR}

#include "netif_bridge.h"

// Trampolines: Go cannot call a C function pointer value directly, so these tiny
// wrappers bounce the call into C. They are definitions, which cgo forbids in
// the preamble of a file that uses //export — hence they live here and NOT in
// netif_export_android.go. Both are NULL-safe: an engine bound before the shim
// registered its pointers simply no-ops (protect fails closed, replay skips).
static inline int32_t ff_call_protect(ff_protect_fn fn, int32_t fd) {
    return fn ? fn(fd) : -1;
}
static inline void ff_call_replay(ff_replay_fn fn) {
    if (fn) fn();
}
*/
import "C"

import (
	"context"
	"fmt"
	"net"
	"net/netip"
	"os"
	"strings"
	"sync"

	"github.com/sagernet/sing-box/adapter"
	"github.com/sagernet/sing-box/common/process"
	singconstant "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/experimental/libbox/platform"
	"github.com/sagernet/sing-box/option"
	tun "github.com/sagernet/sing-tun"
	"github.com/sagernet/sing/common/control"
	"github.com/sagernet/sing/common/logger"
	"github.com/sagernet/sing/common/x/list"
	"github.com/sagernet/sing/service"
)

func withPlatformInterface(ctx context.Context, e *engine) context.Context {
	return service.ContextWith[platform.Interface](ctx, &androidPlatform{engine: e})
}

// ── Flag bits (MUST mirror FF_NETIF_* in netif_bridge.h / FLAG_* in
//    NetworkStateMonitor.kt — change all three or none). ──────────────────────

const (
	flagWifi        uint32 = 1 << 0
	flagCellular    uint32 = 1 << 1
	flagEthernet    uint32 = 1 << 2
	flagBluetooth   uint32 = 1 << 3
	flagMetered     uint32 = 1 << 8
	flagConstrained uint32 = 1 << 9
	flagValidated   uint32 = 1 << 10
)

// noNetworkHandle mirrors FF_NETIF_NO_HANDLE: "no usable underlying network".
const noNetworkHandle int64 = -1

// defaultIfFlags is the net.Flags stamped on every interface we synthesize.
// ConnectivityManager only ever reports live, usable networks, so Up|Running is
// always true; Multicast keeps mDNS-style consumers happy. HardwareAddr and the
// exact broadcast/point-to-point bits are unknown over this bridge and unused by
// the core's auto-detect-interface path (which binds by index/name).
const defaultIfFlags net.Flags = net.FlagUp | net.FlagRunning | net.FlagMulticast

// netifSnapshot is a pure-Go copy of one FFNetworkInfo. The cgo exports build it
// (copying every borrowed C string) before handing control back to C, honouring
// the "copy, never retain" memory contract in netif_bridge.h.
type netifSnapshot struct {
	handle  int64
	ifIndex int
	mtu     int
	flags   uint32
	ifName  string
	addrs   string // comma-joined CIDRs
	dns     string // comma-joined IPs
}

// netifRegistry is the process-wide sink for platform network state. It is a
// singleton because the cgo exports are global C symbols that must always have a
// target, independent of whether an engine/monitor currently exists.
type netifRegistry struct {
	mu sync.RWMutex

	// Every tracked underlying (non-VPN) network, keyed by Android net handle.
	// Backs Interfaces() (the platform interface getter).
	ifaces map[int64]adapter.NetworkInterface

	// The current best underlying interface (nil = none). Backs the monitor's
	// DefaultInterface() and drives AutoDetectInterface route selection.
	defaultIface *control.Interface

	// Default-interface change callbacks the core registers through the monitor.
	callbacks list.List[tun.DefaultInterfaceUpdateCallback]

	// Set once by Initialize; lets us prod the core to re-read Interfaces() when
	// the platform interface set changes (the netlink NetworkUpdateMonitor that
	// normally does this is disabled on Android).
	networkManager adapter.NetworkManager

	// C function pointers handed over by the JNI shim through
	// NetifRegisterPlatform. Nil until the shim binds (proxy-only/dev).
	protect C.ff_protect_fn
	replay  C.ff_replay_fn
}

// netifReg is the singleton the cgo exports feed and the platform reads.
var netifReg = &netifRegistry{ifaces: make(map[int64]adapter.NetworkInterface)}

// ── State mutations (called from the cgo exports, on arbitrary Go threads) ────

func (r *netifRegistry) update(s netifSnapshot) {
	iface := buildNetworkInterface(s)
	r.mu.Lock()
	r.ifaces[s.handle] = iface
	nm := r.networkManager
	r.mu.Unlock()
	refreshInterfaces(nm)
}

func (r *netifRegistry) lost(handle int64) {
	r.mu.Lock()
	_, existed := r.ifaces[handle]
	delete(r.ifaces, handle)
	nm := r.networkManager
	r.mu.Unlock()
	if existed {
		refreshInterfaces(nm)
	}
}

// setDefault records the new best underlying interface (nil snapshot / no handle
// means "none") and fires the registered callbacks. When the incoming handle is
// still tracked we reuse its richer entry (addresses/MTU) rather than the sparse
// default-change payload.
func (r *netifRegistry) setDefault(s *netifSnapshot) {
	var next *control.Interface
	r.mu.Lock()
	if s != nil && s.handle != noNetworkHandle {
		if tracked, ok := r.ifaces[s.handle]; ok {
			ci := tracked.Interface // copy the embedded control.Interface
			next = &ci
		} else {
			next = &control.Interface{
				Index: s.ifIndex,
				Name:  s.ifName,
				MTU:   normalizeMTU(s.mtu),
				Flags: defaultIfFlags,
			}
		}
	}
	r.defaultIface = next
	nm := r.networkManager
	cbs := r.snapshotCallbacksLocked()
	r.mu.Unlock()

	refreshInterfaces(nm)
	for _, cb := range cbs {
		cb(next, 0)
	}
}

// reset drops every cached network (the platform monitor stopped). Callbacks are
// preserved — the core's monitor may outlive one platform monitor session — but
// they are notified that the default is now gone.
func (r *netifRegistry) reset() {
	r.mu.Lock()
	r.ifaces = make(map[int64]adapter.NetworkInterface)
	r.defaultIface = nil
	nm := r.networkManager
	cbs := r.snapshotCallbacksLocked()
	r.mu.Unlock()

	refreshInterfaces(nm)
	for _, cb := range cbs {
		cb(nil, 0)
	}
}

func (r *netifRegistry) setPlatform(protect C.ff_protect_fn, replay C.ff_replay_fn) {
	r.mu.Lock()
	r.protect = protect
	r.replay = replay
	r.mu.Unlock()
}

// ── Reads / upcalls (called from the core and the monitor) ────────────────────

func (r *netifRegistry) setNetworkManager(nm adapter.NetworkManager) {
	r.mu.Lock()
	r.networkManager = nm
	r.mu.Unlock()
}

func (r *netifRegistry) interfaces() []adapter.NetworkInterface {
	r.mu.RLock()
	defer r.mu.RUnlock()
	out := make([]adapter.NetworkInterface, 0, len(r.ifaces))
	for _, v := range r.ifaces {
		out = append(out, v)
	}
	return out
}

func (r *netifRegistry) currentDefault() *control.Interface {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.defaultIface
}

func (r *netifRegistry) registerCallback(cb tun.DefaultInterfaceUpdateCallback) *list.Element[tun.DefaultInterfaceUpdateCallback] {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.callbacks.PushBack(cb)
}

func (r *netifRegistry) unregisterCallback(e *list.Element[tun.DefaultInterfaceUpdateCallback]) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.callbacks.Remove(e)
}

// snapshotCallbacksLocked copies the callback list so we can invoke handlers
// outside r.mu (a handler that calls back into DefaultInterface()/RegisterCallback
// would otherwise deadlock). Caller must hold r.mu.
func (r *netifRegistry) snapshotCallbacksLocked() []tun.DefaultInterfaceUpdateCallback {
	if r.callbacks.Len() == 0 {
		return nil
	}
	out := make([]tun.DefaultInterfaceUpdateCallback, 0, r.callbacks.Len())
	for e := r.callbacks.Front(); e != nil; e = e.Next() {
		out = append(out, e.Value)
	}
	return out
}

// protectFd forwards a socket fd to VpnService.protect through the JNI shim. A
// failed protect MUST fail the dial (returning nil here would create a routing
// loop). Until the shim registers its pointer, protect is a no-op — acceptable
// only in proxy-only/dev builds where there is no tunnel to loop through.
func (r *netifRegistry) protectFd(fd int) error {
	r.mu.RLock()
	fn := r.protect
	r.mu.RUnlock()
	if fn == nil {
		return nil
	}
	if rc := C.ff_call_protect(fn, C.int32_t(fd)); rc != 0 {
		return fmt.Errorf("VpnService.protect(%d) failed: rc=%d", fd, int(rc))
	}
	return nil
}

// requestReplay asks the platform to resend its full current state, so the core's
// monitor never starts from an empty view (contract: ff_replay_fn). No-op until
// the shim binds; the platform pushes live updates as they arrive regardless.
func (r *netifRegistry) requestReplay() {
	r.mu.RLock()
	fn := r.replay
	r.mu.RUnlock()
	if fn != nil {
		C.ff_call_replay(fn)
	}
}

// ── Snapshot → sing-box type helpers ──────────────────────────────────────────

func refreshInterfaces(nm adapter.NetworkManager) {
	if nm != nil {
		_ = nm.UpdateInterfaces()
	}
}

func normalizeMTU(mtu int) int {
	if mtu <= 0 {
		return 1500
	}
	return mtu
}

func buildNetworkInterface(s netifSnapshot) adapter.NetworkInterface {
	return adapter.NetworkInterface{
		Interface: control.Interface{
			Index:     s.ifIndex,
			MTU:       normalizeMTU(s.mtu),
			Name:      s.ifName,
			Addresses: parsePrefixes(s.addrs),
			Flags:     defaultIfFlags,
		},
		Type:        interfaceTypeOf(s.flags),
		DNSServers:  splitNonEmpty(s.dns),
		Expensive:   s.flags&flagMetered != 0,
		Constrained: s.flags&flagConstrained != 0,
	}
}

func interfaceTypeOf(flags uint32) singconstant.InterfaceType {
	switch {
	case flags&flagWifi != 0:
		return singconstant.InterfaceTypeWIFI
	case flags&flagCellular != 0:
		return singconstant.InterfaceTypeCellular
	case flags&flagEthernet != 0:
		return singconstant.InterfaceTypeEthernet
	default:
		return singconstant.InterfaceTypeOther
	}
}

func parsePrefixes(csv string) []netip.Prefix {
	if csv == "" {
		return nil
	}
	parts := strings.Split(csv, ",")
	out := make([]netip.Prefix, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		if prefix, err := netip.ParsePrefix(p); err == nil {
			out = append(out, prefix)
		}
	}
	return out
}

func splitNonEmpty(csv string) []string {
	if csv == "" {
		return nil
	}
	parts := strings.Split(csv, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}

// ── The platform default-interface monitor ────────────────────────────────────

// androidInterfaceMonitor satisfies tun.DefaultInterfaceMonitor by delegating to
// the shared netifRegistry. It is deliberately thin: all state lives in the
// registry so the (global) cgo exports and the (per-run) monitor observe exactly
// the same view.
type androidInterfaceMonitor struct {
	registry *netifRegistry
	logger   logger.Logger
}

var _ tun.DefaultInterfaceMonitor = (*androidInterfaceMonitor)(nil)

func (m *androidInterfaceMonitor) Start() error {
	// Pull the full current state up from the platform so the engine doesn't
	// begin blind even though the monitor binds after the Kotlin monitor started.
	m.registry.requestReplay()
	return nil
}

func (m *androidInterfaceMonitor) Close() error { return nil }

func (m *androidInterfaceMonitor) DefaultInterface() *control.Interface {
	return m.registry.currentDefault()
}

// OverrideAndroidVPN / AndroidVPNEnabled are false: the Kotlin monitor only ever
// registers NOT_VPN callbacks, so our view already excludes the tunnel and there
// is no Android VPN for the core to reason about (mirrors libbox's platform
// monitor, which returns false unconditionally).
func (m *androidInterfaceMonitor) OverrideAndroidVPN() bool { return false }
func (m *androidInterfaceMonitor) AndroidVPNEnabled() bool  { return false }

func (m *androidInterfaceMonitor) RegisterCallback(
	callback tun.DefaultInterfaceUpdateCallback,
) *list.Element[tun.DefaultInterfaceUpdateCallback] {
	return m.registry.registerCallback(callback)
}

func (m *androidInterfaceMonitor) UnregisterCallback(
	element *list.Element[tun.DefaultInterfaceUpdateCallback],
) {
	m.registry.unregisterCallback(element)
}

// ── platform.Interface implementation ─────────────────────────────────────────

type androidPlatform struct {
	engine *engine
}

var _ platform.Interface = (*androidPlatform)(nil)

// Initialize is called by the router once at startup. We stash the network
// manager so interface-set changes can prod it to re-read Interfaces().
func (p *androidPlatform) Initialize(networkManager adapter.NetworkManager) error {
	netifReg.setNetworkManager(networkManager)
	return nil
}

// UsePlatformAutoDetectInterfaceControl tells the core to route socket-protect
// calls through AutoDetectInterfaceControl instead of trying to bind interfaces
// itself (which is not permitted inside a VpnService sandbox).
func (p *androidPlatform) UsePlatformAutoDetectInterfaceControl() bool { return true }

// AutoDetectInterfaceControl is the "protect" hook: every socket the core opens
// for the upstream connection is passed here so it bypasses the tunnel and does
// not loop back into the VPN. Forwarded through the JNI shim to
// VpnService.protect(fd); a failed protect is surfaced as an error (failing open
// would create a routing loop).
func (p *androidPlatform) AutoDetectInterfaceControl(fd int) error {
	return netifReg.protectFd(fd)
}

// OpenTun hands the core the descriptor established by VpnService rather than
// letting it open /dev/tun (which is impossible without root). The core keeps
// ownership of the Options (addresses, MTU, routes) it derived from the config.
func (p *androidPlatform) OpenTun(options *tun.Options, _ option.TunPlatformOptions) (tun.Tun, error) {
	fd := int(p.engine.tunFd.Load())
	if fd < 0 {
		return nil, os.ErrInvalid
	}
	options.FileDescriptor = fd
	return tun.New(*options)
}

// The core now takes its interface monitor and interface getter FROM us: the
// JNI-backed netifRegistry replaces the netlink monitor that route.NewNetworkManager
// cannot run inside the VpnService sandbox. Both flags MUST stay true while
// CreateDefaultInterfaceMonitor returns a non-nil monitor (returning true with a
// nil monitor is what made NewNetworkManager panic).
func (p *androidPlatform) UsePlatformDefaultInterfaceMonitor() bool { return true }
func (p *androidPlatform) UsePlatformInterfaceGetter() bool         { return true }

// CreateDefaultInterfaceMonitor returns the JNI-backed monitor. All state lives
// in the shared netifRegistry, so the monitor and the cgo exports stay in sync.
func (p *androidPlatform) CreateDefaultInterfaceMonitor(l logger.Logger) tun.DefaultInterfaceMonitor {
	return &androidInterfaceMonitor{registry: netifReg, logger: l}
}

// Interfaces backs the platform interface getter: the set of underlying networks
// the Kotlin monitor is currently reporting.
func (p *androidPlatform) Interfaces() ([]adapter.NetworkInterface, error) {
	return netifReg.interfaces(), nil
}

// UnderNetworkExtension is an iOS/NEPacketTunnel concept; false on Android.
func (p *androidPlatform) UnderNetworkExtension() bool { return false }
func (p *androidPlatform) IncludeAllNetworks() bool    { return false }

func (p *androidPlatform) ClearDNSCache() {}

func (p *androidPlatform) ReadWIFIState() adapter.WIFIState { return adapter.WIFIState{} }

// FindProcessInfo (process.Searcher): per-app routing by uid requires reading the
// Android proc table, which the Java side owns. Returning ErrInvalid tells the
// core process-based rules are unavailable through this bridge.
func (p *androidPlatform) FindProcessInfo(ctx context.Context, network string, source netip.AddrPort, destination netip.AddrPort) (*process.Info, error) {
	return nil, os.ErrInvalid
}

func (p *androidPlatform) SendNotification(*platform.Notification) error { return nil }
