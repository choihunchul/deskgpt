const fs = require('fs');
const path = require('path');
const assert = require('assert');

const root = path.resolve(__dirname, '..');
const appDelegate = fs.readFileSync(path.join(root, 'src', 'AppDelegate.swift'), 'utf8');
const viewController = fs.readFileSync(path.join(root, 'src', 'DeskGPTViewController.swift'), 'utf8');

assert(
  appDelegate.includes('복구 (Recover Web Renderer)') &&
    appDelegate.includes('#selector(recoverWebRendererAction)') &&
    appDelegate.includes('viewController?.recoverWebRenderer'),
  'DeskGPT should expose a Help menu action that recovers the WebKit renderer without clearing the session'
);

assert(
  viewController.includes('DispatchSource.makeMemoryPressureSource') &&
    viewController.includes('recoverWebRenderer(reason: "memory-pressure")'),
  'DeskGPT should auto-recover the WebKit renderer when macOS reports memory pressure'
);

assert(
  viewController.includes('func recoverWebRenderer(reason: String = "manual")') &&
    viewController.includes('webView.reload()') &&
    viewController.includes('showLoadingOverlay(message: "Web 렌더러를 복구하는 중...")'),
  'DeskGPT should centralize renderer recovery in a dedicated method'
);
