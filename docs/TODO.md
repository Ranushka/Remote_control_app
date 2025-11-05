# Project TODO

## Host App (Node.js)
- [ ] Implement macOS-specific input adapters using `robotjs` or native APIs for reliable mouse and keyboard control.
- [ ] Package the host as a notarized macOS menu bar application with auto-start at login.
- [ ] Persist per-client session UUIDs and QR code payload rotation.
- [ ] Add Bonjour/mDNS advertisement so that the controller can discover the host automatically without a QR code.
- [ ] Harden the WebSocket message validation and add configurable rate limiting.
- [ ] Provide integration tests that simulate controller messages end-to-end.

## Controller App (Flutter)
- [ ] Integrate a production-grade QR code scanner and validate payload signatures.
- [ ] Replace the placeholder touchpad implementation with a high-frequency gesture recognizer tuned for low latency.
- [ ] Implement haptic feedback and customizable gesture mappings in settings.
- [ ] Build specialty panels for media, volume, and power controls and wire them to the host command channel.
- [ ] Add localization and accessibility support (VoiceOver, large text, high-contrast themes).
- [ ] Implement persistent connection preferences and multiple host profiles.

## DevOps & Documentation
- [ ] Create CI workflows for linting, formatting, and running unit/widget tests.
- [ ] Produce setup guides for macOS and iOS developers, including code signing steps.
- [ ] Record a demo video that walks through pairing via QR code and controlling the Mac.
