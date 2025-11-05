import { createServer } from 'http';
import { WebSocketServer } from 'ws';
import { nanoid } from 'nanoid';
import { getPrimaryAddress } from './utils/network.js';
import { renderQr } from './utils/qr.js';
import { parseMessage, isHeartbeat } from './utils/messages.js';
import { InputBridge } from './input/bridge.js';

const inputBridge = new InputBridge();
const clients = new Set();

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
  renderQr(payload);
});

process.on('SIGINT', () => {
  console.log('Shutting down host server');
  wsServer.close(() => {
    httpServer.close(() => process.exit(0));
  });
});
