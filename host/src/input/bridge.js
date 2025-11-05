let robotPromise;

async function loadRobot() {
  if (!robotPromise) {
    robotPromise = import('robotjs')
      .then(module => module?.default ?? module)
      .catch(() => null);
  }
  return robotPromise;
}

export class InputBridge {
  constructor(logger = console) {
    this.logger = logger;
  }

  async ensureRobot() {
    if (!this.robot) {
      this.robot = await loadRobot();
      if (!this.robot) {
        this.logger.warn('robotjs not available. Input events will be logged but not executed.');
      }
    }
    return this.robot;
  }

  async handleEvent(event) {
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
      case 'command':
        return this.handleCommand(event);
      default:
        this.logger.warn('Unhandled event type', event);
    }
  }

  async handleMouseMove({ deltaX = 0, deltaY = 0 }) {
    const robot = await this.ensureRobot();
    if (!robot) {
      this.logger.info('Mouse move', { deltaX, deltaY });
      return;
    }
    const position = robot.getMousePos();
    robot.moveMouse(position.x + deltaX, position.y + deltaY);
  }

  async handleMouseClick({ button = 'left', double = false }) {
    const robot = await this.ensureRobot();
    if (!robot) {
      this.logger.info('Mouse click', { button, double });
      return;
    }
    const mappedButton = button === 'right' ? 'right' : button === 'middle' ? 'middle' : 'left';
    robot.mouseClick(mappedButton, double);
  }

  async handleMouseScroll({ scrollX = 0, scrollY = 0 }) {
    const robot = await this.ensureRobot();
    if (!robot) {
      this.logger.info('Mouse scroll', { scrollX, scrollY });
      return;
    }
    robot.scrollMouse(scrollX, scrollY);
  }

  async handleKey({ key, action = 'tap', modifiers = [] }) {
    if (!key) {
      this.logger.warn('Missing key in key event');
      return;
    }
    const robot = await this.ensureRobot();
    if (!robot) {
      this.logger.info('Key event', { key, action, modifiers });
      return;
    }
    const normalized = Array.isArray(modifiers) ? modifiers.map(mod => mod.toLowerCase()) : [];
    if (action === 'press') {
      robot.keyToggle(key, 'down', normalized);
    } else if (action === 'release') {
      robot.keyToggle(key, 'up', normalized);
    } else {
      robot.keyTap(key, normalized);
    }
  }

  async handleCommand({ command, args = [] }) {
    this.logger.info('Received command', command, args);
    // Placeholder for implementing power/media commands via AppleScript.
  }
}
