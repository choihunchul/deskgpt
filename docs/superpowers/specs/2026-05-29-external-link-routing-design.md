# DeskGPT External Link Routing Spec

이 설계 문서는 사용자가 DeskGPT 내에서 ChatGPT를 사용하던 중 답변 내의 참조 링크 또는 외부 문서 링크를 클릭했을 때, 해당 페이지가 앱 내부 창에서 열려 대화 세션이 끊기는 현상을 방지하고 **자동으로 macOS 기본 웹 브라우저(Safari, Chrome 등)를 통해 띄우도록** 설계된 상세 사양서입니다.

---

## 1. 해결하고자 하는 문제 (Problem Statement)
현재 DeskGPT는 `createWebViewWith` 대리자 함수를 통해 `target="_blank"` 속성을 가진 새 창 이동 링크만 외부 브라우저로 분기하고 있습니다.
그러나 `_self` 또는 target 속성이 지정되지 않은 일반 `<a>` 태그의 경우, WKWebView 내부 프레임이 이를 자체적으로 탐색해 버립니다. 이로 인해 DeskGPT 앱 안에 외부 포털이나 블로그가 떠서 ChatGPT 세션이 초기화되는 심각한 UX 파편화가 초래됩니다.

---

## 2. 해결 방안 (Proposed Approach)

WKWebView의 메인 탐색 검증 핸들러인 `decidePolicyFor navigationAction`을 보완합니다.

### 2.1. 허용할 도메인 화이트리스트 (Allowed Domains)
ChatGPT 정상 구동 및 로그인 연동 등에 필요한 최소한의 도메인만 내부 브라우징을 허용합니다:
1. `chatgpt.com` (메인 챗 인터페이스)
2. `openai.com` (API 및 개발사)
3. `oaiusercontent.com` (ChatGPT 정적 리소스 및 이미지 CDN)
4. `auth0.com` / `appleid.apple.com` / `accounts.google.com` (소셜 및 싱글사인온 로그인 보안 게이트웨이)
5. `sentry.io` (에러 리포팅 도구)

### 2.2. 외부 도메인 차단 및 외부 실행 (Cancel & Open in Default Browser)
화이트리스트에 부합하지 않는 모든 아웃바운드 링크는 웹뷰 탐색을 즉시 취소(`.cancel`)하고, AppKit의 `NSWorkspace.shared.open(url)`을 호출하여 macOS 기본 웹 브라우저로 튕겨서 열어줍니다.

---

## 3. 상세 설계 및 구현 코드

### 3.1. Swift 네이티브 단 (`DeskGPTViewController.swift`)

`decidePolicyFor navigationAction` 내의 탐색 인터셉터 로직을 개편합니다.

```swift
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if #available(macOS 11.3, *) {
            if navigationAction.shouldPerformDownload {
                decisionHandler(.download)
                return
            }
        }
        
        // Intercept and route outbound external links
        if let url = navigationAction.request.url {
            let host = url.host?.lowercased() ?? ""
            
            // Define strict whitelist of essential domains to remain inside the app
            let allowedHosts = ["chatgpt.com", "openai.com", "oaiusercontent.com", "auth0.com", "appleid.apple.com", "accounts.google.com", "sentry.io"]
            
            // Allow if host is empty (local resources, blank targets) or falls into the allowed list
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

---

## 4. 검증 계획 (Verification Plan)
1. **내부 로그인 및 이동 테스트**: 구글/애플 로그인 게이트 및 ChatGPT 내부 챗 페이지 이동이 부드럽고 끊김 없이 허용되는지 검증.
2. **참조 링크 아웃바운드 테스트**: 대화 중 ChatGPT가 출처로 제시한 외부 사이트(예: 위키백과, 뉴스 포털 등)를 일반 클릭했을 때, DeskGPT 창 내부는 아무 변화가 없고 **macOS 기본 브라우저(Safari)가 실행되며 해당 사이트가 온전히 열리는지** 검증.
