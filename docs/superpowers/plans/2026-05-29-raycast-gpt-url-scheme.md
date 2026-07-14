# Raycast GPT URL Scheme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let Raycast open DeskGPT with a `/gpt`-style command that sends a prompt directly into ChatGPT and submits it automatically.

**Architecture:** DeskGPT will register a custom URL scheme (`deskGPT://`). `AppDelegate` will receive incoming URLs, parse `deskGPT://ask?text=...`, and forward the decoded prompt to `DeskGPTViewController`. The view controller will inject the prompt into the ChatGPT composer, dispatch an input event so React notices the change, and trigger send either by clicking the send button or pressing Enter.

**Tech Stack:** Swift, Cocoa, WebKit, macOS URL handling, JavaScript injection inside `WKWebView`

---

### Task 1: Register and receive DeskGPT URLs

**Files:**
- Modify: `/Users/hunchulchoi/projects/workspace/myside/gpt_exe/src/Info.plist`
- Modify: `/Users/hunchulchoi/projects/workspace/myside/gpt_exe/src/AppDelegate.swift`

- [ ] **Step 1: Add a URL scheme to the app bundle**

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.myside.DeskGPT</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>deskGPT</string>
        </array>
    </dict>
</array>
```

- [ ] **Step 2: Handle incoming URLs in AppDelegate**

```swift
func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
        viewController?.handleIncomingURL(url)
    }
}
```

- [ ] **Step 3: Verify the app still compiles**

Run: `./build.sh`
Expected: `DeskGPT.app 빌드 및 설치 성공` and the app is copied to `/Applications/DeskGPT.app`

### Task 2: Inject and submit prompts in the ChatGPT composer

**Files:**
- Modify: `/Users/hunchulchoi/projects/workspace/myside/gpt_exe/src/DeskGPTViewController.swift`

- [ ] **Step 1: Add a public entry point for external prompts**

```swift
func handleIncomingURL(_ url: URL) {
    guard url.scheme?.lowercased() == "deskgpt" else { return }
    guard url.host?.lowercased() == "ask" else { return }

    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let prompt = components?.queryItems?.first(where: { $0.name == "text" })?.value ?? ""
    guard !prompt.isEmpty else { return }

    DispatchQueue.main.async { [weak self] in
        self?.sendPromptToChatGPT(prompt)
    }
}
```

- [ ] **Step 2: Add JS that fills the composer and submits it**

```swift
func sendPromptToChatGPT(_ prompt: String) {
    let escaped = prompt
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "'", with: "\\'")
        .replacingOccurrences(of: "\n", with: "\\n")

    let js = """
    (function() {
        const selectors = [
            'textarea[placeholder*="Ask anything"]',
            'textarea',
            '[contenteditable="true"]'
        ];

        let input = null;
        for (const selector of selectors) {
            input = document.querySelector(selector);
            if (input) break;
        }
        if (!input) return "no-input";

        const value = '\(escaped)';
        if (input.tagName === 'TEXTAREA') {
            input.value = value;
            input.dispatchEvent(new Event('input', { bubbles: true }));
        } else {
            input.focus();
            document.execCommand('insertText', false, value);
            input.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: value }));
        }

        const sendButton = document.querySelector('button[aria-label*="Send"], button[data-testid*="send"]');
        if (sendButton) {
            sendButton.click();
            return "sent-click";
        }

        input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', bubbles: true }));
        input.dispatchEvent(new KeyboardEvent('keyup', { key: 'Enter', code: 'Enter', bubbles: true }));
        return "sent-enter";
    })();
    """
    webView.evaluateJavaScript(js, completionHandler: nil)
}
```

- [ ] **Step 3: Verify the flow with a local URL open**

Run: `open "deskGPT://ask?text=Hello%20from%20Raycast"`
Expected: DeskGPT opens, the prompt appears in ChatGPT, and the message is sent automatically.

