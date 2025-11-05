import os from 'os';

export function getPrimaryAddress() {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name] || []) {
      if (!iface) continue;
      const { address, family, internal } = iface;
      if (family === 'IPv4' && !internal) {
        return { address, interface: name };
      }
    }
  }
  return { address: '127.0.0.1', interface: 'loopback' };
}
