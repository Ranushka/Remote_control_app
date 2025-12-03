import { exec, execFile } from 'child_process';

let robotPromise;

async function loadRobot() {
  if (!robotPromise) {
    robotPromise = import('robotjs')
      .then(m => m?.default ?? m)
      .catch(() => null);
  }
  return robotPromise;
}

export class InputBridge {
  constructor(logger = console) {
    this.logger = logger;
    this.mouseResidual = { x: 0, y: 0 };
    this.commandAvailability = new Map();
    this.missingCommandLogged = new Set();
  }

  async ensureRobot() {
    if (!this.robot) {
      this.robot = await loadRobot();
      if (!this.robot) {
        this.logger.warn('robotjs not available, using fallback.');
        return null;
      }
      try {
        this.robot.getMousePos();
      } catch {
        this.logger.warn('robotjs blocked by macOS. Enable Accessibility permissions.');
        this.robot = null;
      }
    }
    return this.robot;
  }

  async commandExists(command) {
    if (this.commandAvailability.has(command)) {
      return this.commandAvailability.get(command);
    }
    const exists = await new Promise(resolve => {
      exec(`command -v ${command}`, err => resolve(!err));
    });
    this.commandAvailability.set(command, exists);
    return exists;
  }

  async ensureCommand(command, purpose) {
    const exists = await this.commandExists(command);
    if (!exists && !this.missingCommandLogged.has(command)) {
      this.logger.warn(
        `${purpose || 'Operation'} unavailable because "${command}" is not installed on this system.`
      );
      this.missingCommandLogged.add(command);
    }
    return exists;
  }

  async runCommand(command, args = [], label = command) {
    return new Promise(resolve => {
      execFile(command, args, (err, stdout, stderr) => {
        if (err) {
          this.logger.error(`${label} failed`, err, stderr?.toString().trim() || '');
          return resolve(false);
        }
        return resolve(true);
      });
    });
  }

  mapModifier(mod) {
    const normalized = `${mod ?? ''}`.toLowerCase();
    if (['command', 'cmd', 'super', 'meta', 'win', 'windows'].includes(normalized)) return 'super';
    if (['control', 'ctrl', 'ctl'].includes(normalized)) return 'ctrl';
    if (['option', 'alt'].includes(normalized)) return 'alt';
    if (normalized === 'shift') return 'shift';
    if (normalized === 'capslock') return 'caps';
    return normalized || null;
  }

  async handleEvent(event) {
    console.log('Handling event:', event);
    if (!event || typeof event !== 'object') return;
    try {
      switch (event.type) {
        case 'mouse_move':
          return this.handleMouseMove(event);
        case 'mouse_click':
          return this.handleMouseClick(event);
        case 'mouse_scroll':
          return this.handleMouseScroll(event);
        case 'key_press':
        case 'key_tap':
          return this.handleKey(event);
        case 'text_input':
          return this.handleTextInput(event);
        case 'command':
          return this.handleCommand(event);
      }
    } catch (err) {
      this.logger.error('Error handling event', err);
    }
  }

  async handleMouseMove({ deltaX = 0, deltaY = 0 }) {
    const robot = await this.ensureRobot();
    try {
      this.mouseResidual.x += deltaX;
      this.mouseResidual.y += deltaY;

      const moveX = Math.trunc(this.mouseResidual.x);
      const moveY = Math.trunc(this.mouseResidual.y);
      if (moveX === 0 && moveY === 0) return;

      this.mouseResidual.x -= moveX;
      this.mouseResidual.y -= moveY;

      if (robot) {
        const pos = robot.getMousePos();
        const newX = pos.x + moveX;
        const newY = pos.y + moveY;
        robot.moveMouse(newX, newY);
        this.logger.info(`Mouse moved to (${newX}, ${newY})`);
      } else if (process.platform === 'linux' && (await this.ensureCommand('xdotool', 'Mouse move'))) {
        await this.runCommand(
          'xdotool',
          ['mousemove_relative', '--', String(moveX), String(moveY)],
          'Mouse move (xdotool)'
        );
        this.logger.info(`Mouse moved (xdotool) by (${moveX}, ${moveY})`);
      } else if (process.platform === 'darwin') {
        const { x, y } = await this.moveMouseWithJxa(moveX, moveY);
        this.logger.info(`Mouse moved (JXA) to (${x}, ${y})`);
      } else {
        this.logger.info('Mouse move skipped', { deltaX, deltaY });
      }
    } catch (err) {
      this.logger.error('Mouse move failed', err);
    }
  }

