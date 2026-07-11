//go:build windows

package main

import (
	"fmt"
	"io"
	"unsafe"

	"golang.org/x/sys/windows"
)

const pipeName = `\\.\pipe\FastFlowHelper`

// pipeSDDL: deny NETWORK first (belt-and-suspenders against remote access — the
// PIPE_REJECT_REMOTE_CLIENTS flag already blocks it), then allow SYSTEM and
// Administrators full and interactive users read/write so the standard-user GUI
// can open the endpoint. Opening the pipe is intentionally broad; verifyClient
// (exact path + Authenticode + publisher) is the real authorization gate.
const pipeSDDL = `D:P(D;;GA;;;NU)(A;;GA;;;SY)(A;;GA;;;BA)(A;;GRGW;;;IU)`

const (
	pipeAccessDuplex          = 0x00000003
	fileFlagFirstPipeInstance = 0x00080000
	pipeTypeByte              = 0x00000000
	pipeReadmodeByte          = 0x00000000
	pipeWaitMode              = 0x00000000
	pipeRejectRemoteClients   = 0x00000008
	pipeUnlimitedInstances    = 255
	pipeBufSize               = 64 * 1024
)

var (
	modKernel32                     = windows.NewLazySystemDLL("kernel32.dll")
	procGetNamedPipeClientProcessID = modKernel32.NewProc("GetNamedPipeClientProcessId")
)

// pipeConn adapts a connected pipe handle to io.ReadWriteCloser so the existing
// newline-delimited JSON loop in handle() consumes it unchanged.
type pipeConn struct{ h windows.Handle }

func (c *pipeConn) Read(p []byte) (int, error) {
	var n uint32
	err := windows.ReadFile(c.h, p, &n, nil)
	if err != nil {
		// A closed/disconnected pipe surfaces as ERROR_BROKEN_PIPE; treat as EOF.
		if err == windows.ERROR_BROKEN_PIPE || err == windows.ERROR_PIPE_NOT_CONNECTED {
			return int(n), io.EOF
		}
		return int(n), err
	}
	if n == 0 {
		return 0, io.EOF
	}
	return int(n), nil
}

func (c *pipeConn) Write(p []byte) (int, error) {
	var n uint32
	err := windows.WriteFile(c.h, p, &n, nil)
	return int(n), err
}

func (c *pipeConn) Close() error {
	_ = windows.FlushFileBuffers(c.h)
	_ = windows.DisconnectNamedPipe(c.h)
	return windows.CloseHandle(c.h)
}

func makePipeSA() (*windows.SecurityAttributes, error) {
	sd, err := windows.SecurityDescriptorFromString(pipeSDDL)
	if err != nil {
		return nil, fmt.Errorf("parse pipe sddl: %w", err)
	}
	sa := &windows.SecurityAttributes{SecurityDescriptor: sd}
	sa.Length = uint32(unsafe.Sizeof(*sa))
	return sa, nil
}

// createPipeInstance creates one server instance of the pipe. The first instance
// sets FILE_FLAG_FIRST_PIPE_INSTANCE so that if a malicious process has already
// squatted the pipe name, creation fails hard instead of us serving on an
// endpoint an attacker also owns.
func createPipeInstance(first bool, sa *windows.SecurityAttributes) (windows.Handle, error) {
	name, err := windows.UTF16PtrFromString(pipeName)
	if err != nil {
		return windows.InvalidHandle, err
	}
	openMode := uint32(pipeAccessDuplex)
	if first {
		openMode |= fileFlagFirstPipeInstance
	}
	h, err := windows.CreateNamedPipe(name, openMode,
		pipeTypeByte|pipeReadmodeByte|pipeWaitMode|pipeRejectRemoteClients,
		pipeUnlimitedInstances, pipeBufSize, pipeBufSize, 0, sa)
	if err != nil {
		return windows.InvalidHandle, fmt.Errorf("CreateNamedPipe: %w", err)
	}
	return h, nil
}

// waitForClient blocks until a client connects to the instance and returns the
// connecting process id (from the kernel, so there is no port->PID race).
func waitForClient(h windows.Handle) (uint32, error) {
	err := windows.ConnectNamedPipe(h, nil)
	if err != nil && err != windows.ERROR_PIPE_CONNECTED {
		return 0, fmt.Errorf("ConnectNamedPipe: %w", err)
	}
	return namedPipeClientPID(h)
}

func namedPipeClientPID(h windows.Handle) (uint32, error) {
	var pid uint32
	r, _, e := procGetNamedPipeClientProcessID.Call(
		uintptr(h), uintptr(unsafe.Pointer(&pid)))
	if r == 0 {
		return 0, fmt.Errorf("GetNamedPipeClientProcessId: %w", e)
	}
	return pid, nil
}
