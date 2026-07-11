//go:build windows

package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
)

// Rule names mirror WindowsRouteManager in the Dart layer so the elevated and
// non-elevated code paths manage the same firewall state.
const (
	ruleName         = "FastFlow-Engine-Out"
	ruleNameLoopback = "FastFlow-Engine-Out-Loopback"
)

// enableKillSwitch sets the default outbound policy to block and allows only the
// engine executable (all tunnelled traffic egresses from that process) plus
// loopback. If the engine dies, nothing leaves the machine.
func enableKillSwitch(appPath string) error {
	if err := netsh("advfirewall", "set", "allprofiles",
		"firewallpolicy", "blockinbound,blockoutbound"); err != nil {
		return err
	}
	if appPath != "" {
		if err := netsh("advfirewall", "firewall", "add", "rule",
			"name="+ruleName, "dir=out", "action=allow",
			"program="+appPath, "enable=yes"); err != nil {
			return err
		}
	}
	return netsh("advfirewall", "firewall", "add", "rule",
		"name="+ruleNameLoopback, "dir=out", "action=allow",
		"remoteip=127.0.0.1", "enable=yes")
}

// disableKillSwitch restores the default allow-outbound policy and removes the
// rules. appPath is accepted for symmetry with the client API.
func disableKillSwitch(appPath string) error {
	_ = appPath
	if err := netsh("advfirewall", "set", "allprofiles",
		"firewallpolicy", "blockinbound,allowoutbound"); err != nil {
		return err
	}
	_ = netsh("advfirewall", "firewall", "delete", "rule", "name="+ruleName)
	_ = netsh("advfirewall", "firewall", "delete", "rule", "name="+ruleNameLoopback)
	return nil
}

func netsh(args ...string) error { return run(system32("netsh.exe"), args...) }

// system32 returns the absolute path to a Windows system tool. Invoking tools by
// bare name would resolve them through PATH (or, historically, the working
// directory), letting an attacker who controls a writable PATH entry plant a
// trojaned netsh.exe / route.exe that the SYSTEM daemon would execute.
func system32(name string) string {
	root := os.Getenv("SystemRoot")
	if root == "" {
		root = `C:\Windows`
	}
	return filepath.Join(root, "System32", name)
}

// run executes a console tool without popping a window (CREATE_NO_WINDOW).
func run(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: 0x08000000} // CREATE_NO_WINDOW
	return cmd.Run()
}
