# Remote Control Host (Node.js)

This package exposes a lightweight WebSocket server that the iOS/iPadOS controller can use to deliver mouse and keyboard events to a Mac.

## Features

- Detects the primary IPv4 address and spins up a WebSocket server.
- Prints a QR code containing the connection payload (`ws://<ip>:<port>` and session identifier).
- Parses controller messages for mouse, keyboard, scroll, and custom commands.
- Delegates to a pluggable `InputBridge` that uses [`robotjs`](https://github.com/octalmage/robotjs) when available, otherwise logs events for development.

## Getting Started

```bash
cd host
npm install
npm start
```

When the server boots it will display a QR code in the terminal. Scan the code with the Flutter controller app to pair immediately.

## Message Format

The server expects UTF-8 JSON messages with a `type` field and shape matching the examples below:

```json
{"type":"mouse_move","deltaX":12,"deltaY":-8}
{"type":"mouse_click","button":"left","double":false}
{"type":"mouse_scroll","scrollX":0,"scrollY":-24}
{"type":"key_press","key":"a","action":"tap","modifiers":["command"]}
{"type":"command","command":"media.play_pause"}
```

Heartbeat messages should be sent every few seconds to keep the connection alive:

```json
{"type":"heartbeat"}
```

The host will respond with `heartbeat_ack` messages containing a timestamp.

## Next Steps

- Implement AppleScript-based handlers inside `InputBridge.handleCommand` for power and media controls.
- Wrap the Node server with an Electron shell to surface a persistent status indicator and menu bar controls.
- Harden security by introducing optional pairing PINs and TLS certificates.
