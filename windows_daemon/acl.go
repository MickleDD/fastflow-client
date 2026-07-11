//go:build windows

package main

import (
	"fmt"
	"os"
	"unsafe"

	"golang.org/x/sys/windows"
)

// fastflowSDDL locks %ProgramData%\FastFlow: owner Administrators, and a
// *protected* DACL ("P") so the parent's inheritable "Users may create files /
// append data" ACE does NOT flow down — that ACE is what lets a standard user
// squat the folder. SYSTEM + Administrators get full control; BUILTIN\Users get
// read only (the standard-user GUI must read daemon.token). The OICI flags make
// these ACEs inheritable by child files (daemon.token, daemon.log) so they get
// the same DACL without any per-file work.
const fastflowSDDL = `O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;FR;;;BU)`

// ensureSecureDir creates dir with the explicit protected DACL above. If the
// directory already exists it verifies the owner is SYSTEM or Administrators and,
// when it is not (a squatter pre-created it), reclaims ownership + DACL and purges
// any planted secrets so they are regenerated cleanly. The daemon runs as SYSTEM,
// which holds SeTakeOwnership/SeRestore, so the reclaim always succeeds.
func ensureSecureDir(dir string) error {
	sd, err := windows.SecurityDescriptorFromString(fastflowSDDL)
	if err != nil {
		return fmt.Errorf("parse sddl: %w", err)
	}
	owner, _, err := sd.Owner()
	if err != nil {
		return fmt.Errorf("read sddl owner: %w", err)
	}
	dacl, _, err := sd.DACL()
	if err != nil {
		return fmt.Errorf("read sddl dacl: %w", err)
	}

	p16, err := windows.UTF16PtrFromString(dir)
	if err != nil {
		return err
	}

	sa := &windows.SecurityAttributes{SecurityDescriptor: sd}
	sa.Length = uint32(unsafe.Sizeof(*sa))

	err = windows.CreateDirectory(p16, sa)
	if err == nil {
		return nil // fresh, correctly-ACLed directory
	}
	if err != windows.ERROR_ALREADY_EXISTS {
		return fmt.Errorf("create %q: %w", dir, err)
	}

	// Pre-existing: trust it only if a trusted principal owns it.
	if verifyDirTrusted(dir) == nil {
		return nil
	}
	if serr := windows.SetNamedSecurityInfo(
		dir, windows.SE_FILE_OBJECT,
		windows.OWNER_SECURITY_INFORMATION|
			windows.DACL_SECURITY_INFORMATION|
			windows.PROTECTED_DACL_SECURITY_INFORMATION,
		owner, nil, dacl, nil,
	); serr != nil {
		return fmt.Errorf("reclaim %q: %w", dir, serr)
	}
	// Discard anything the squatter may have planted (a chosen token, a
	// poisoned allowlist) so nothing attacker-controlled survives the reclaim.
	_ = os.Remove(tokenPath())
	_ = os.Remove(clientAllowlistPath())
	return nil
}

// verifyDirTrusted returns nil only when dir is owned by LocalSystem or the
// built-in Administrators group.
func verifyDirTrusted(dir string) error {
	sd, err := windows.GetNamedSecurityInfo(
		dir, windows.SE_FILE_OBJECT, windows.OWNER_SECURITY_INFORMATION)
	if err != nil {
		return err
	}
	owner, _, err := sd.Owner()
	if err != nil {
		return err
	}
	sys, err := windows.CreateWellKnownSid(windows.WinLocalSystemSid)
	if err != nil {
		return err
	}
	admins, err := windows.CreateWellKnownSid(windows.WinBuiltinAdministratorsSid)
	if err != nil {
		return err
	}
	if owner.Equals(sys) || owner.Equals(admins) {
		return nil
	}
	return fmt.Errorf("untrusted owner on %q: %s", dir, owner.String())
}
