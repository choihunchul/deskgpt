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
    viewController.includes('checkWebRendererMemoryUsage(reasonPrefix: "memory-pressure")'),
  'DeskGPT should check renderer memory safely when macOS reports memory pressure'
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
  viewController.includes('webRendererRecoveryCooldownSeconds: TimeInterval = 15 * 60') &&
    viewController.includes('lastWebRendererRecoveryAt') &&
    viewController.includes('lastWebRendererRecoveryRSSMB') &&
    viewController.includes('shouldDelayAutomaticWebRendererRecovery'),
  'DeskGPT should throttle automatic renderer recovery to prevent reload loops when RSS does not drop'
);

assert(
  viewController.includes('updateWindowTitle(webRendererRSSMB: rssMB)') &&
    viewController.includes('DeskGPT \\(shortVersion)') &&
    viewController.includes('Web \\(rssMB)MB'),
  'DeskGPT should show the app version and current Web renderer memory in the title bar'
);

assert(
  !viewController.includes('force: true') &&
    viewController.includes('recoverWebRendererIfSafe(reason: "\\(reasonPrefix)-hard-\\(rssMB)MB", rssMB: rssMB)') &&
    viewController.includes('showToast(message: "Web 렌더러 메모리 높음: \\(rssMB)MB")'),
  'DeskGPT watchdog should never force reload while the user may be scrolling or editing'
);

assert(
  viewController.includes('func recoverWebRenderer(reason: String = "manual")') &&
    viewController.includes('webView.reload()') &&
    viewController.includes('showLoadingOverlay(message: "Web 렌더러를 복구하는 중...")'),
  'DeskGPT should centralize renderer recovery in a dedicated method'
);
