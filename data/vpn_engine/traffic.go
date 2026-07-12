package main

import (
	"context"
	"reflect"
	"time"

	"github.com/sagernet/sing-box/adapter"
	"github.com/sagernet/sing/service"
)

// trafficSample is one direction of the traffic meter: an instantaneous rate in
// bytes/sec and a cumulative byte total for the current session.
type trafficSample struct {
	rate  int64
	total int64
}

// trafficSnapshot is stored atomically so readers never see a torn up/down pair.
type trafficSnapshot struct {
	up   trafficSample
	down trafficSample
	at   time.Time
}

// readTraffic returns the latest up/down samples for GetStats. It only reads the
// last cached snapshot (populated by the poller below), so the FFI call the UI
// makes every second never blocks and no loopback listener is ever bound.
func readTraffic(e *engine) (up, down trafficSample) {
	snap := e.traffic.Load()
	if snap == nil {
		return trafficSample{}, trafficSample{}
	}
	return snap.up, snap.down
}

// --- in-process traffic poller ----------------------------------------------
//
// SECURITY: this samples sing-box's v2ray statistics service *in process*. The
// config builder enables it with an EMPTY `listen`, so NO TCP listener is bound;
// clash_api is never enabled and no loopback socket is ever opened. Counters are
// read by a direct Go call, not over any socket.

// trafficOutboundTags are the outbound tags whose counters we sum for the meter.
// They MUST match OutboundBuilder.proxyTag / directTag on the Dart side and the
// `experimental.v2ray_api.stats.outbounds` list in the generated config.
var trafficOutboundTags = []string{"proxy", "direct"}

const trafficPollInterval = time.Second

// startTrafficPoller wires the meter for one running instance. [ctx] MUST be the
// context handed to box.New: it carries the sing-box service registry (so we can
// find the stats service) and is cancelled when the engine stops. Safe to call
// while holding e.mu — it does no blocking work and the goroutine never locks.
func (e *engine) startTrafficPoller(ctx context.Context) {
	reader := newV2RayStatsReader(ctx)
	if reader == nil {
		// Stats service unavailable (disabled in config, or the core exposes no
		// readable stats service). Leave e.traffic nil so GetStats reports 0 —
		// nothing was opened, so there is nothing to tear down.
		return
	}
	go e.pollTraffic(ctx, reader)
}

func (e *engine) pollTraffic(ctx context.Context, reader statsReader) {
	// Never let a stats read take the host process down; degrade to 0 instead.
	defer func() { _ = recover() }()

	ticker := time.NewTicker(trafficPollInterval)
	defer ticker.Stop()

	var last trafficSnapshot
	haveLast := false

	for {
		select {
		case <-ctx.Done():
			// Engine stopped: clear the meter so the next connection starts at 0.
			e.traffic.Store(nil)
			return
		case now := <-ticker.C:
			up, down := readTotals(reader)
			snap := trafficSnapshot{
				up:   trafficSample{total: up},
				down: trafficSample{total: down},
				at:   now,
			}
			if haveLast {
				dt := now.Sub(last.at).Seconds()
				snap.up.rate = perSecond(up-last.up.total, dt)
				snap.down.rate = perSecond(down-last.down.total, dt)
			}
			last = snap
			haveLast = true
			e.traffic.Store(&snap)
		}
	}
}

func readTotals(reader statsReader) (up, down int64) {
	for _, tag := range trafficOutboundTags {
		up += reader.read(statsCounterName(tag, "uplink"))
		down += reader.read(statsCounterName(tag, "downlink"))
	}
	return up, down
}

// statsCounterName builds the V2Ray/Xray counter key sing-box registers per
// outbound, e.g. "outbound>>>proxy>>>traffic>>>uplink".
func statsCounterName(tag, direction string) string {
	return "outbound>>>" + tag + ">>>traffic>>>" + direction
}

// perSecond converts a byte delta over dt seconds into a bytes/sec rate. The
// v2ray counters are cumulative and monotonic; a negative delta only happens on
// a counter reset (reconnect), so clamp to 0 rather than show a spike.
func perSecond(delta int64, dtSeconds float64) int64 {
	if delta <= 0 || dtSeconds <= 0 {
		return 0
	}
	return int64(float64(delta) / dtSeconds)
}