  async handleMouseClick({ button = 'left', double = false }) {
    const robot = await this.ensureRobot();
    try {
      const mapped = button === 'right' ? 'right' : button === 'middle' ? 'middle' : 'left';
      if (robot) {
        robot.mouseClick(mapped, double);
        this.logger.info(`Mouse ${mapped} ${double ? 'double' : 'single'} click`);
      } else if (
        process.platform === 'linux' &&
        (await this.ensureCommand('xdotool', 'Mouse click'))
      ) {
        const buttonMap = { left: '1', middle: '2', right: '3' };
        const repeatArgs = double ? ['--repeat', '2', '--delay', '120'] : [];
        await this.runCommand(
          'xdotool',
          ['click', ...repeatArgs, buttonMap[mapped] ?? '1'],
          'Mouse click (xdotool)'
        );
        this.logger.info(`Mouse click (xdotool) ${mapped} ${double ? 'double' : 'single'}`);
      } else if (process.platform === 'darwin') {
        const cmd =
          mapped === 'right'
            ? 'tell application "System Events" to right click (the front window)'
            : 'tell application "System Events" to click (the front window)';
        exec(`osascript -e ${JSON.stringify(cmd)}`, err => {
          if (err) this.logger.error('AppleScript click failed', err);
        });
        this.logger.info(`Mouse click (AppleScript) ${mapped}`);
      } else {
        this.logger.info('Mouse click skipped', { button, double });
      }
    } catch (err) {
      this.logger.error('Mouse click failed', err);
    }
  }

  async handleMouseScroll({ scrollX = 0, scrollY = 0 }) {
    const robot = await this.ensureRobot();
    try {
      if (robot) {
        robot.scrollMouse(Math.round(scrollX), Math.round(scrollY));
        this.logger.info(`Mouse scrolled (${scrollX}, ${scrollY})`);
      } else if (
        process.platform === 'linux' &&
        (await this.ensureCommand('xdotool', 'Mouse scroll'))
      ) {
        const tasks = [];
        const xSteps = Math.trunc(scrollX);
        const ySteps = Math.trunc(scrollY);

        if (ySteps !== 0) {
          const button = ySteps > 0 ? '5' : '4';
          tasks.push(
            this.runCommand(
              'xdotool',
              ['click', '--repeat', String(Math.abs(ySteps)), '--delay', '5', button],
              'Mouse vertical scroll (xdotool)'
            )
          );
        }
        if (xSteps !== 0) {
          const button = xSteps > 0 ? '7' : '6';
          tasks.push(
            this.runCommand(
              'xdotool',
              ['click', '--repeat', String(Math.abs(xSteps)), '--delay', '5', button],
              'Mouse horizontal scroll (xdotool)'
            )
          );
        }

        if (tasks.length === 0) return;
        await Promise.all(tasks);
        this.logger.info(`Mouse scroll (xdotool) (${scrollX}, ${scrollY})`);
      } else if (process.platform === 'darwin') {
        const script = `tell application "System Events" to key code 125 using command down`;
        exec(`osascript -e ${JSON.stringify(script)}`);
        this.logger.info('Mouse scroll (AppleScript)');
      } else {
        this.logger.info('Mouse scroll skipped', { scrollX, scrollY });
      }
    } catch (err) {
      this.logger.error('Mouse scroll failed', err);
    }
  }

  async handleKey({ key, action = 'tap', modifiers = [] }) {
    if (!key) return;
    const robot = await this.ensureRobot();
    try {
      const mods = Array.isArray(modifiers) ? modifiers.map(m => m.toLowerCase()) : [];
      if (robot) {
        if (action === 'press') robot.keyToggle(key, 'down', mods);
        else if (action === 'release') robot.keyToggle(key, 'up', mods);
        else robot.keyTap(key, mods);
        this.logger.info(`Key ${key} ${action}`);
      } else if (
        process.platform === 'linux' &&
        (await this.ensureCommand('xdotool', 'Keyboard input'))
      ) {
        const mappedMods = mods.map(m => this.mapModifier(m)).filter(Boolean);
        const combo = [...mappedMods, key].join('+');
        const args =
          action === 'press'
            ? ['keydown', '--clearmodifiers', combo]
            : action === 'release'
            ? ['keyup', '--clearmodifiers', combo]
            : ['key', '--clearmodifiers', combo];
        await this.runCommand('xdotool', args, 'Key event (xdotool)');
        this.logger.info(`Key (xdotool) ${key} ${action}`);
      } else if (process.platform === 'darwin') {
        const cmd = `tell application "System Events" to keystroke "${key}"`;
        exec(`osascript -e ${JSON.stringify(cmd)}`);
        this.logger.info(`Key (AppleScript) ${key}`);
      } else {
        this.logger.info('Key skipped', { key, action, modifiers });
      }
    } catch (err) {
      this.logger.error('Key failed', err);
    }
  }

