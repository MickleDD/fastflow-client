// Package main compiles to a C-shared library (libvpn_engine.so / vpn_engine.dll)
// consumed from Dart via FFI. It is a thin, thread-safe lifecycle wrapper around
// the sing-box core.
//
// FFI contract (must stay in sync with lib/data/vpn_engine/engine_controller.dart):
//
//	char* StartEngine(char* configJson)  -> heap string "SUCCESS" or "ERROR: <msg>"; caller must FreeString it.
//	void  StopEngine()                   -> stops the running instance, blocks until closed.
//	char* GetStatus()                    -> heap string: "stopped" | "starting" | "running" | "stopping" | "error".
//	char* GetEngineLastError()                 -> heap string with the last fatal error (or "").
//	char* GetStats()                     -> heap JSON string {"uplink":..,"downlink":..,"uplinkTotal":..,"downlinkTotal":..}.
//	void  SetTunFd(int fd)               -> Android only: file descriptor produced by VpnService.establish().
//	void  FreeString(char* ptr)          -> frees a string previously returned by this library.
//
// Build:
//
//	Android (per ABI):
//	  CGO_ENABLED=1 GOOS=android GOARCH=arm64 CC=$NDK/.../aarch64-linux-android21-clang \
//	    go build -buildmode=c-shared -o libvpn_engine.so .
//	Windows:
//	  CGO_ENABLED=1 GOOS=windows GOARCH=amd64 CC=x86_64-w64-mingw32-gcc \
//	    go build -buildmode=c-shared -o vpn_engine.dll .
package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"context"
	"fmt"
	"runtime/debug"
	"sync"
	"sync/atomic"
	"time"
	"unsafe"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/include"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing/common/json"

	// custom_transports is the "soil" for proprietary protocols. Its init()
	// registers any extra inbounds/outbounds into the sing-box registries before
	// a config is parsed. Importing it for side effects keeps the compilation
	// step aware of pluggable transports without touching the core wrapper.
	_ "vpnengine/custom_transports"
)

type engineStatus int32

const (
	statusStopped engineStatus = iota
	statusStarting
	statusRunning
	statusStopping
	statusError
)

func (s engineStatus) String() string {
	switch s {
	case statusStarting:
		return "starting"
	case statusRunning:
		return "running"
	case statusStopping:
		return "stopping"
	case statusError:
		return "error"
	default:
		return "stopped"
	}
}

// engine holds the single active sing-box instance. The VPN client only ever
// runs one tunnel at a time, so a package-level singleton guarded by a mutex is
// the simplest correct model.
type engine struct {
	mu        sync.Mutex
	instance  *box.Box
	cancel    context.CancelFunc
	status    atomic.Int32
	lastError atomic.Pointer[string]
	tunFd     atomic.Int32 // Android VpnService fd; -1 when unset.
	// traffic holds the most recent up/down meter snapshot. It is populated by
	// the optional v2ray statistics service (enabled from the config builder) and
	// read lock-free by GetStats. Nil until the first sample arrives.
	traffic atomic.Pointer[trafficSnapshot]
}

var eng = func() *engine {
	e := &engine{}
	e.status.Store(int32(statusStopped))
	e.tunFd.Store(-1)
	empty := ""
	e.lastError.Store(&empty)
	return e
}()

func (e *engine) setStatus(s engineStatus) { e.status.Store(int32(s)) }

func (e *engine) setError(err error) {
	msg := err.Error()
	e.lastError.Store(&msg)
	e.setStatus(statusError)
}

