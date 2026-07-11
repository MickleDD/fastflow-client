module fastflow-daemon

go 1.22

// Windows-only helper service. Run `go mod tidy` (network required) to populate
// go.sum before the first build.
require golang.org/x/sys v0.20.0
