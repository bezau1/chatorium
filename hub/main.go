// chatoriumd: on-device hub for Chatorium. Runs as a launchd daemon.
package main

import (
	"context"
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/bezau1/chatorium/hub/internal/connector"
	"github.com/bezau1/chatorium/hub/internal/connector/whatsapp"
	"github.com/bezau1/chatorium/hub/internal/server"
	"github.com/bezau1/chatorium/hub/internal/store"
)

func main() {
	dir := flag.String("data", "/var/jb/var/mobile/Library/Chatorium", "data directory")
	addr := flag.String("addr", "127.0.0.1:47474", "loopback listen address")
	flag.Parse()

	st, err := store.Open(*dir)
	if err != nil {
		log.Fatal(err)
	}
	locals := []connector.Connector{whatsapp.New(*dir)}
	hub := server.New(st, locals...)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	if err := hub.Run(ctx, *addr); err != nil {
		log.Fatal(err)
	}
}
