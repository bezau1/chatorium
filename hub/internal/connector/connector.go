// Package connector defines what a platform backend running inside the hub looks like.
package connector

import (
	"context"

	"github.com/bezau1/chatorium/hub/internal/proto"
)

// Sink is how connectors hand data to the hub.
type Sink interface {
	Ingest(m proto.Message)
	Status(platform, data string)
}

type Connector interface {
	Platform() string
	Start(ctx context.Context, sink Sink) error
	Send(ctx context.Context, chat, text string) error
}
