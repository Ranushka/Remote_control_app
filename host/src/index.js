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
const MAX_RESTART_ATTEMPTS = 3;

let bonjourService;
let httpServer;
let wsServer;
let shuttingDown = false;
let restarting = false;
let restartAttempts = 0;

function createHttpServer() {
  return createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(
      JSON.stringify({
        status: 'ok',
        message: 'Remote control host WebSocket server',
        clients: clients.size
      })
    );
  });
}

function broadcastStatus() {
  const payload = JSON.stringify({ type: 'status', connectedClients: clients.size });
  for (const ws of clients) {
    if (ws.readyState === ws.OPEN) {
      ws.send(payload);
    }
  }
}

function handleConnection(ws) {
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
}

function attachWebSocketServer(server) {
  const socketServer = new WebSocketServer({ server });
  socketServer.on('connection', handleConnection);
  socketServer.on('error', error => {
    console.error('WebSocket server error', error);
    handleFatal('WebSocket server error', error);
  });
  return socketServer;
}

function publishBonjour(ipAddress, boundPort, sessionId) {
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
    handleFatal('Bonjour service error', error);
  });
}

function startHost() {
  if (shuttingDown) return;
  const { address: ipAddress } = getPrimaryAddress();
  const port = process.env.PORT ? Number(process.env.PORT) : 0;
  httpServer = createHttpServer();
  httpServer.on('error', error => {
    console.error('HTTP server error', error);
    handleFatal('HTTP server error', error);
  });
  httpServer.on('close', () => {
    if (!shuttingDown) {
      console.warn('HTTP server closed unexpectedly');
      handleFatal('HTTP server closed', new Error('HTTP server closed'));
    }
  });
  wsServer = attachWebSocketServer(httpServer);

  httpServer.listen(port, '0.0.0.0', () => {
    restartAttempts = 0;
    const { port: boundPort } = httpServer.address();
    const sessionId = nanoid();
    const payload = { protocol: 'ws', host: ipAddress, port: boundPort, sessionId };
    console.log('Remote control host ready on', `ws://${ipAddress}:${boundPort}`);
    publishBonjour(ipAddress, boundPort, sessionId);
    renderQr(payload);
  });
}

async function cleanupContext() {
  const tasks = [];
  if (bonjourService) {
    tasks.push(
      new Promise(resolve => {
        try {
          const service = bonjourService;
          bonjourService = null;
          service.stop(() => resolve());
        } catch (error) {
          console.warn('Error stopping bonjour service', error);
          resolve();
        }
      })
    );
  }
  if (wsServer) {
    tasks.push(
      new Promise(resolve => {
        const server = wsServer;
        wsServer = null;
        server.close(() => resolve());
      })
    );
  }
  if (httpServer) {
    tasks.push(
      new Promise(resolve => {
        const server = httpServer;
        httpServer = null;
        server.close(() => resolve());
      })
    );
  }
  clients.clear();
  if (tasks.length) {
    await Promise.allSettled(tasks);
  }
}

async function handleFatal(reason, error) {
  if (shuttingDown || restarting) {
    return;
  }
  restarting = true;
  console.error(`Host encountered a fatal issue (${reason}).`);
  if (error) {
    console.error(error);
  }
  await cleanupContext();
  if (restartAttempts >= MAX_RESTART_ATTEMPTS) {
    console.error('Max restart attempts reached. Exiting.');
    process.exit(1);
    return;
  }
  restartAttempts += 1;
  console.log(`Restarting host (attempt ${restartAttempts}/${MAX_RESTART_ATTEMPTS})…`);
  try {
    startHost();
  } finally {
    restarting = false;
  }
}

async function shutdown() {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log('Shutting down host server');
  await cleanupContext();
  bonjour.unpublishAll(() => {
    bonjour.destroy();
    process.exit(0);
  });
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
process.on('uncaughtException', error => {
  console.error('Uncaught exception', error);
  handleFatal('uncaughtException', error);
});
process.on('unhandledRejection', error => {
  console.error('Unhandled promise rejection', error);
  handleFatal('unhandledRejection', error instanceof Error ? error : new Error(String(error)));
});

startHost();