// --- sing-box v2ray stats bridge — VERIFY THESE 2 SYMBOLS AGAINST YOUR CORE ---
//
// I could NOT compile this against the pinned core here (the module cache had no
// sing-box and CGO was unavailable), and this build links a hiddify-style fork
// per outbound_builder.dart. Exactly TWO compile-time symbols below are my read
// of the sing-box v1.11 API and are the only things to confirm:
//
//   (1) adapter.V2RayServer                 -> adapter/experimental.go
//   (2) (adapter.V2RayServer).StatsService()-> same file (returns V2RayStatsService)
//
// Everything AFTER StatsService() goes through reflection on purpose: the public
// V2RayStatsService interface exposes only connection wrappers, and the readable
// GetStats lives on the concrete type. Reflecting over it keeps this file free of
// the unexported v2rayapi request/response types, so it compiles across core
// versions and simply reports 0 if the shape differs — no hard failure.

type statsReader interface {
	read(name string) int64
}

// newV2RayStatsReader finds the running v2ray stats service in [ctx] (the same
// registry box.New populated) and returns a reader, or nil if stats are off.
func newV2RayStatsReader(ctx context.Context) statsReader {
	server := service.FromContext[adapter.V2RayServer](ctx) // (1) verify symbol
	if server == nil {
		return nil
	}
	stats := server.StatsService() // (2) verify symbol
	if stats == nil {
		return nil
	}
	// reflect.ValueOf unwraps the interface to the concrete stats type, whose
	// method set includes GetStats even though the interface does not expose it.
	getStats := reflect.ValueOf(stats).MethodByName("GetStats")
	if !getStats.IsValid() {
		return nil
	}
	mt := getStats.Type() // bound method: receiver already applied
	if mt.NumIn() != 2 || mt.NumOut() != 2 || mt.In(1).Kind() != reflect.Ptr {
		return nil
	}
	return &v2rayStatsReader{ctx: ctx, getStats: getStats}
}

type v2rayStatsReader struct {
	ctx      context.Context
	getStats reflect.Value // func(context.Context, *GetStatsRequest) (*GetStatsResponse, error)
}

// read returns the current value of the named counter, or 0 if the counter does
// not exist yet (no traffic on that outbound) or the response shape is unknown.
//
// TYPED EQUIVALENT — swap in once you confirm the symbols against your core
// (import "github.com/sagernet/sing-box/experimental/v2rayapi"):
//
//	resp, err := r.svc.GetStats(r.ctx, &v2rayapi.GetStatsRequest{Name: name})
//	if err != nil || resp.GetStat() == nil { return 0 }
//	return resp.GetStat().GetValue()
func (r *v2rayStatsReader) read(name string) (result int64) {
	// A signature mismatch would panic in reflect.Call; contain it -> 0.
	defer func() {
		if recover() != nil {
			result = 0
		}
	}()

	reqType := r.getStats.Type().In(1).Elem() // GetStatsRequest struct
	req := reflect.New(reqType)
	nameField := req.Elem().FieldByName("Name")
	if !nameField.IsValid() || nameField.Kind() != reflect.String {
		return 0
	}
	nameField.SetString(name)

	out := r.getStats.Call([]reflect.Value{reflect.ValueOf(r.ctx), req})
	if !out[1].IsNil() { // error != nil => counter not found => 0
		return 0
	}
	return statValue(out[0])
}

// statValue extracts resp.Stat.Value from a *GetStatsResponse, tolerating either
// pointer or value structs at each hop.
func statValue(resp reflect.Value) int64 {
	resp = deref(resp)
	if !resp.IsValid() || resp.Kind() != reflect.Struct {
		return 0
	}
	stat := deref(resp.FieldByName("Stat"))
	if !stat.IsValid() || stat.Kind() != reflect.Struct {
		return 0
	}
	value := stat.FieldByName("Value")
	if !value.IsValid() || value.Kind() != reflect.Int64 {
		return 0
	}
	return value.Int()
}

func deref(v reflect.Value) reflect.Value {
	if v.Kind() == reflect.Ptr {
		if v.IsNil() {
			return reflect.Value{}
		}
		return v.Elem()
	}
	return v
}