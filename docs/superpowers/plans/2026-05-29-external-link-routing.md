# External Link Routing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Secure DeskGPT outbound links by routing any non-essential domains to open in macOS Safari, protecting session state.

**Architecture:** Update `decidePolicyFor navigationAction` in `DeskGPTViewController.swift` to match hosts against a dynamic domain whitelist.

**Tech Stack:** Swift, AppKit, WebKit (WKWebView)

---

### Task 1: Secure Outbound Web Links

**Files:**
- Modify: [DeskGPTViewController.swift](file:///Users/hunchulchoi/projects/workspace/myside/gpt_exe/src/DeskGPTViewController.swift)

- [ ] **Step 1: Rewrite decidePolicyFor navigationAction with strict host filtering**

Locate `decidePolicyFor navigationAction` (around lines 65-74) and modify it as follows:

```swift
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if #available(macOS 11.3, *) {
            if navigationAction.shouldPerformDownload {
                decisionHandler(.download)
                return
            }
        }
        
        // Intercept and route outbound external links safely to default macOS Safari
        if let url = navigationAction.request.url {
            let host = url.host?.lowercased() ?? ""
            
            // Whitelist of domains allowed to remain inside DeskGPT
            let allowedHosts = [
                "chatgpt.com", 
                "openai.com", 
                "oaiusercontent.com", 
                "auth0.com", 
                "appleid.apple.com", 
                "accounts.google.com", 
                "sentry.io"
            ]
            
            // Allow hosts that match exactly or are subdomains of whitelisted domains
            let isAllowed = host.isEmpty || allowedHosts.contains { allowed in
                host == allowed || host.hasSuffix("." + allowed)
            }
            
            if !isAllowed {
                print("🌐 Outbound link routed to Safari: \(url.absoluteString)")
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
        }
        
        decisionHandler(.allow)
    }
```

- [ ] **Step 2: Run Compile Verification**

Run build script to ensure compile passes cleanly:
`./build.sh`
Expected: Succeeds without errors.

- [ ] **Step 3: Deploy and Test**

Deploy to `/Applications`:
`rm -rf /Applications/DeskGPT.app && cp -R build/DeskGPT.app /Applications/DeskGPT.app`
Expected: Succeeds without errors.

- [ ] **Step 4: Commit and Push**

```bash
git add src/DeskGPTViewController.swift docs/superpowers/specs/2026-05-29-external-link-routing-design.md docs/superpowers/plans/2026-05-29-external-link-routing.md
git commit -m "feat: secure outbound web links to route safely to default default macOS Safari browser"
git push origin main
```