  async handleTextInput({ text = '' }) {
    if (!text) return;
    const robot = await this.ensureRobot();
    try {
      if (robot) {
        robot.typeString(text);
        this.logger.info(`Text typed: ${text}`);
      } else if (
        process.platform === 'linux' &&
        (await this.ensureCommand('xdotool', 'Text input'))
      ) {
        await this.runCommand(
          'xdotool',
          ['type', '--delay', '0', '--clearmodifiers', '--', text],
          'Text input (xdotool)'
        );
        this.logger.info(`Text typed (xdotool): ${text}`);
      } else if (process.platform === 'darwin') {
        // Use AppleScript to type each character
        for (const char of text) {
          const cmd = `tell application "System Events" to keystroke "${char.replace(/"/g, '\\"')}"`;
          await new Promise(resolve => {
            exec(`osascript -e ${JSON.stringify(cmd)}`, resolve);
          });
        }
        this.logger.info(`Text typed (AppleScript): ${text}`);
      } else {
        this.logger.info('Text input skipped', { text });
      }
    } catch (err) {
      this.logger.error('Text input failed', err);
    }
  }

  async handleCommand({ command, args = [] }) {
    this.logger.info('Received command', command, args);
    try {
      const raw = `${command ?? ''}`.trim().toLowerCase();
      const dot = raw.replace(/[_\s-]+/g, '.');
      const snake = raw.replace(/[.\s-]+/g, '_');
      if (
        dot === 'media.volume_up' ||
        dot === 'volume.up' ||
        snake === 'media_volume_up' ||
        snake === 'volume_up'
      )
        return this.adjustVolume('up', args);
      if (
        dot === 'media.volume_down' ||
        dot === 'volume.down' ||
        snake === 'media_volume_down' ||
        snake === 'volume_down'
      )
        return this.adjustVolume('down', args);
      if (
        dot === 'volume.mute' ||
        dot === 'media.volume_mute' ||
        dot === 'media.mute' ||
        snake === 'volume_mute' ||
        snake === 'media_volume_mute' ||
        snake === 'media_mute'
      )
        return this.toggleMute(args);
      this.logger.warn('Unhandled command', command, args);
    } catch (err) {
      this.logger.error('Error handling command', command, err);
    }
  }

  async adjustVolume(direction = 'up', args = []) {
    const step = Number(args?.[0]) || 6;
    const delta = Math.max(1, Math.round(step));
    if (process.platform === 'darwin') {
      const op = direction === 'up' ? '+' : '-';
      const apple = [
        `set curVolume to output volume of (get volume settings)`,
        `set newVolume to curVolume ${op} ${delta}`,
        `if newVolume > 100 then set newVolume to 100`,
        `if newVolume < 0 then set newVolume to 0`,
        `set volume output volume newVolume`
      ]
        .map(s => `-e ${JSON.stringify(s)}`)
        .join(' ');
      await new Promise((resolve, reject) => {
        exec(`osascript ${apple}`, (err, stdout, stderr) => {
          if (err) {
            this.logger.error('AppleScript error', err, stderr);
            return reject(err);
          }
          this.logger.info(`Volume ${direction} by ${delta}%`);
          resolve();
        });
      });
      return;
    }

    if (process.platform === 'linux') {
      const pactlAvailable = await this.ensureCommand('pactl', 'Volume control');
      const amixerAvailable =
        pactlAvailable || (await this.ensureCommand('amixer', 'Volume control'));

      if (pactlAvailable) {
        const change = `${direction === 'up' ? '+' : '-'}${delta}%`;
        await this.runCommand(
          'pactl',
          ['set-sink-volume', '@DEFAULT_SINK@', change],
          'Volume adjust (pactl)'
        );
        this.logger.info(`Volume ${direction} by ${delta}% (pactl)`);
        return;
      }
      if (amixerAvailable) {
        const change = direction === 'up' ? `${delta}%+` : `${delta}%-`;
        await this.runCommand('amixer', ['set', 'Master', change], 'Volume adjust (amixer)');
        this.logger.info(`Volume ${direction} by ${delta}% (amixer)`);
        return;
      }
      return;
    }

    this.logger.warn('Volume control not supported on this platform');
  }

