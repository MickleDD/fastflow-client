//go:build windows

package main

import (
	"fmt"
	"os"

	"golang.org/x/sys/windows/svc/mgr"
)

func installService() error {
	exe, err := os.Executable()
	if err != nil {
		return fmt.Errorf("locate executable: %w", err)
	}

	// Create the data directory with its protected DACL now, at admin-time,
	// closing the window in which a standard user could squat it before the
	// service first runs. NOTE: the installer must place this daemon and the GUI
	// (%ProgramFiles%\FastFlow\fastflow_vpn.exe) in an admin-only location — the
	// peer check trusts that path.
	if err := ensureSecureDir(fastflowDir()); err != nil {
		return fmt.Errorf("secure data dir: %w", err)
	}

	m, err := mgr.Connect()
	if err != nil {
		return fmt.Errorf("connect to service manager (run as admin): %w", err)
	}
	defer m.Disconnect()

	if s, err := m.OpenService(serviceName); err == nil {
		s.Close()
		return fmt.Errorf("service %q already installed", serviceName)
	}

	s, err := m.CreateService(serviceName, exe, mgr.Config{
		DisplayName:  displayName,
		Description:  "Performs privileged routing / firewall operations for FastFlow VPN.",
		StartType:    mgr.StartAutomatic,
		ServiceType:  0x10, // SERVICE_WIN32_OWN_PROCESS
		Dependencies: []string{"Tcpip"},
	})
	if err != nil {
		return fmt.Errorf("create service: %w", err)
	}
	defer s.Close()
	return nil
}

func uninstallService() error {
	m, err := mgr.Connect()
	if err != nil {
		return fmt.Errorf("connect to service manager (run as admin): %w", err)
	}
	defer m.Disconnect()

	s, err := m.OpenService(serviceName)
	if err != nil {
		return fmt.Errorf("service %q not installed: %w", serviceName, err)
	}
	defer s.Close()

	if err := s.Delete(); err != nil {
		return fmt.Errorf("delete service: %w", err)
	}
	return nil
}
