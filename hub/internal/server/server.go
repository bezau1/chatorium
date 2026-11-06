// Package server is the loopback hub: it routes UI <-> connectors and persists history.
package server

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net"
	"sync"

	"github.com/bezau1/chatorium/hub/internal/connector"
	"github.com/bezau1/chatorium/hub/internal/proto"
	"github.com/bezau1/chatorium/hub/internal/store"
)

type client struct {
	conn     net.Conn
	role     string
	platform string
	out      chan proto.Frame
}

type Hub struct {
	st      *store.Store
	mu      sync.Mutex
	clients map[*client]bool
	local   map[string]connector.Connector
	status  map[string]string // last status per platform, replayed to new UIs
}

func New(st *store.Store, locals ...connector.Connector) *Hub {
	h := &Hub{st: st, clients: map[*client]bool{}, local: map[string]connector.Connector{}, status: map[string]string{}}
	for _, c := range locals {
		h.local[c.Platform()] = c
	}
	return h
}

// --- connector.Sink ---

func (h *Hub) Ingest(m proto.Message) {
	isNew, err := h.st.Add(m)
	if err != nil {
		log.Printf("store: %v", err)
	}
	if isNew {
		h.broadcast("ui", proto.Frame{Op: "message", Message: &m})
	}
}

func (h *Hub) Status(platform, data string) {
	h.mu.Lock()
	h.status[platform] = data
	h.mu.Unlock()
	h.broadcast("ui", proto.Frame{Op: "status", Platform: platform, Data: data})
}

func (h *Hub) broadcast(role string, f proto.Frame) {
	h.mu.Lock()
	defer h.mu.Unlock()
	for c := range h.clients {
		if c.role == role {
			select {
			case c.out <- f:
			default: // slow client; drop
			}
		}
	}
}

// Run starts local connectors and serves until ctx is cancelled.
func (h *Hub) Run(ctx context.Context, addr string) error {
	for p, c := range h.local {
		p, c := p, c
		go func() {
			if err := c.Start(ctx, h); err != nil {
				log.Printf("connector %s: %v", p, err)
				h.Status(p, "error:"+err.Error())
			}
		}()
	}
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		return err
	}
	go func() { <-ctx.Done(); ln.Close() }()
	log.Printf("hub listening on %s", addr)
	for {
		conn, err := ln.Accept()
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			return err
		}
		go h.serve(ctx, conn)
	}
}

func (h *Hub) serve(ctx context.Context, conn net.Conn) {
	c := &client{conn: conn, out: make(chan proto.Frame, 64)}
	h.mu.Lock()
	h.clients[c] = true
	h.mu.Unlock()
	defer func() {
		h.mu.Lock()
		delete(h.clients, c)
		h.mu.Unlock()
		conn.Close()
	}()

	go func() {
		enc := json.NewEncoder(conn)
		for f := range c.out {
			if enc.Encode(f) != nil {
				return
			}
		}
	}()
	defer close(c.out)

	sc := bufio.NewScanner(conn)
	sc.Buffer(make([]byte, 0, 64<<10), 4<<20)
	for sc.Scan() {
		var f proto.Frame
		if err := json.Unmarshal(sc.Bytes(), &f); err != nil {
			c.out <- proto.Frame{Op: "error", Error: "bad json"}
			continue
		}
		h.handle(ctx, c, f)
	}
}

func (h *Hub) handle(ctx context.Context, c *client, f proto.Frame) {
	switch f.Op {
	case "hello":
		h.mu.Lock()
		c.role, c.platform = f.Role, f.Platform
		var st map[string]string
		if f.Role == "ui" {
			st = map[string]string{}
			for k, v := range h.status {
				st[k] = v
			}
		}
		h.mu.Unlock()
		for p, d := range st {
			c.out <- proto.Frame{Op: "status", Platform: p, Data: d}
		}
	case "history":
		c.out <- proto.Frame{Op: "history", Messages: h.st.All()}
	case "ingest": // remote connector (e.g. iMessage tweak) reports a message
		if f.Message != nil {
			h.Ingest(*f.Message)
		}
	case "status":
		h.Status(f.Platform, f.Data)
	case "send":
		if err := h.send(ctx, f); err != nil {
			c.out <- proto.Frame{Op: "error", Error: err.Error()}
		}
	default:
		c.out <- proto.Frame{Op: "error", Error: "unknown op " + f.Op}
	}
}

func (h *Hub) send(ctx context.Context, f proto.Frame) error {
	if lc, ok := h.local[f.Platform]; ok {
		return lc.Send(ctx, f.Chat, f.Text)
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	for c := range h.clients {
		if c.role == "connector" && c.platform == f.Platform {
			select {
			case c.out <- f: // forwarded verbatim; connector performs the send
				return nil
			default:
				return errors.New("connector busy")
			}
		}
	}
	return fmt.Errorf("%w: %s", errNoConnector, f.Platform)
}

var errNoConnector = errors.New("no connector online for platform")