// start parses configJson, builds the sing-box instance and starts it. It is
// idempotent-safe: starting while already running returns an error instead of
// leaking the previous instance.
func (e *engine) start(configJson string) (err error) {
	e.mu.Lock()
	defer e.mu.Unlock()

	// Recover from any panic inside the core so a bad config can never take the
	// whole host process (and the Flutter UI) down with it.
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("engine panic: %v\n%s", r, debug.Stack())
			e.setError(err)
			e.forceCleanupLocked()
		}
	}()

	if e.instance != nil {
		return fmt.Errorf("engine already running")
	}
	e.setStatus(statusStarting)

	ctx, cancel := context.WithCancel(context.Background())
	// Register every built-in inbound/outbound/endpoint type. Custom transports
	// registered via the imported custom_transports package are already present
	// in these registries by the time we get here.
	ctx = box.Context(ctx, include.InboundRegistry(), include.OutboundRegistry(), include.EndpointRegistry())

	// Inject the Android platform hooks (TUN fd provider + "protect" control) so
	// the core can open a tunnel over the descriptor VpnService handed us. On
	// Windows this is nil and the core manages the wintun adapter itself.
	ctx = withPlatformInterface(ctx, e)

	options, err := json.UnmarshalExtendedContext[option.Options](ctx, []byte(configJson))
	if err != nil {
		cancel()
		wrapped := fmt.Errorf("parse config: %w", err)
		e.setError(wrapped)
		return wrapped
	}

	instance, err := box.New(box.Options{
		Context: ctx,
		Options: options,
	})
	if err != nil {
		cancel()
		wrapped := fmt.Errorf("create instance: %w", err)
		e.setError(wrapped)
		return wrapped
	}

	if err = instance.Start(); err != nil {
		_ = instance.Close()
		cancel()
		wrapped := fmt.Errorf("start instance: %w", err)
		e.setError(wrapped)
		return wrapped
	}

	e.instance = instance
	e.cancel = cancel
	empty := ""
	e.lastError.Store(&empty)
	e.setStatus(statusRunning)
	return nil
}

func (e *engine) stop() {
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.instance == nil {
		e.setStatus(statusStopped)
		return
	}
	e.setStatus(statusStopping)
	e.forceCleanupLocked()
	e.setStatus(statusStopped)
}

// forceCleanupLocked closes the instance and cancels its context. Callers must
// already hold e.mu.
func (e *engine) forceCleanupLocked() {
	if e.instance != nil {
		// Close is bounded so a hung core can't wedge the UI thread forever.
		done := make(chan struct{})
		inst := e.instance
		go func() {
			_ = inst.Close()
			close(done)
		}()
		select {
		case <-done:
		case <-time.After(5 * time.Second):
		}
		e.instance = nil
	}
	if e.cancel != nil {
		e.cancel()
		e.cancel = nil
	}
}

func (e *engine) statsJSON() string {
	// The clash-api / v2ray stats service (if enabled in the config) is the
	// authoritative source; here we expose a stable shape the Dart side can
	// decode even when stats are unavailable, so the UI never has to special-case.
	up, down := readTraffic(e)
	return fmt.Sprintf(
		`{"uplink":%d,"downlink":%d,"uplinkTotal":%d,"downlinkTotal":%d}`,
		up.rate, down.rate, up.total, down.total,
	)
}

//export StartEngine
func StartEngine(configJson *C.char) *C.char {
	jsonStr := C.GoString(configJson)
	if err := eng.start(jsonStr); err != nil {
		return C.CString("ERROR: " + err.Error())
	}
	return C.CString("SUCCESS")
}

//export StopEngine
func StopEngine() {
	eng.stop()
}

//export GetStatus
func GetStatus() *C.char {
	return C.CString(engineStatus(eng.status.Load()).String())
}

//export GetEngineLastError
func GetEngineLastError() *C.char {
	p := eng.lastError.Load()
	if p == nil {
		return C.CString("")
	}
	return C.CString(*p)
}

//export GetStats
func GetStats() *C.char {
	return C.CString(eng.statsJSON())
}

// SetTunFd is called from the Android side after VpnService.establish() returns
// a ParcelFileDescriptor. Pass -1 to clear it. Must be called BEFORE StartEngine.
//
//export SetTunFd
func SetTunFd(fd C.int) {
	eng.tunFd.Store(int32(fd))
}

// FreeString releases a string previously returned by any exported function.
// Every char* returned across the FFI boundary is allocated by C.CString and
// therefore owned by the caller; Dart must call this to avoid leaks.
//
//export FreeString
func FreeString(ptr *C.char) {
	if ptr != nil {
		C.free(unsafe.Pointer(ptr))
	}
}

// main is required for buildmode=c-shared but is never executed when the library
// is loaded by the host process; the exported functions are the real entry points.
func main() {}
