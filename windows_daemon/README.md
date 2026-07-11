# FastFlow Windows Helper Daemon

Elevated Windows service that performs the privileged operations the
standard-user Flutter GUI cannot: the default-block firewall **kill switch** and
**route table** changes. The GUI (running as a normal user) talks to it over a
loopback-only JSON/TCP socket — see
[`daemon_ipc_client.dart`](../infrastructure/os_windows/daemon_ipc_client.dart).

## Protocol

Newline-delimited JSON on `127.0.0.1:47654`.

Request: `{"id":1,"token":"<secret>","method":"killSwitch","params":{"enabled":true,"appPath":"C:\\...\\fastflow_vpn.exe"}}`
Response: `{"id":1,"ok":true,"result":{}}`

Methods: `ping`, `killSwitch{enabled,appPath}`, `addRoute{cidr,gateway}`, `removeRoute{cidr}`.

## Security

1. **Loopback only** — the listener binds `127.0.0.1`; never reachable off-box.
2. **Shared secret** — a 256-bit token generated on first run, stored at
   `%ProgramData%\FastFlow\daemon.token` (Users read / Admins write). The GUI
   reads it and sends it with every command; the daemon compares in constant time.
3. **Peer process check** — each connection's local port is mapped to its owning
   PID (`GetExtendedTcpTable`) and the image path is checked against an allowlist
   (`%ProgramData%\FastFlow\client_allowlist.txt`, or the default `fastflow_vpn.exe`).

## Build

Requires Go 1.22+. On Windows (native), or cross-compiled from Linux with mingw:

```bash
cd windows_daemon
go mod tidy                 # once, to populate go.sum (network required)

# Native Windows build:
go build -trimpath -ldflags "-s -w" -o fastflow-daemon.exe .

# Cross-compile from Linux/CI:
CGO_ENABLED=0 GOOS=windows GOARCH=amd64 \
  go build -trimpath -ldflags "-s -w" -o fastflow-daemon.exe .
```

## Install (run from an elevated / Administrator prompt)

```powershell
fastflow-daemon.exe install     # register + auto-start the service
sc.exe start FastFlowHelper     # (or reboot; StartType is Automatic)

fastflow-daemon.exe uninstall   # remove it

fastflow-daemon.exe debug       # run in the foreground to watch logs
```

Service logs go to `%ProgramData%\FastFlow\daemon.log`. The installer/MSI should
place `fastflow-daemon.exe` under `%ProgramFiles%\FastFlow\`, run `install`, and
(optionally) write `client_allowlist.txt` with the full path of the installed
`fastflow_vpn.exe` to tighten the peer check to an exact path.
