//go:build windows

package main

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"golang.org/x/sys/windows"
)

// expectedClientName is the only image name permitted to drive the daemon, and
// expectedPublisherCN is the Authenticode subject it must be signed by. Set the
// CN to match the production code-signing certificate before release.
const (
	expectedClientName  = "fastflow_vpn.exe"
	expectedPublisherCN = "FastFlow Networks Inc."
)

func fastflowDir() string {
	base := os.Getenv("ProgramData")
	if base == "" {
		base = `C:\ProgramData`
	}
	return filepath.Join(base, "FastFlow")
}

func tokenPath() string           { return filepath.Join(fastflowDir(), "daemon.token") }
func clientAllowlistPath() string { return filepath.Join(fastflowDir(), "client_allowlist.txt") }

func programFilesDir() string {
	if d := os.Getenv("ProgramFiles"); d != "" {
		return d
	}
	return `C:\Program Files`
}

// expectedClientPath is the single absolute path the GUI must run from. It lives
// under %ProgramFiles%\FastFlow, a directory only administrators can write, so an
// attacker cannot drop a same-named binary there.
func expectedClientPath() string {
	return filepath.Join(programFilesDir(), "FastFlow", expectedClientName)
}

// loadOrCreateToken returns the shared secret, generating it on first run.
//
// The directory is locked down first (ensureSecureDir): a *protected* DACL means
// child files inherit SYSTEM/Admins-full + Users-read, so the token is not
// writable by unprivileged code and the folder cannot be squatted. The token is
// kept only as defence-in-depth channel auth — the security boundary is the
// per-connection peer check (verifyClient), because a file DACL cannot separate
// the real GUI from other same-user processes.
func loadOrCreateToken() (string, error) {
	if err := ensureSecureDir(fastflowDir()); err != nil {
		return "", fmt.Errorf("secure data dir: %w", err)
	}
	p := tokenPath()
	if b, err := os.ReadFile(p); err == nil {
		if t := strings.TrimSpace(string(b)); len(t) >= 32 {
			return t, nil
		}
	}
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	tok := hex.EncodeToString(buf)
	// The directory's protected, inheritable DACL gives this file the correct
	// ACL; the mode bits are advisory on Windows.
	if err := os.WriteFile(p, []byte(tok), 0o600); err != nil {
		return "", err
	}
	return tok, nil
}

// verifyClient authorises a connecting process (PID from the named-pipe kernel
// lookup — no port->PID race). It must be the exact installed GUI image, carry a
// valid trusted Authenticode chain, and be signed by the expected publisher.
// Returns the verified image path so the dispatcher can bind privileged
// arguments (e.g. the kill-switch allow target) to it instead of trusting
// client-supplied strings.
func verifyClient(pid uint32) (string, error) {
	path, err := processImagePath(pid)
	if err != nil {
		return "", fmt.Errorf("resolve image for pid %d: %w", pid, err)
	}
	if !strings.EqualFold(path, expectedClientPath()) {
		return "", fmt.Errorf("client %q is not the installed GUI", path)
	}
	// !!! SECURITY — TEMPORARY: signature verification is DISABLED pending a code
	// signing certificate. The trust boundary now rests ONLY on the admin-only
	// install path (%ProgramFiles%\FastFlow). RE-ENABLE both checks below before
	// any public/production release — without them, any binary that reaches that
	// exact path (e.g. via a weak install-dir ACL or a tampered on-disk exe) is
	// trusted as SYSTEM. Functions are kept intact for a one-line re-enable.
	// if err := verifyAuthenticode(path); err != nil {
	// 	return "", fmt.Errorf("client signature check failed: %w", err)
	// }
	// if err := verifySignerCN(path, expectedPublisherCN); err != nil {
	// 	return "", fmt.Errorf("client publisher check failed: %w", err)
	// }
	return path, nil
}

// processImagePath resolves a PID to its full on-disk image path.
func processImagePath(pid uint32) (string, error) {
	h, err := windows.OpenProcess(windows.PROCESS_QUERY_LIMITED_INFORMATION, false, pid)
	if err != nil {
		return "", err
	}
	defer windows.CloseHandle(h)

	buf := make([]uint16, windows.MAX_PATH)
	size := uint32(len(buf))
	if err := windows.QueryFullProcessImageName(h, 0, &buf[0], &size); err != nil {
		return "", err
	}
	return windows.UTF16ToString(buf[:size]), nil
}
