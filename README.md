# Chatorium

All your chats (iMessage, WhatsApp, Telegram) in one jailbroken-iOS app, running **entirely on the device** — no external server.

Target: iOS 15, rootless (`THEOS_PACKAGE_SCHEME=rootless`), private use.

## Architecture

```
 Chatorium.app (UIKit)  ──┐
                          ├─ 127.0.0.1:47474, newline-delimited JSON ──  chatoriumd (Go, launchd daemon)
 ChatoriumIMessage tweak ─┘        (see hub/internal/proto)                 ├─ encrypted history (AES-256-GCM)
   (in SpringBoard: sms.db poll + IMCore send)                               ├─ WhatsApp: linked device (whatsmeow)
                                                                             └─ Telegram: TODO
```

* **hub/** – `chatoriumd`: routes UI ⇄ connectors, stores history encrypted at rest (`store.key` random per install).
* **tweaks/imessage/** – SpringBoard tweak: incoming iMessages from `sms.db`, outgoing through IMCore.
* **app/** – the unified inbox UI. Pairing QR for WhatsApp is shown here. "Call" opens the real app (FaceTime / WhatsApp / Telegram).

## Build

```bash
make hub            # static arm64 Go daemon -> app/layout/usr/local/bin/chatoriumd
make package        # needs Theos + iOS 15 SDK
```

## Status (honest)

| Part | State |
|---|---|
| Hub routing, encrypted store, dedupe | built + smoke-tested locally |
| WhatsApp connector | compiles for darwin/arm64; **pairing not yet tested on a device/network** |
| iMessage tweak, app | written, **not compiled or run** (needs Theos + a device); IMCore send path is the riskiest bit |
| Telegram | not started (plan: gotd/td MTProto session inside the hub, since Telegram-iOS is Swift and hard to hook) |
| LaunchDaemon postinst, auto-start | not done |
