//go:build windows

package main

import (
	"fmt"
	"net"
)

// addRoute installs a static route to [cidr] via [gateway]. Used to point the
// tunnel's route(s) at the wintun adapter's gateway when running elevated.
//
// Both arguments arrive over IPC, so they are strictly validated as a real IPv4
// CIDR and a real IPv4 gateway before being handed to route.exe — this rejects
// malformed input and any attempt at argument smuggling.
func addRoute(cidr, gateway string) error {
	ip, mask, err := parseIPv4CIDR(cidr)
	if err != nil {
		return err
	}
	gw := net.ParseIP(gateway)
	if gw == nil || gw.To4() == nil {
		return fmt.Errorf("invalid gateway %q", gateway)
	}
	return run(system32("route.exe"), "ADD", ip, "MASK", mask, gw.To4().String())
}

func removeRoute(cidr string) error {
	ip, _, err := parseIPv4CIDR(cidr)
	if err != nil {
		return err
	}
	return run(system32("route.exe"), "DELETE", ip)
}

// parseIPv4CIDR validates "a.b.c.d/n" and returns the network address and the
// dotted netmask that route.exe expects.
func parseIPv4CIDR(cidr string) (ip, mask string, err error) {
	_, ipnet, err := net.ParseCIDR(cidr)
	if err != nil {
		return "", "", fmt.Errorf("invalid cidr %q", cidr)
	}
	v4 := ipnet.IP.To4()
	if v4 == nil || len(ipnet.Mask) != net.IPv4len {
		return "", "", fmt.Errorf("cidr %q is not IPv4", cidr)
	}
	return v4.String(), net.IP(ipnet.Mask).String(), nil
}
