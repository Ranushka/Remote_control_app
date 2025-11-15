const VALID_TYPES = new Set([
  'mouse_move',
  'mouse_click',
  'mouse_scroll',
  'key_press',
  'key_tap',
  'text_input',
  'command',
  'heartbeat'
]);

export function parseMessage(raw) {
  try {
    const payload = JSON.parse(raw);
    if (!payload || typeof payload !== 'object') {
      throw new Error('Invalid payload shape');
    }
    if (!VALID_TYPES.has(payload.type)) {
      throw new Error(`Unsupported event type: ${payload.type}`);
    }
    return payload;
  } catch (error) {
    return { type: 'invalid', error: error instanceof Error ? error.message : 'Unknown error' };
  }
}

export function isHeartbeat(payload) {
  return payload.type === 'heartbeat';
}
