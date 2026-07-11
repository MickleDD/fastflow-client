module vpnengine

go 1.22

// Pinned sing-box release. The platform.Interface method set in
// platform_android.go is written against this tag — reconcile that file when
// bumping. After changing versions run `go mod tidy` (network required) to
// regenerate go.sum and the full transitive require set.
require (
	github.com/sagernet/sing v0.5.1
	github.com/sagernet/sing-box v1.11.0
	github.com/sagernet/sing-tun v0.6.0
)
