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
  viewController.includes('webRendererWarningThresholdMB = 500') &&
    viewController.includes('webRendererAutoRecoverThresholdMB = 800') &&
    viewController.includes('webRendererHardRecoverThresholdMB = 1_000'),
  'DeskGPT should use 500MB warning, 800MB auto, and 1GB hard renderer memory thresholds'
);

assert(
  viewController.includes('startWebRendererMemoryWatchdog()') &&
    viewController.includes('DispatchSource.makeTimerSource') &&
    viewController.includes('currentWebContentProcessIdentifier()') &&
    viewController.includes('residentMemoryMegabytes(for:') &&
    viewController.includes('_webProcessIdentifier') &&
    viewController.includes('proc_pidinfo'),
  'DeskGPT should run a lightweight renderer RSS watchdog without shelling out to ps'
);

assert(
  viewController.includes('func recoverWebRenderer(reason: String = "manual")') &&
    viewController.includes('webView.reload()') &&
    viewController.includes('showLoadingOverlay(message: "Web 렌더러를 복구하는 중...")'),
  'DeskGPT should centralize renderer recovery in a dedicated method'
);
