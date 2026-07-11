//go:build !android

package main

import "context"

// withPlatformInterface is a no-op on non-Android targets. On Windows the
// sing-box core creates and owns the wintun adapter itself (when the process has
// the privileges to do so); in the no-admin fallback the client uses a
// mixed/SOCKS inbound plus the Windows system proxy instead of a TUN, so no
// platform hooks are required here either.
func withPlatformInterface(ctx context.Context, _ *engine) context.Context {
	return ctx
}
