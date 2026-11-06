// Package whatsapp links Chatorium to WhatsApp as a "linked device" (multi-device
// protocol) using whatsmeow. No injection into the WhatsApp app is needed.
package whatsapp

import (
	"context"
	"fmt"
	"path/filepath"
	"strings"

	_ "modernc.org/sqlite" // pure-Go driver, registers "sqlite"

	"go.mau.fi/whatsmeow"
	waE2E "go.mau.fi/whatsmeow/proto/waE2E"
	"go.mau.fi/whatsmeow/store/sqlstore"
	"go.mau.fi/whatsmeow/types"
	"go.mau.fi/whatsmeow/types/events"
	waLog "go.mau.fi/whatsmeow/util/log"
	"google.golang.org/protobuf/proto"

	"github.com/bezau1/chatorium/hub/internal/connector"
	cp "github.com/bezau1/chatorium/hub/internal/proto"
)

type WA struct {
	dir    string
	client *whatsmeow.Client
	sink   connector.Sink
}

func New(dataDir string) *WA { return &WA{dir: dataDir} }

func (w *WA) Platform() string { return "whatsapp" }

func (w *WA) Start(ctx context.Context, sink connector.Sink) error {
	w.sink = sink
	dsn := fmt.Sprintf("file:%s?_pragma=foreign_keys(1)", filepath.Join(w.dir, "whatsapp.db"))
	container, err := sqlstore.New(ctx, "sqlite", dsn, waLog.Noop)
	if err != nil {
		return err
	}
	dev, err := container.GetFirstDevice(ctx)
	if err != nil {
		return err
	}
	w.client = whatsmeow.NewClient(dev, waLog.Noop)
	w.client.AddEventHandler(w.onEvent)

	if w.client.Store.ID == nil { // not paired yet: surface QR codes to the UI
		qrs, err := w.client.GetQRChannel(ctx)
		if err != nil {
			return err
		}
		if err := w.client.Connect(); err != nil {
			return err
		}
		go func() {
			for e := range qrs {
				if e.Event == "code" {
					sink.Status("whatsapp", "qr:"+e.Code)
				} else {
					sink.Status("whatsapp", "pair:"+e.Event)
				}
			}
		}()
		return nil
	}
	if err := w.client.Connect(); err != nil {
		return err
	}
	sink.Status("whatsapp", "connected")
	return nil
}

func (w *WA) onEvent(raw interface{}) {
	switch e := raw.(type) {
	case *events.PairSuccess:
		w.sink.Status("whatsapp", "connected")
	case *events.Connected:
		w.sink.Status("whatsapp", "connected")
	case *events.Disconnected:
		w.sink.Status("whatsapp", "disconnected")
	case *events.Message:
		text := e.Message.GetConversation()
		if text == "" {
			text = e.Message.GetExtendedTextMessage().GetText()
		}
		if text == "" {
			return // media etc. not handled yet
		}
		w.sink.Ingest(cp.Message{
			ID:       e.Info.ID,
			Platform: "whatsapp",
			ChatID:   e.Info.Chat.String(),
			ChatName: e.Info.PushName,
			Sender:   e.Info.Sender.String(),
			FromMe:   e.Info.IsFromMe,
			Text:     text,
			Time:     e.Info.Timestamp.Unix(),
		})
	}
}

// Send accepts a full JID ("123@s.whatsapp.net") or a bare phone number.
func (w *WA) Send(ctx context.Context, chat, text string) error {
	if w.client == nil || !w.client.IsLoggedIn() {
		return fmt.Errorf("whatsapp not connected")
	}
	jid, err := types.ParseJID(chat)
	if err != nil || !strings.Contains(chat, "@") {
		jid = types.NewJID(strings.TrimPrefix(chat, "+"), types.DefaultUserServer)
	}
	_, err = w.client.SendMessage(ctx, jid, &waE2E.Message{Conversation: proto.String(text)})
	return err
}
