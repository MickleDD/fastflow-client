package main

import "time"

// trafficSample is one direction of the traffic meter: an instantaneous rate in
// bytes/sec and a cumulative byte total for the current session.
type trafficSample struct {
	rate  int64
	total int64
}

// readTraffic returns the latest up/down samples for GetStats.
//
// Authoritative counters come from the v2ray statistics service that the config
// builder enables (experimental.v2ray_api.stats) with per-outbound tags. The
// builder sets an EMPTY listen address, so no TCP listener is ever bound: a
// background poller reads the stats service in-process (via the sing-box
// context) and calls engine.updateTraffic; here we only read the last cached
// snapshot so the FFI call the UI makes every second never blocks.
//
// Keep it that way — a loopback stats listener is readable by any co-resident
// process (Android does not isolate 127.0.0.1) and leaks server addresses and
// live traffic data to local spyware.
func readTraffic(e *engine) (up, down trafficSample) {
	snap := e.traffic.Load()
	if snap == nil {
		return trafficSample{}, trafficSample{}
	}
	return snap.up, snap.down
}

// trafficSnapshot is stored atomically so readers never see a torn up/down pair.
type trafficSnapshot struct {
	up   trafficSample
	down trafficSample
	at   time.Time
}
