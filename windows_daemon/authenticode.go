//go:build windows

package main

import (
	"fmt"
	"strings"
	"unsafe"

	"golang.org/x/sys/windows"
)

// ---- WinVerifyTrust: chain / tamper validation -----------------------------

var (
	modWintrust        = windows.NewLazySystemDLL("wintrust.dll")
	procWinVerifyTrust = modWintrust.NewProc("WinVerifyTrust")

	// WINTRUST_ACTION_GENERIC_VERIFY_V2
	wintrustActionVerify = windows.GUID{
		Data1: 0x00aac56b, Data2: 0xcd44, Data3: 0x11d0,
		Data4: [8]byte{0x8c, 0xc2, 0x00, 0xc0, 0x4f, 0xc2, 0x95, 0xee},
	}
)

const (
	wtdUINone            = 2
	wtdRevokeNone        = 0
	wtdChoiceFile        = 1
	wtdStateActionVerify = 1
	wtdStateActionClose  = 2
	// Do not prompt / do not cache UI; fail closed on any trust problem.
	wtdSafeAdvancedFlags = 0x00000100 // WTD_SAFER_FLAG
)

type wintrustFileInfo struct {
	cbStruct       uint32
	pcwszFilePath  *uint16
	hFile          windows.Handle
	pgKnownSubject *windows.GUID
}

type wintrustData struct {
	cbStruct            uint32
	pPolicyCallbackData uintptr
	pSIPClientData      uintptr
	dwUIChoice          uint32
	fdwRevocationChecks uint32
	dwUnionChoice       uint32
	pFile               *wintrustFileInfo
	dwStateAction       uint32
	hWVTStateData       windows.Handle
	pwszURLReference    *uint16
	dwProvFlags         uint32
	dwUIContext         uint32
	pSignatureSettings  uintptr
}

// verifyAuthenticode returns nil only when path carries a valid, trusted,
// unbroken Authenticode chain. Rejects unsigned, tampered, and untrusted-root
// binaries. Revocation is not checked online (WTD_REVOKE_NONE) to avoid blocking
// on a dead network; chain trust to a Microsoft-rooted CA is still required.
func verifyAuthenticode(path string) error {
	p16, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return err
	}
	fi := wintrustFileInfo{
		cbStruct:      uint32(unsafe.Sizeof(wintrustFileInfo{})),
		pcwszFilePath: p16,
	}
	wd := wintrustData{
		cbStruct:            uint32(unsafe.Sizeof(wintrustData{})),
		dwUIChoice:          wtdUINone,
		fdwRevocationChecks: wtdRevokeNone,
		dwUnionChoice:       wtdChoiceFile,
		pFile:               &fi,
		dwStateAction:       wtdStateActionVerify,
		dwProvFlags:         wtdSafeAdvancedFlags,
	}
	r, _, _ := procWinVerifyTrust.Call(0,
		uintptr(unsafe.Pointer(&wintrustActionVerify)),
		uintptr(unsafe.Pointer(&wd)))

	// Always release the state data, whatever the verify result was.
	wd.dwStateAction = wtdStateActionClose
	procWinVerifyTrust.Call(0,
		uintptr(unsafe.Pointer(&wintrustActionVerify)),
		uintptr(unsafe.Pointer(&wd)))

	if r != 0 {
		return fmt.Errorf("WinVerifyTrust failed (0x%08x) for %q", uint32(r), path)
	}
	return nil
}

// ---- crypt32: signer publisher (subject CN) check --------------------------

var (
	modCrypt32              = windows.NewLazySystemDLL("crypt32.dll")
	procCryptQueryObject    = modCrypt32.NewProc("CryptQueryObject")
	procCryptMsgGetParam    = modCrypt32.NewProc("CryptMsgGetParam")
	procCryptMsgClose       = modCrypt32.NewProc("CryptMsgClose")
	procCertFindCertInStore = modCrypt32.NewProc("CertFindCertificateInStore")
	procCertGetNameStringW  = modCrypt32.NewProc("CertGetNameStringW")
	procCertFreeCertContext = modCrypt32.NewProc("CertFreeCertificateContext")
	procCertCloseStore      = modCrypt32.NewProc("CertCloseStore")
)

