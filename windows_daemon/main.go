//go:build windows

// FastFlow VPN helper daemon.
//
// A tiny Windows service that runs elevated (LocalSystem) and performs the
// privileged operations the standard-user Flutter GUI cannot: default-block
// firewall kill switch and route table changes. The GUI talks to it over a
// named pipe (see lib/infrastructure/os_windows/daemon_ipc_client.dart).
//
// Security model:
//   - Transport is a named pipe (\\.\pipe\FastFlowHelper) with a restrictive
//     SDDL and PIPE_REJECT_REMOTE_CLIENTS — never reachable off-box, and the
//     first instance uses FILE_FLAG_FIRST_PIPE_INSTANCE to prevent name squatting.
//   - Each connection's owning process (from GetNamedPipeClientProcessId, no
//     port->PID race) must be the exact installed GUI image, carry a valid
//     Authenticode chain, and be signed by the expected publisher (verifyClient).
//   - A shared secret under %ProgramData%\FastFlow\daemon.token is checked per
//     request as defence in depth; the data directory is created with a
//     protected DACL and reclaimed if a squatter pre-created it.
//
// Usage:
//
//	fastflow-daemon.exe install     # register + as a Windows service (admin)
//	fastflow-daemon.exe uninstall   # remove the service (admin)
//	fastflow-daemon.exe debug       # run in the foreground (admin console)
//	(no args)                       # run as a service (invoked by the SCM)
package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"golang.org/x/sys/windows/svc"
)

const (
	serviceName = "FastFlowHelper"
	displayName = "FastFlow VPN Helper"
)

func main() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "install":
			must(installService())
			fmt.Println("FastFlow helper installed.")
			return
		case "uninstall":
			must(uninstallService())
			fmt.Println("FastFlow helper removed.")
			return
		case "debug":
			runConsole()
			return
		}
	}

	isService, err := svc.IsWindowsService()
	if err != nil {
		log.Fatalf("cannot determine service session: %v", err)
	}
	if isService {
		setupServiceLogging()
		runService()
	} else {
		runConsole()
	}
}

func must(err error) {
	if err != nil {
		log.Fatal(err)
	}
}

func setupServiceLogging() {
	// Lock the data directory before writing anything into it (protected DACL,
	// squat recovery), then open the log inside it.
	if err := ensureSecureDir(fastflowDir()); err != nil {
		return
	}
	path := filepath.Join(fastflowDir(), "daemon.log")
	if f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o600); err == nil {
		log.SetOutput(f)
	}
}
