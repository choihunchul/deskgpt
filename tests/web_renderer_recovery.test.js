const fs = require('fs');
const path = require('path');
const assert = require('assert');

const root = path.resolve(__dirname, '..');
const appDelegate = fs.readFileSync(path.join(root, 'src', 'AppDelegate.swift'), 'utf8');
const viewController = fs.readFileSync(path.join(root, 'src', 'DeskGPTViewController.swift'), 'utf8');
const buildScript = fs.readFileSync(path.join(root, 'build.sh'), 'utf8');

assert(
  appDelegate.includes('복구 (Recover Web Renderer)') &&
    appDelegate.includes('#selector(recoverWebRendererAction)') &&
    appDelegate.includes('viewController?.recoverWebRenderer'),
  'DeskGPT should expose a Help menu action that recovers the WebKit renderer without clearing the session'
);

assert(
  viewController.includes('DispatchSource.makeMemoryPressureSource') &&
    viewController.includes('eventMask: [.normal, .warning, .critical]') &&
    viewController.includes('isSystemMemoryPressureCritical'),
  'DeskGPT should use macOS critical memory pressure as the automatic recovery gate'
);

assert(
  viewController.includes('webRendererWarningThresholdMB = 500') &&
    viewController.includes('webRendererEmergencyThresholdMB = 1_500') &&
    viewController.includes('webRendererEmergencySampleCount = 3') &&
    !viewController.includes('webRendererAutoRecoverThresholdMB') &&
    !viewController.includes('webRendererHardRecoverThresholdMB'),
  'DeskGPT should warn at 500MB and reserve automatic recovery for sustained 1.5GB emergencies'
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
  viewController.includes('consecutiveEmergencyMemorySamples') &&
    viewController.includes('isSystemMemoryPressureCritical') &&
    viewController.includes('!NSApp.isActive') &&
    viewController.includes('consecutiveEmergencyMemorySamples >= webRendererEmergencySampleCount'),
  'DeskGPT should recover only after sustained high memory while the app is inactive and macOS pressure is critical'
);

assert(
  !viewController.includes('content-visibility: auto') &&
    !viewController.includes('contain-intrinsic-size') &&
    !viewController.includes('deskgpt-long-chat-containment'),
  'DeskGPT should not inject containment CSS that causes long chats to redraw while scrolling'
);

assert(
  viewController.includes('updateWindowTitle(webRendererRSSMB: rssMB)') &&
    viewController.includes('DeskGPT \\(shortVersion)') &&
    viewController.includes('Web \\(rssMB)MB'),
  'DeskGPT should show the app version and current Web renderer memory in the title bar'
);

assert(
  viewController.includes('titlebarMemoryLabel') &&
    viewController.includes('NSTitlebarAccessoryViewController') &&
    viewController.includes('accessory.layoutAttribute = .left') &&
    viewController.includes('installTitlebarMemoryLabelIfNeeded()') &&
    viewController.includes('titlebarMemoryLabel?.stringValue'),
  'DeskGPT should render version and memory at the start of the titlebar'
);

assert(
  viewController.includes('checkWebRendererMemoryUsage(reasonPrefix: "initial")') &&
    viewController.includes('residentMemoryMegabytes(for: getpid())') &&
    viewController.includes('"App \\(appRSSMB)MB"'),
  'DeskGPT should show a memory value immediately at startup before the WebContent PID is available'
);

assert(
  appDelegate.includes('win.titleVisibility = .hidden') &&
    !viewController.includes('view.window?.title = title'),
  'DeskGPT should hide the standard window title so the memory accessory is the only visible title'
);

assert(
  viewController.includes('method_getImplementation') &&
    viewController.includes('unsafeBitCast') &&
    viewController.includes('_webProcessIdentifier'),
  'DeskGPT should read the WebContent PID through the private WebKit selector before measuring RSS'
);

assert(
  viewController.includes('isTerminatingWebContentForRecovery') &&
    viewController.includes('kill(pid, SIGTERM)') &&
    viewController.includes('webViewWebContentProcessDidTerminate') &&
    viewController.includes('isTerminatingWebContentForRecovery = false'),
  'DeskGPT recovery should terminate the WebContent process instead of only reloading the same renderer'
);

assert(
  buildScript.includes('git describe --tags --abbrev=0') &&
    buildScript.includes('CFBundleShortVersionString'),
  'DeskGPT local builds should display the latest release tag version instead of the source plist default'
);

assert(
  !viewController.includes('force: true') &&
    viewController.includes('recoverWebRendererIfSafe(reason: "\\(reasonPrefix)-emergency-\\(rssMB)MB", rssMB: rssMB)') &&
    viewController.includes('showToast(message: "Web 렌더러 메모리 높음: \\(rssMB)MB")'),
  'DeskGPT watchdog should never force reload while the app is active or the user has draft text'
);

assert(
  viewController.includes('func recoverWebRenderer(reason: String = "manual")') &&
    viewController.includes('webView.reload()') &&
    viewController.includes('showLoadingOverlay(message: "Web 렌더러를 복구하는 중...")'),
  'DeskGPT should centralize renderer recovery in a dedicated method'
);
