// Package proto defines the newline-delimited JSON protocol spoken over the
// loopback socket by the UI app, the in-app tweaks (connectors) and the hub.
package proto

// Message is one chat message from any platform.
type Message struct {
	ID       string `json:"id"`
	Platform string `json:"platform"` // whatsapp | telegram | imessage
	ChatID   string `json:"chat"`
	ChatName string `json:"chatName,omitempty"`
	Sender   string `json:"sender,omitempty"`
	FromMe   bool   `json:"fromMe"`
	Text     string `json:"text"`
	Time     int64  `json:"time"` // unix seconds
}

// Frame is the envelope for every line on the wire.
//
// Client -> hub ops: hello, history, send, ingest, status
// Hub -> client ops: history, message, status, error
type Frame struct {
	Op       string    `json:"op"`
	Role     string    `json:"role,omitempty"`     // hello: "ui" | "connector"
	Platform string    `json:"platform,omitempty"` // hello(connector) / send / status
	Chat     string    `json:"chat,omitempty"`     // send
	Text     string    `json:"text,omitempty"`     // send
	Data     string    `json:"data,omitempty"`     // status payload (e.g. "qr:...")
	Message  *Message  `json:"message,omitempty"`  // ingest / message
	Messages []Message `json:"messages,omitempty"` // history
	Error    string    `json:"error,omitempty"`
}
