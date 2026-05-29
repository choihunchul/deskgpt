# WKDownloadDelegate Hijacker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overwrite the WKDownloadDelegate `decideDestinationUsing` callback to capture WebKit's native "이미지 다운로드" actions, bypass save dialogs, sync session cookies, and save directly to `~/Downloads`.

**Architecture:** Hijack `download(_:decideDestinationUsing:suggestedFilename:completionHandler:)` inside `DeskGPTViewController.swift` and abort default WKDownload session cleanly using `completionHandler(nil)`.

**Tech Stack:** Swift, AppKit, WebKit (WKDownloadDelegate, WKDownload)

---

### Task 1: Overwrite WKDownloadDelegate Destination Logic

**Files:**
- Modify: [DeskGPTViewController.swift](file:///Users/hunchulchoi/projects/workspace/myside/gpt_exe/src/DeskGPTViewController.swift)

- [ ] **Step 1: Rewrite download(_:decideDestinationUsing:...) inside DeskGPTViewController.swift**

Locate `download(_:decideDestinationUsing:suggestedFilename:completionHandler:)` (around lines 100-115) and rewrite the delegate method to hijack destination logic.

```swift
    // MARK: - WKDownloadDelegate
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        // Hijack the WKDownload lifecycle to bypass system NSSavePanel dialogs and cookies issues!
        if let url = response.url {
            let filename = suggestedFilename.isEmpty ? "image.png" : suggestedFilename
            let destinationUrl = self.getUniqueDownloadsURL(suggestedName: filename)
            
            print("🚀 WKDownload Interceptor: Routing native download safely for \(url.absoluteString)")
            
            // Route to our secure cookie-synced Swift URLSession downloader
            self.downloadImage(from: url, to: destinationUrl)
        }
        
        // Pass nil to the completionHandler to instantly cancel the system Save Panel / native thread
        completionHandler(nil)
    }
```

- [ ] **Step 2: Clean up compile error warnings on duplicate delegates**

Ensure the `download(_:didFailWithError:resumeData:)` delegate method handles failures gracefully without crashing.

```swift
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        // Log error safely but bypass generic UI alert to avoid interrupting custom downloads
        print("ℹ️ WKDownload thread naturally terminated or bypassed: \(error.localizedDescription)")
    }
```

- [ ] **Step 3: Compile and Deploy**

Run compile & applications folder deployment:
`./build.sh && rm -rf /Applications/DeskGPT.app && cp -R build/DeskGPT.app /Applications/DeskGPT.app`
Expected: Succeeds cleanly.

- [ ] **Step 4: Commit and Push**

```bash
git add src/DeskGPTViewController.swift docs/superpowers/plans/2026-05-29-wkdownload-delegate-hijacker.md
git commit -m "feat: hijack WKDownloadDelegate decideDestinationUsing to bypass system Save Panel and download directly to Downloads"
git push origin main
```
