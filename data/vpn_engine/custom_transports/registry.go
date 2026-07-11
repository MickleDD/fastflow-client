// Package custom_transports is the injection point ("soil") for proprietary
// transports that are not part of upstream sing-box.
//
// It is imported for its side effects by the engine wrapper:
//
//	import _ "vpnengine/custom_transports"
//
// Its init() runs before any config is parsed, so anything registered here is
// available to sing-box as if it were a built-in outbound/inbound. To add a
// future closed-source protocol you only touch this package and drop the
// implementation next to registry.go — the core wrapper, the FFI boundary and
// the Dart layers stay untouched, which is exactly what makes the transport
// "pluggable" at the compilation step.
package custom_transports

import (
	"context"
	"fmt"

	"github.com/sagernet/sing-box/adapter"
	"github.com/sagernet/sing-box/log"
	"github.com/sagernet/sing-box/option"
)

func errNotImplemented(tag string) error {
	return fmt.Errorf("custom_transports: outbound %q is a template and not implemented", tag)
}

// CustomTransportType is the "type" string a profile uses in the generated
// sing-box config to select this transport (outbound_builder.dart emits it).
const CustomTransportType = "custom-fastflow"

func init() {
	// Register the transport constructor into sing-box's outbound registry. Once
	// this runs, a config containing {"type":"custom-fastflow", ...} is accepted
	// by the core exactly like a native "vless" or "hysteria2" outbound.
	//
	// The real project supplies RegisterCustom* into the shared registry that the
	// engine builds with include.OutboundRegistry(); this template shows the
	// contract without pulling in a real dependency.
	registerPlaceholder()
}

// CustomOutboundOptions is the config schema for the proprietary transport. Add
// fields here and they become available as JSON keys in the generated config.
type CustomOutboundOptions struct {
	option.DialerOptions
	Server     string `json:"server"`
	ServerPort uint16 `json:"server_port"`
	Password   string `json:"password,omitempty"`
	// Obfuscation / handshake knobs specific to the proprietary protocol go here.
	Magic string `json:"magic,omitempty"`
}

// NewCustomOutbound is the constructor sing-box calls when it encounters a
// CustomTransportType outbound. Replace the body with the real dialer. It must
// return something satisfying adapter.Outbound (dial TCP/UDP, tag, network set).
func NewCustomOutbound(
	ctx context.Context,
	router adapter.Router,
	logger log.ContextLogger,
	tag string,
	options CustomOutboundOptions,
) (adapter.Outbound, error) {
	// TEMPLATE ONLY. The proprietary implementation:
	//   1. wraps options.DialerOptions into an upstream dialer,
	//   2. performs the custom handshake / obfuscation against options.Server,
	//   3. returns an adapter.Outbound whose DialContext yields an obfuscated conn.
	//
	// Returning an error keeps the template inert if a config ever references it
	// before the real code is dropped in. The real impl builds an
	// adapter.Outbound over options.DialerOptions and the custom handshake.
	_ = router // wired through to the real dialer
	_ = logger
	return nil, errNotImplemented(tag)
}

func registerPlaceholder() {
	// No-op in the template: registering a nil constructor would make the core
	// reject the type at parse time, which is worse than "unknown type". The real
	// package replaces this with the registry.Register call for its tag.
}
