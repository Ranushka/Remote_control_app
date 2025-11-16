import os from 'os';
import { createServer } from 'http';
import { WebSocketServer } from 'ws';
import { nanoid } from 'nanoid';
import { Bonjour } from 'bonjour-service';
import { getPrimaryAddress } from './utils/network.js';
import { renderQr } from './utils/qr.js';
import { parseMessage, isHeartbeat } from './utils/messages.js';
import { InputBridge } from './input/bridge.js';

const inputBridge = new InputBridge();
const clients = new Set();
const bonjour = new Bonjour();
const SERVICE_TYPE = 'remotecontrol';
let bonjourService;

const httpServer = createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(
    JSON.stringify({
      status: 'ok',
      message: 'Remote control host WebSocket server',
      clients: clients.size
    })
  );
});

const wsServer = new WebSocketServer({ server: httpServer });

function broadcastStatus() {
  const payload = JSON.stringify({ type: 'status', connectedClients: clients.size });
  for (const ws of clients) {
    if (ws.readyState === ws.OPEN) {
      ws.send(payload);
    }
  }
}

wsServer.on('connection', ws => {
  clients.add(ws);
  console.log('Client connected');
  broadcastStatus();

  ws.on('message', async data => {
    const payload = parseMessage(data.toString());
    if (payload.type === 'invalid') {
      ws.send(JSON.stringify({ type: 'error', message: payload.error }));
      return;
    }
    if (isHeartbeat(payload)) {
      ws.send(JSON.stringify({ type: 'heartbeat_ack', timestamp: Date.now() }));
      return;
    }

    await inputBridge.handleEvent(payload);
  });

  ws.on('close', () => {
    clients.delete(ws);
    console.log('Client disconnected');
    broadcastStatus();
  });

  ws.on('error', error => {
    console.error('WebSocket error', error);
  });

  ws.send(JSON.stringify({ type: 'welcome', timestamp: Date.now() }));
});

const { address: ipAddress } = getPrimaryAddress();
const port = process.env.PORT ? Number(process.env.PORT) : 0;

httpServer.listen(port, '0.0.0.0', () => {
  const { port: boundPort } = httpServer.address();
  const sessionId = nanoid();
  const payload = { protocol: 'ws', host: ipAddress, port: boundPort, sessionId };
  console.log('Remote control host ready on', `ws://${ipAddress}:${boundPort}`);
  bonjourService = bonjour.publish({
    name: `Remote Control Host (${os.hostname()})`,
    type: SERVICE_TYPE,
    host: ipAddress,
    port: boundPort,
    txt: {
      host: ipAddress,
      sessionId,
      protocol: 'ws'
    }
  });
  bonjourService.on('up', () => {
    console.log('Bonjour service published: %s at %s:%d', bonjourService.fqdn, ipAddress, boundPort);
    console.log('Bonjour TXT record:', bonjourService.txt);
  });
  bonjourService.on('error', error => {
    console.error('Bonjour service error', error);
  });
  renderQr(payload);
});

function shutdown() {
  console.log('Shutting down host server');
  bonjour.unpublishAll(() => {
    bonjour.destroy();
  });
  wsServer.close(() => {
    httpServer.close(() => process.exit(0));
  });
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
