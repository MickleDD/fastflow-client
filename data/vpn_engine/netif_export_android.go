//go:build android

package main

// Cgo exports for the platform network monitor (Part 2).
//
// These are the Go side of the C ABI in netif_bridge.h. The JNI shim
// (libfastflow_jni.so) resolves them at runtime with dlsym and calls them from
// the Kotlin NetworkStateMonitor's downcalls; NetifRegisterPlatform runs once,
// after which Go can call back into the shim (protect/replay) through the
// pointers it hands over. See platform_android.go for the registry these feed
// and the ff_call_* trampolines that invoke the returned pointers.
//
// This file is kept separate from platform_android.go on purpose: cgo forbids
// C *definitions* (the trampolines) in the preamble of a file that uses //export,
// so the preamble here includes only the shared header (pure declarations).
//
// MEMORY CONTRACT (netif_bridge.h): every const char* is a borrowed, call-scoped
// buffer owned by the caller, and FFNetworkInfo is stack-allocated by the caller.
// We copy everything (C.GoString / by-value fields) into a netifSnapshot before
// returning and never retain a C pointer.

/*
#cgo CFLAGS: -I${SRCDIR}

#include "netif_bridge.h"
*/
import "C"

// snapshotFromC copies a borrowed FFNetworkInfo into an owned, pure-Go value.
func snapshotFromC(info *C.FFNetworkInfo) netifSnapshot {
	return netifSnapshot{
		handle:  int64(info.net_handle),
		ifIndex: int(info.if_index),
		mtu:     int(info.mtu),
		flags:   uint32(info.flags),
		ifName:  C.GoString(info.if_name),
		addrs:   C.GoString(info.addresses),
		dns:     C.GoString(info.dns_servers),
	}
}

// NetifUpdate: a non-VPN network appeared or changed (identity = net_handle).
//
//export NetifUpdate
func NetifUpdate(info *C.FFNetworkInfo) {
	if info == nil {
		return
	}
	netifReg.update(snapshotFromC(info))
}

// NetifLost: the network with this handle disappeared.
//
//export NetifLost
func NetifLost(netHandle C.int64_t) {
	netifReg.lost(int64(netHandle))
}

// NetifDefaultChanged: the best underlying (non-VPN) network changed. A nil info
// (or FF_NETIF_NO_HANDLE) means no usable network.
//
//export NetifDefaultChanged
func NetifDefaultChanged(info *C.FFNetworkInfo) {
	if info == nil {
		netifReg.setDefault(nil)
		return
	}
	s := snapshotFromC(info)
	netifReg.setDefault(&s)
}

// NetifReset: the platform monitor stopped — drop every cached network.
//
//export NetifReset
func NetifReset() {
	netifReg.reset()
}

// NetifRegisterPlatform: hand Go the shim's upcall pointers (protect + replay).
// Called once by the shim after it resolves these exports.
//
//export NetifRegisterPlatform
func NetifRegisterPlatform(protect C.ff_protect_fn, replay C.ff_replay_fn) {
	netifReg.setPlatform(protect, replay)
}
