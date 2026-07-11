//go:build windows

package main

import (
	"bufio"
	"crypto/subtle"
	"encoding/json"
	"io"
	"log"
	"sync"

	"golang.org/x/sys/windows"
)

// Wire format matches daemon_ipc_client.dart: one JSON object per line.
//
//	request : {"id","token","method","params"}
//	response: {"id","ok","result"|"error"}
type request struct {
	ID     int                    `json:"id"`
	Token  string                 `json:"token"`
	Method string                 `json:"method"`
	Params map[string]interface{} `json:"params"`
}

type response struct {
	ID     int                    `json:"id"`
	OK     bool                   `json:"ok"`
	Result map[string]interface{} `json:"result,omitempty"`
	Error  string                 `json:"error,omitempty"`
}

type server struct {
	token string

	mu      sync.Mutex
	cur     windows.Handle // instance currently blocked in ConnectNamedPipe
	stopped bool
}

func newServer() *server { return &server{cur: windows.InvalidHandle} }

func (s *server) start() error {
	tok, err := loadOrCreateToken()
	if err != nil {
		return err
	}
	s.token = tok
	go s.acceptLoop()
	log.Printf("IPC listening on %s", pipeName)
	return nil
}

func (s *server) stop() {
	s.mu.Lock()
	s.stopped = true
	h := s.cur
	s.cur = windows.InvalidHandle
	s.mu.Unlock()
	// Closing the instance that is parked in ConnectNamedPipe unblocks the loop.
	if h != windows.InvalidHandle {
		_ = windows.CloseHandle(h)
	}
}

func (s *server) acceptLoop() {
	sa, err := makePipeSA()
	if err != nil {
		log.Printf("pipe security descriptor: %v", err)
		return
	}
	first := true
	for {
		h, err := createPipeInstance(first, sa)
		first = false
		if err != nil {
			log.Printf("create pipe instance: %v", err)
			return
		}

		s.mu.Lock()
		if s.stopped {
			s.mu.Unlock()
			_ = windows.CloseHandle(h)
			return
		}
		s.cur = h
		s.mu.Unlock()

		pid, err := waitForClient(h)

		s.mu.Lock()
		stopped := s.stopped
		s.cur = windows.InvalidHandle
		s.mu.Unlock()
		if stopped {
			_ = windows.CloseHandle(h)
			return
		}
		if err != nil {
			log.Printf("await client: %v", err)
			_ = windows.CloseHandle(h)
			continue
		}

		// Authorise the peer BEFORE reading any input from it.
		path, verr := verifyClient(pid)
		if verr != nil {
			log.Printf("rejected connection (pid %d): %v", pid, verr)
			(&pipeConn{h: h}).Close()
			continue
		}
		go s.handle(&pipeConn{h: h}, path)
	}
}

// handle serves one authorised client. verifiedPath is the on-disk image of the
// connecting process, used to bind privileged arguments to a trusted value.
func (s *server) handle(conn io.ReadWriteCloser, verifiedPath string) {
	defer conn.Close()

	reader := bufio.NewReader(conn)
	for {
		line, err := reader.ReadBytes('\n')
		if err != nil {
			return
		}
		var req request
		if err := json.Unmarshal(line, &req); err != nil {
			writeResp(conn, response{OK: false, Error: "invalid json"})
			continue
		}
		writeResp(conn, s.dispatch(req, verifiedPath))
	}
}

func writeResp(conn io.Writer, resp response) {
	b, _ := json.Marshal(resp)
	b = append(b, '\n')
	_, _ = conn.Write(b)
}

func (s *server) dispatch(req request, verifiedPath string) response {
	// Constant-time secret check on every command (defence in depth on top of
	// the pipe DACL + peer verification).
	if subtle.ConstantTimeCompare([]byte(req.Token), []byte(s.token)) != 1 {
		log.Printf("unauthorized request for method %q", req.Method)
		return response{ID: req.ID, OK: false, Error: "unauthorized"}
	}

	switch req.Method {
	case "ping":
		return response{ID: req.ID, OK: true, Result: map[string]interface{}{"pong": true}}

	case "killSwitch":
		enabled, _ := req.Params["enabled"].(bool)
		// Ignore any client-supplied appPath: the allow target is the verified
		// peer image (the sing-box engine runs in the GUI process on Windows).
		if enabled {
			return result(req.ID, enableKillSwitch(verifiedPath))
		}
		return result(req.ID, disableKillSwitch(verifiedPath))

	case "addRoute":
		cidr, _ := req.Params["cidr"].(string)
		gateway, _ := req.Params["gateway"].(string)
		return result(req.ID, addRoute(cidr, gateway))

	case "removeRoute":
		cidr, _ := req.Params["cidr"].(string)
		return result(req.ID, removeRoute(cidr))

	default:
		return response{ID: req.ID, OK: false, Error: "unknown method: " + req.Method}
	}
}

func result(id int, err error) response {
	if err != nil {
		return response{ID: id, OK: false, Error: err.Error()}
	}
	return response{ID: id, OK: true, Result: map[string]interface{}{}}
}