const (
	certQueryObjectFile             = 0x00000001
	certQueryContentFlagPkcs7Signed = 0x00000400 // CERT_QUERY_CONTENT_FLAG_PKCS7_SIGNED_EMBED = 1<<10
	certQueryFormatFlagBinary       = 0x00000002 // CERT_QUERY_FORMAT_FLAG_BINARY = 1<<1
	cmsgSignerCertInfoParam         = 34
	certFindSubjectCert             = 0x000B0000 // CERT_COMPARE_SUBJECT_CERT<<CERT_COMPARE_SHIFT
	x509AsnEncoding                 = 0x00000001
	pkcs7AsnEncoding                = 0x00010000
	certNameSimpleDisplayType       = 4
)

// verifySignerCN confirms the primary signer's subject display name matches
// wantCN (case-insensitive). Called only after verifyAuthenticode has already
// established the chain is trusted, so this pins *which* trusted publisher is
// allowed — a validly signed binary from any other vendor is rejected.
func verifySignerCN(path, wantCN string) error {
	p16, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return err
	}

	var (
		encoding    uint32
		contentType uint32
		formatType  uint32
		hStore      windows.Handle
		hMsg        windows.Handle
	)
	r, _, e := procCryptQueryObject.Call(
		certQueryObjectFile,
		uintptr(unsafe.Pointer(p16)),
		certQueryContentFlagPkcs7Signed,
		certQueryFormatFlagBinary,
		0,
		uintptr(unsafe.Pointer(&encoding)),
		uintptr(unsafe.Pointer(&contentType)),
		uintptr(unsafe.Pointer(&formatType)),
		uintptr(unsafe.Pointer(&hStore)),
		uintptr(unsafe.Pointer(&hMsg)),
		0,
	)
	if r == 0 {
		return fmt.Errorf("CryptQueryObject(%q): %w", path, e)
	}
	defer procCryptMsgClose.Call(uintptr(hMsg))
	defer procCertCloseStore.Call(uintptr(hStore), 0)

	// Fetch the signer's CERT_INFO (Issuer + SerialNumber) — first sized, then read.
	var cbInfo uint32
	r, _, e = procCryptMsgGetParam.Call(uintptr(hMsg), cmsgSignerCertInfoParam, 0, 0,
		uintptr(unsafe.Pointer(&cbInfo)))
	if r == 0 || cbInfo == 0 {
		return fmt.Errorf("CryptMsgGetParam(size): %w", e)
	}
	info := make([]byte, cbInfo)
	r, _, e = procCryptMsgGetParam.Call(uintptr(hMsg), cmsgSignerCertInfoParam, 0,
		uintptr(unsafe.Pointer(&info[0])), uintptr(unsafe.Pointer(&cbInfo)))
	if r == 0 {
		return fmt.Errorf("CryptMsgGetParam(data): %w", e)
	}

	// Locate the signer certificate in the message's store by Issuer+Serial.
	certCtx, _, _ := procCertFindCertInStore.Call(
		uintptr(hStore),
		x509AsnEncoding|pkcs7AsnEncoding,
		0,
		certFindSubjectCert,
		uintptr(unsafe.Pointer(&info[0])),
		0,
	)
	if certCtx == 0 {
		return fmt.Errorf("signer certificate not found for %q", path)
	}
	defer procCertFreeCertContext.Call(certCtx)

	// Read the subject simple display name (CN / O), first sized then filled.
	n, _, _ := procCertGetNameStringW.Call(certCtx, certNameSimpleDisplayType, 0, 0, 0, 0)
	if n <= 1 {
		return fmt.Errorf("empty signer subject for %q", path)
	}
	buf := make([]uint16, n)
	procCertGetNameStringW.Call(certCtx, certNameSimpleDisplayType, 0, 0,
		uintptr(unsafe.Pointer(&buf[0])), n)
	subject := windows.UTF16ToString(buf)

	if !strings.EqualFold(strings.TrimSpace(subject), strings.TrimSpace(wantCN)) {
		return fmt.Errorf("client signed by %q, expected %q", subject, wantCN)
	}
	return nil
}
