//go:build windows

package main

import (
	"log"

	"golang.org/x/sys/windows/svc"
)

// helper implements svc.Handler; the SCM drives its lifecycle.
type helper struct{}

func (h *helper) Execute(args []string, r <-chan svc.ChangeRequest, status chan<- svc.Status) (bool, uint32) {
	const accepted = svc.AcceptStop | svc.AcceptShutdown
	status <- svc.Status{State: svc.StartPending}

	server := newServer()
	if err := server.start(); err != nil {
		log.Printf("failed to start IPC server: %v", err)
		return false, 1
	}
	status <- svc.Status{State: svc.Running, Accepts: accepted}

	for c := range r {
		switch c.Cmd {
		case svc.Interrogate:
			status <- c.CurrentStatus
		case svc.Stop, svc.Shutdown:
			status <- svc.Status{State: svc.StopPending}
			server.stop()
			return false, 0
		default:
			log.Printf("unexpected service control request #%d", c.Cmd)
		}
	}
	return false, 0
}

func runService() {
	if err := svc.Run(serviceName, &helper{}); err != nil {
		log.Fatalf("service failed: %v", err)
	}
}

// runConsole runs the same IPC server in the foreground for local debugging.
func runConsole() {
	log.SetFlags(log.LstdFlags | log.Lmicroseconds)
	log.Printf("FastFlow helper (console mode) listening on %s — Ctrl+C to stop", pipeName)
	server := newServer()
	if err := server.start(); err != nil {
		log.Fatalf("failed to start IPC server: %v", err)
	}
	select {} // block forever
}
