# Remote Control App

This repository contains a proof-of-concept implementation of the **Remote Control** system described in the project brief. It consists of:

- A **Node.js host app** that runs on macOS, exposes a WebSocket server, and displays a QR code for pairing.
- A **Flutter controller app** for iPhone/iPad that can scan the QR code, connect to the host, and relay mouse/keyboard/command events.
- A shared **project TODO list** that outlines next steps required to reach production quality.

## Repository Structure

```
.
├── docs/                Project notes and TODO list
├── host/                Node.js host service
└── controller_app/      Flutter client
```

### Host (Node.js)

See [`host/README.md`](host/README.md) for setup instructions. After installing dependencies you can run `npm start` to boot the WebSocket server. When it starts, it prints a QR code payload containing the IP address, port, and session identifier. The host parses incoming JSON messages from the controller and forwards them to a pluggable `InputBridge`. When [`robotjs`](https://github.com/octalmage/robotjs) is available it will trigger native mouse and keyboard events; otherwise the events are logged, which is handy when developing on non-macOS environments.

### Controller (Flutter)

The Flutter app lives under `controller_app/` and is built with Material 3 and `flutter_hooks`. The home screen displays connection status, touchpad surface, quick command buttons, and allows adjusting pointer sensitivity. Tapping the QR button opens a camera overlay powered by `mobile_scanner`; once a QR code emitted by the host is scanned, the app establishes a WebSocket connection and begins streaming events.

> **Note:** The repository does not vendor Flutter SDK binaries. Follow the [Flutter installation guide](https://docs.flutter.dev/get-started/install) to set up your environment before running the app locally.

## Getting Started

1. **Host app**
   ```bash
   cd host
   npm install
   npm start
   ```
2. **Controller app**
   ```bash
   cd controller_app
   flutter pub get
   flutter run
   ```

For development without hardware, you can run the host server locally and connect from an iOS Simulator. The QR payload is plain JSON, so you can copy/paste it into the simulator by long-pressing the QR overlay and pasting the text payload during development.

## License

This proof-of-concept is provided without an explicit license. Add one before distributing the binaries.
