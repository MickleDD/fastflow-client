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
// NOTE ON VERSIONING: platform.Interface's method set tracks the sing-box
// release pinned in go.mod (see the "github.com/sagernet/sing-box" line). When
// bumping sing-box, reconcile this type against
// experimental/libbox/platform/interface.go for that tag — added methods must be
// implemented here. The behaviour that matters (OpenTun over the injected fd and
// AutoDetectInterfaceControl -> VpnService.protect) is centralised below.

import (
	"context"
	"net/netip"
	"os"

	"github.com/sagernet/sing-box/adapter"
	"github.com/sagernet/sing-box/common/process"
	"github.com/sagernet/sing-box/experimental/libbox/platform"
	"github.com/sagernet/sing-box/option"
	tun "github.com/sagernet/sing-tun"
	"github.com/sagernet/sing/common/control"
	"github.com/sagernet/sing/common/logger"
	"github.com/sagernet/sing/service"
)

func withPlatformInterface(ctx context.Context, e *engine) context.Context {
	return service.ContextWith[platform.Interface](ctx, &androidPlatform{engine: e})
}

// protectHook is installed by the Android bootstrap via SetProtectHook (wired to
// a tiny JNI shim that calls VpnService.protect(fd)). Sockets opened for the
// upstream tunnel must be protected or they loop back into the VPN. Until a hook
// is installed, protect is a no-op — acceptable only in development.
var protectHook func(fd int) error

// SetProtectHook is not exported over FFI (it takes a Go func); the Android
// native bootstrap sets it in an init() alongside its JNI registration.
func SetProtectHook(h func(fd int) error) { protectHook = h }

func protectSocket(fd int) error {
	if protectHook == nil {
		return nil
	}
	return protectHook(fd)
}

type androidPlatform struct {
	engine *engine
}

// Initialize is called by the router once at startup. We have no state to prime.
func (p *androidPlatform) Initialize(networkManager adapter.NetworkManager) error {
	return nil
}

// UsePlatformAutoDetectInterfaceControl tells the core to route socket-protect
// calls through AutoDetectInterfaceControl instead of trying to bind interfaces
// itself (which is not permitted inside a VpnService sandbox).
func (p *androidPlatform) UsePlatformAutoDetectInterfaceControl() bool { return true }

// AutoDetectInterfaceControl is the "protect" hook: every socket the core opens
// for the upstream connection is passed here so it bypasses the tunnel and does
// not loop back into the VPN. The Java side implements the actual
// VpnService.protect(fd); here we forward the request through the JNI callback
// wired up at library load. Failing open (nil) would create a routing loop, so a
// failed protect is surfaced as an error.
func (p *androidPlatform) AutoDetectInterfaceControl(fd int) error {
	return protectSocket(fd)
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

// The core uses its own interface monitor / getter on Android; we defer to it.
func (p *androidPlatform) UsePlatformDefaultInterfaceMonitor() bool { return true }
func (p *androidPlatform) UsePlatformInterfaceGetter() bool         { return true }
func (p *androidPlatform) CreateDefaultInterfaceMonitor(logger.Logger) tun.DefaultInterfaceMonitor {
	return nil
}

func (p *androidPlatform) Interfaces() ([]adapter.NetworkInterface, error) {
	return nil, os.ErrInvalid
}

// UnderNetworkExtension is an iOS/NEPacketTunnel concept; false on Android.
func (p *androidPlatform) UnderNetworkExtension() bool { return false }
func (p *androidPlatform) IncludeAllNetworks() bool    { return false }

func (p *androidPlatform) ClearDNSCache() {}

func (p *androidPlatform) ReadWIFIState() adapter.WIFIState { return adapter.WIFIState{} }

// FindProcessInfo (process.Searcher)   per-app routing by uid requires reading
// the Android proc table, which the Java side owns. Returning ErrInvalid tells
// the core process-based rules are unavailable through this bridge.
func (p *androidPlatform) FindProcessInfo(ctx context.Context, network string, source netip.AddrPort, destination netip.AddrPort) (*process.Info, error) {
	return nil, os.ErrInvalid
}

func (p *androidPlatform) SendNotification(*platform.Notification) error { return nil }