  async moveMouseWithJxa(deltaX, deltaY) {
    const script = `
ObjC.import('ApplicationServices');
function run(argv) {
  const dx = Number(argv[0]) || 0;
  const dy = Number(argv[1]) || 0;
  const currentEvent = $.CGEventCreate(null);
  const current = $.CGEventGetLocation(currentEvent);
  const destination = { x: current.x + dx, y: current.y + dy };
  const moveEvent = $.CGEventCreateMouseEvent(
    null,
    $.kCGEventMouseMoved,
    destination,
    $.kCGMouseButtonLeft
  );
  $.CGEventPost($.kCGHIDEventTap, moveEvent);
  return JSON.stringify(destination);
}`;
    return new Promise(resolve => {
      const cmd = `osascript -l JavaScript -e ${JSON.stringify(script)} ${JSON.stringify(
        deltaX
      )} ${JSON.stringify(deltaY)}`;
      exec(cmd, (err, stdout, stderr) => {
        if (err) {
          this.logger.error('JXA mouse move failed', err, stderr);
          return resolve({ x: 0, y: 0 });
        }
        try {
          const parsed = JSON.parse(stdout.trim());
          const x = Number(parsed?.x);
          const y = Number(parsed?.y);
          if (Number.isFinite(x) && Number.isFinite(y)) {
            return resolve({ x, y });
          }
        } catch (parseErr) {
          this.logger.error('JXA mouse move parse error', parseErr);
        }
        resolve({ x: 0, y: 0 });
      });
    });
  }

  async toggleMute(args = []) {
    const mode = `${args?.[0] ?? ''}`.toLowerCase();
    if (process.platform === 'darwin') {
      const scriptLines = ['set isMuted to output muted of (get volume settings)'];

      if (mode === 'on' || mode === 'true') {
        scriptLines.push('if isMuted is false then set volume with output muted');
      } else if (mode === 'off' || mode === 'false') {
        scriptLines.push('if isMuted then set volume without output muted');
      } else {
        scriptLines.push('if isMuted then');
        scriptLines.push('  set volume without output muted');
        scriptLines.push('else');
        scriptLines.push('  set volume with output muted');
        scriptLines.push('end if');
      }

      const apple = scriptLines.map(s => `-e ${JSON.stringify(s)}`).join(' ');
      await new Promise((resolve, reject) => {
        exec(`osascript ${apple}`, (err, stdout, stderr) => {
          if (err) {
            this.logger.error('AppleScript mute toggle failed', err, stderr);
            return reject(err);
          }
          const stateLabel =
            mode === 'on' || mode === 'true'
              ? 'muted'
              : mode === 'off' || mode === 'false'
              ? 'unmuted'
              : 'toggled';
          this.logger.info(`Volume ${stateLabel}`);
          resolve();
        });
      });
      return;
    }

    if (process.platform === 'linux') {
      const pactlAvailable = await this.ensureCommand('pactl', 'Mute control');
      const amixerAvailable =
        pactlAvailable || (await this.ensureCommand('amixer', 'Mute control'));

      const modeLabel =
        mode === 'on' || mode === 'true'
          ? 'on'
          : mode === 'off' || mode === 'false'
          ? 'off'
          : 'toggle';

      if (pactlAvailable) {
        const arg = modeLabel === 'toggle' ? 'toggle' : modeLabel === 'on' ? '1' : '0';
        await this.runCommand(
          'pactl',
          ['set-sink-mute', '@DEFAULT_SINK@', arg],
          'Mute control (pactl)'
        );
        this.logger.info(`Mute ${modeLabel} (pactl)`);
        return;
      }
      if (amixerAvailable) {
        const arg = modeLabel === 'toggle' ? 'toggle' : modeLabel === 'on' ? 'mute' : 'unmute';
        await this.runCommand('amixer', ['set', 'Master', arg], 'Mute control (amixer)');
        this.logger.info(`Mute ${modeLabel} (amixer)`);
        return;
      }
      return;
    }

    this.logger.warn('Mute control not supported on this platform');
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const bridge = new InputBridge(console);
  bridge.handleEvent({ type: 'mouse_move', deltaX: 100, deltaY: 50 });
  bridge.handleEvent({ type: 'mouse_click', button: 'left' });
  bridge.handleEvent({ type: 'command', command: 'volume.up', args: [10] });
}
