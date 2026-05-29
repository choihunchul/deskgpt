# DeskGPT Standalone macOS Application Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** macOS 환경에서 독립된 데스크톱 앱으로 ChatGPT를 실행하고, 세션을 보존하며, 항상 위에 유지 및 PDF 분할 텍스트 주입기(PDF Chunker & Injector)를 내장한 초경량 프리미엄 네이티브 macOS Cocoa 애플리케이션(`DeskGPT.app`)을 빌드합니다.

**Architecture:** Cocoa AppKit (`NSApplication`, `NSWindow`)과 WebKit (`WKWebView`) 및 PDFKit을 활용합니다. 앱은 크게 메인 대화 창과 PDF 분석 플로팅 도구 창으로 이뤄지며, 이들 간에 스마트 JavaScript 텍스트 주입 메커니즘을 연동합니다.

**Tech Stack:** Swift 5.0+, AppKit, WebKit, PDFKit, macOS Shell Utility (`sips`, `iconutil`).

---

### 📂 최종 파일 구조 (File Structure)

1. `src/main.swift`: 앱 기동 및 런타임 이벤트 루프 가동.
2. `src/AppDelegate.swift`: 애플리케이션 라이프사이클 및 시스템 네이티브 메뉴바 단축키 연동.
3. `src/DeskGPTWindowController.swift`: 메인 브라우저 창 속성 및 항상 위에 유지 기능 제어.
4. `src/DeskGPTViewController.swift`: WKWebView 세팅, 로그인 유지, 파일 업/다운로드, ChatGPT 입력창 텍스트 주입.
5. `src/DeskGPTPDFViewController.swift` **[NEW]**: PDF 로드, PDFKit 기반 고속 텍스트 추출, 텍스트 분할 알고리즘 및 주입 연동용 UI.
6. `src/Info.plist`: 앱 패키징 메타데이터.
7. `build.sh`: 고해상도 플랫 앱 아이콘 패키징 및 최종 컴파일 컴파일러 래퍼 스크립트.

---

### Task 1: DeskGPTViewController 구현 (메인 브라우저)

**Files:**
- Create: `src/DeskGPTViewController.swift`

- [ ] **Step 1: DeskGPTViewController 기본 뼈대 및 WKWebView 초기화**
  
  로그인 영속성(`WKWebsiteDataStore.default()`) 및 표준 Safari User Agent를 활용하여 ChatGPT 페이지를 연동하는 뷰 컨트롤러를 구현합니다.

  `src/DeskGPTViewController.swift`를 생성하고 다음 코드를 구현합니다:
  ```swift
  import Cocoa
  import WebKit

  class DeskGPTViewController: NSViewController, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
      var webView: WKWebView!
      
      override func loadView() {
          let webConfiguration = WKWebViewConfiguration()
          webConfiguration.websiteDataStore = WKWebsiteDataStore.default()
          webConfiguration.preferences.setValue(true, forKey: "developerExtrasEnabled")
          
          webView = WKWebView(frame: .zero, configuration: webConfiguration)
          webView.navigationDelegate = self
          webView.uiDelegate = self
          
          webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
          
          self.view = webView
      }
      
      override func viewDidLoad() {
          super.viewDidLoad()
          if let url = URL(string: "https://chatgpt.com") {
              let request = URLRequest(url: url)
              webView.load(request)
          }
      }
  }
  ```

- [ ] **Step 2: 파일 업로드 (`WKUIDelegate`) 및 다운로드 (`WKDownloadDelegate`) 추가 구현**
  
  네이티브 오픈 패널 및 세이브 패널을 연동하여 ChatGPT 내 업로드/다운로드를 매끄럽게 처리합니다.

  `src/DeskGPTViewController.swift` 내에 아래 델리게이트 연동 코드를 구현합니다:
  ```swift
  // 파일 업로드 대화상자 연동
  func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
      let openPanel = NSOpenPanel()
      openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection
      openPanel.canChooseDirectories = false
      openPanel.canChooseFiles = true
      
      openPanel.begin { response in
          if response == .OK {
              completionHandler(openPanel.urls)
          } else {
              completionHandler(nil)
          }
      }
  }

  // 파일 다운로드 제안 처리
  func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
      if let mimeType = navigationResponse.response.mimeType, mimeType.contains("octet-stream") || navigationResponse.canShowMIMEType == false {
          decisionHandler(.download)
      } else {
          decisionHandler(.allow)
      }
  }

  func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
      download.delegate = self
  }

  func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
      let savePanel = NSSavePanel()
      savePanel.suggestedFilename = suggestedFilename
      
      savePanel.begin { response in
          if response == .OK, let url = savePanel.url {
              completionHandler(url)
          } else {
              completionHandler(nil)
          }
      }
  }

  func downloadDidFinish(_ download: WKDownload) {
      NSBeep()
  }

  func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
      let alert = NSAlert()
      alert.messageText = "다운로드 실패"
      alert.informativeText = error.localizedDescription
      alert.alertStyle = .warning
      alert.addButton(withTitle: "확인")
      alert.runModal()
  }
  ```

- [ ] **Step 3: 줌 및 ChatGPT 텍스트 네이티브 주입(Smart Injection) 함수 구현**
  
  PDF 분할 조각을 ChatGPT 입력창(`textarea`)에 깔끔하게 심어주는 네이티브 주입 함수와 편의 유틸들을 작성합니다.

  `src/DeskGPTViewController.swift` 마지막 부분에 다음 코드를 구현합니다:
  ```swift
  func zoomIn() { webView.pageZoom += 0.1 }
  func zoomOut() { if webView.pageZoom > 0.5 { webView.pageZoom -= 0.1 } }
  func resetZoom() { webView.pageZoom = 1.0 }
  func reloadPage() { webView.reload() }
  func goBack() { if webView.canGoBack { webView.goBack() } }
  func goForward() { if webView.canGoForward { webView.goForward() } }

  // ChatGPT 입력창에 텍스트 주입 및 입력 이벤트 발송 JavaScript 로직
  func injectTextIntoChat(_ text: String) {
      // 특수 문자 이스케이프 처리
      let escapedText = text
          .replacingOccurrences(of: "\\", with: "\\\\")
          .replacingOccurrences(of: "\"", with: "\\\"")
          .replacingOccurrences(of: "\n", with: "\\n")
          .replacingOccurrences(of: "\r", with: "\\r")
      
      let jsScript = """
      (function() {
          var textarea = document.querySelector('#prompt-textarea') || document.querySelector('textarea');
          if (textarea) {
              textarea.focus();
              textarea.value = "\(escapedText)";
              // ChatGPT React 엔진이 글자 입력을 감지하도록 input 이벤트 강제 발송
              textarea.dispatchEvent(new Event('input', { bubbles: true }));
              return true;
          }
          return false;
      })();
      """
      
      webView.evaluateJavaScript(jsScript) { result, error in
          if let error = error {
              print("Text injection failed: \(error.localizedDescription)")
          } else if let success = result as? Bool, !success {
              // 찾지 못한 경우 클립보드 복사로 대체 안전장치 작동
              let pasteboard = NSPasteboard.general
              pasteboard.clearContents()
              pasteboard.setString(text, forType: .string)
              
              DispatchQueue.main.async {
                  let alert = NSAlert()
                  alert.messageText = "자동 주입 대기"
                  alert.informativeText = "ChatGPT 입력창을 찾지 못해 텍스트를 클립보드에 복사했습니다. 원하는 입력칸에 붙여넣기(Cmd+V) 해주세요."
                  alert.alertStyle = .informational
                  alert.addButton(withTitle: "확인")
                  alert.runModal()
              }
          }
      }
  }

  func resetSession() {
      let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
      WKWebsiteDataStore.default().removeData(ofTypes: dataTypes, modifiedSince: Date(timeIntervalSince1970: 0)) {
          DispatchQueue.main.async {
              self.reloadPage()
              let alert = NSAlert()
              alert.messageText = "세션 초기화 완료"
              alert.informativeText = "쿠키 및 로컬 캐시가 성공적으로 지워졌습니다."
              alert.alertStyle = .informational
              alert.addButton(withTitle: "확인")
              alert.runModal()
          }
      }
  }
  ```

---

### Task 2: DeskGPTPDFViewController 구현 (PDF 분할 분석 도구)

**Files:**
- Create: `src/DeskGPTPDFViewController.swift`

- [ ] **Step 1: PDF Chunker 뷰 컨트롤러 기본 UI 구조 작성**
  
  PDF 파일을 읽어 텍스트를 자동 파싱하고 조각별로 복사/주입할 수 있는 스크롤 기반 UI를 빌드합니다.

  `src/DeskGPTPDFViewController.swift`를 생성하고 다음 코드를 구현합니다:
  ```swift
  import Cocoa
  import PDFKit

  class DeskGPTPDFViewController: NSViewController, NSTextFieldDelegate {
      var chunks: [String] = []
      var chunkSize: Int = 4000
      
      let fileLabel = NSTextField(labelWithString: "선택된 PDF 파일이 없습니다.")
      let sizeField = NSTextField()
      let stackView = NSStackView()
      let scrollView = NSScrollView()
      
      weak var mainViewController: DeskGPTViewController?
      
      override func loadView() {
          let view = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 600))
          self.view = view
          
          let titleLabel = NSTextField(labelWithString: "📄 DeskGPT PDF 분할 주입기")
          titleLabel.font = NSFont.boldSystemFont(ofSize: 15)
          titleLabel.translatesAutoresizingMaskIntoConstraints = false
          view.addSubview(titleLabel)
          
          let selectButton = NSButton(title: "PDF 파일 열기 (Select PDF)", target: self, action: #selector(selectPDFFile))
          selectButton.bezelStyle = .rounded
          selectButton.translatesAutoresizingMaskIntoConstraints = false
          view.addSubview(selectButton)
          
          fileLabel.translatesAutoresizingMaskIntoConstraints = false
          fileLabel.cell?.lineBreakMode = .byTruncatingMiddle
          view.addSubview(fileLabel)
          
          let configLabel = NSTextField(labelWithString: "분할 글자수 단위:")
          configLabel.translatesAutoresizingMaskIntoConstraints = false
          view.addSubview(configLabel)
          
          sizeField.stringValue = "4000"
          sizeField.delegate = self
          sizeField.translatesAutoresizingMaskIntoConstraints = false
          view.addSubview(sizeField)
          
          scrollView.translatesAutoresizingMaskIntoConstraints = false
          scrollView.hasVerticalScroller = true
          scrollView.drawsBackground = false
          
          let clipView = NSClipView()
          clipView.drawsBackground = false
          scrollView.contentView = clipView
          
          stackView.orientation = .vertical
          stackView.alignment = .leading
          stackView.spacing = 12
          stackView.translatesAutoresizingMaskIntoConstraints = false
          scrollView.documentView = stackView
          view.addSubview(scrollView)
          
          NSLayoutConstraint.activate([
              titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
              titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
              
              selectButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
              selectButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
              
              fileLabel.centerYAnchor.constraint(equalTo: selectButton.centerYAnchor),
              fileLabel.leadingAnchor.constraint(equalTo: selectButton.trailingAnchor, constant: 12),
              fileLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
              
              configLabel.topAnchor.constraint(equalTo: selectButton.bottomAnchor, constant: 12),
              configLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
              
              sizeField.centerYAnchor.constraint(equalTo: configLabel.centerYAnchor),
              sizeField.leadingAnchor.constraint(equalTo: configLabel.trailingAnchor, constant: 8),
              sizeField.widthAnchor.constraint(equalToConstant: 80),
              
              scrollView.topAnchor.constraint(equalTo: sizeField.bottomAnchor, constant: 16),
              scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
              scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
              scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
          ])
      }
  }
  ```

- [ ] **Step 2: PDFKit 연동 고속 텍스트 추출 및 청킹 알고리즘 구현**
  
  `PDFKit` 라이브러리를 통해 파일 텍스트를 한 글자도 빠짐없이 고속으로 읽어와 논리적으로 분할하는 알고리즘을 추가합니다.

  `src/DeskGPTPDFViewController.swift`에 다음 메서드들을 구현합니다:
  ```swift
  @objc func selectPDFFile() {
      let openPanel = NSOpenPanel()
      openPanel.allowsMultipleSelection = false
      openPanel.canChooseDirectories = false
      openPanel.canChooseFiles = true
      openPanel.allowedFileTypes = ["pdf", "PDF"]
      
      openPanel.begin { [weak self] response in
          guard let self = self, response == .OK, let url = openPanel.url else { return }
          self.fileLabel.stringValue = url.lastPathComponent
          self.processPDF(at: url)
      }
  }
  
  func processPDF(at url: URL) {
      guard let document = PDFDocument(url: url) else {
          fileLabel.stringValue = "PDF 읽기 실패"
          return
      }
      
      var fullText = ""
      let pageCount = document.pageCount
      for i in 0..<pageCount {
          if let page = document.page(at: i), let pageText = page.string {
              fullText += pageText + "\n"
          }
      }
      
      // 글자수 파싱
      if let size = Int(sizeField.stringValue), size > 100 {
          chunkSize = size
      } else {
          chunkSize = 4000
          sizeField.stringValue = "4000"
      }
      
      // 텍스트 조각 내기
      chunks = chunkText(fullText, size: chunkSize)
      updateChunksUI()
  }
  
  func chunkText(_ text: String, size: Int) -> [String] {
      var result: [String] = []
      var current = text
      
      while !current.isEmpty {
          let chunkIndex = current.index(current.startIndex, offsetBy: size, limitedBy: current.endIndex) ?? current.endIndex
          let chunk = String(current[current.startIndex..<chunkIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
          if !chunk.isEmpty {
              result.append(chunk)
          }
          current = String(current[chunkIndex...])
      }
      return result
  }
  ```

- [ ] **Step 3: 조각 리스트 렌더링 및 자동 텍스트 주입 액션 연동**
  
  분할된 텍스트를 UI 카드로 변환하고, 클릭 시 메인 창의 ChatGPT 입력창에 주입하는 스택 뷰 렌더링 함수를 완성합니다.

  `src/DeskGPTPDFViewController.swift` 끝부분에 아래 구현을 채워넣습니다:
  ```swift
  func updateChunksUI() {
      // 기존 뷰 제거
      for view in stackView.arrangedSubviews {
          stackView.removeArrangedSubview(view)
          view.removeFromSuperview()
      }
      
      if chunks.isEmpty {
          let emptyLabel = NSTextField(labelWithString: "추출된 텍스트 조각이 없습니다.")
          stackView.addArrangedSubview(emptyLabel)
          return
      }
      
      for (index, chunk) in chunks.enumerated() {
          let container = NSView()
          container.wantsLayer = true
          container.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
          container.layer?.cornerRadius = 8
          container.translatesAutoresizingMaskIntoConstraints = false
          
          let label = NSTextField(labelWithString: "🧩 조각 [\(index + 1) / \(chunks.count)]  (\(chunk.count) 자)")
          label.font = NSFont.boldSystemFont(ofSize: 12)
          label.translatesAutoresizingMaskIntoConstraints = false
          container.addSubview(label)
          
          let preview = NSTextField(labelWithString: String(chunk.prefix(80)) + "...")
          preview.font = NSFont.systemFont(ofSize: 11)
          preview.textColor = .secondaryLabelColor
          preview.translatesAutoresizingMaskIntoConstraints = false
          container.addSubview(preview)
          
          let injectBtn = NSButton(title: "ChatGPT 주입", target: self, action: #selector(injectChunk(_:)))
          injectBtn.tag = index
          injectBtn.bezelStyle = .rounded
          injectBtn.translatesAutoresizingMaskIntoConstraints = false
          container.addSubview(injectBtn)
          
          let copyBtn = NSButton(title: "복사", target: self, action: #selector(copyChunk(_:)))
          copyBtn.tag = index
          copyBtn.bezelStyle = .rounded
          copyBtn.translatesAutoresizingMaskIntoConstraints = false
          container.addSubview(copyBtn)
          
          // 오토레이아웃 지정
          NSLayoutConstraint.activate([
              container.widthAnchor.constraint(equalToConstant: 400),
              container.heightAnchor.constraint(equalToConstant: 75),
              
              label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
              label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
              
              preview.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
              preview.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
              preview.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
              
              injectBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
              injectBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
              
              copyBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
              copyBtn.trailingAnchor.constraint(equalTo: injectBtn.leadingAnchor, constant: -8)
          ])
          
          stackView.addArrangedSubview(container)
      }
  }
  
  @objc func injectChunk(_ sender: NSButton) {
      let index = sender.tag
      guard index < chunks.count else { return }
      let chunkText = chunks[index]
      
      // 메인 창이 활성화되도록 활성 포커싱 처리 후 ChatGPT 입력란에 주입
      if let mainVC = mainViewController {
          mainVC.view.window?.makeKeyAndOrderFront(nil)
          NSApp.activate(ignoringOtherApps: true)
          
          let prompt = """
          [문서 분할 분석 - 조각 \(index + 1)/\(chunks.count)]
          아래 전달하는 문서 조각을 읽고 기억해 주세요. (질문은 마지막에 이뤄집니다):
          
          ---
          \(chunkText)
          """
          mainVC.injectTextIntoChat(prompt)
      }
  }
  
  @objc func copyChunk(_ sender: NSButton) {
      let index = sender.tag
      guard index < chunks.count else { return }
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.setString(chunks[index], forType: .string)
      NSBeep()
  }
  
  func controlTextDidChange(_ obj: Notification) {
      // 글자수 입력칸 제한 조절 시 반영
  }
  }
  ```

---

### Task 3: DeskGPTWindowController 및 AppDelegate 구현

**Files:**
- Create: `src/DeskGPTWindowController.swift`
- Create: `src/AppDelegate.swift`

- [ ] **Step 1: DeskGPTWindowController 구현**
  
  창 상태를 복원하고 플로팅 모드를 제공하는 메인 브라우저용 윈도우 컨트롤러를 구현합니다.

  `src/DeskGPTWindowController.swift`를 생성하고 다음 코드를 구현합니다:
  ```swift
  import Cocoa

  class DeskGPTWindowController: NSWindowController, NSWindowDelegate {
      convenience init() {
          let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
          let window = NSWindow(
              contentRect: NSRect(x: 100, y: 100, width: 1200, height: 800),
              styleMask: styleMask,
              backing: .buffered,
              defer: false
          )
          self.init(window: window)
          window.title = "DeskGPT"
          window.delegate = self
          window.setFrameAutosaveName("DeskGPTMainWindow")
      }
      
      func windowShouldClose(_ sender: NSWindow) -> Bool {
          sender.orderOut(nil)
          return false
      }
      
      func toggleAlwaysOnTop() {
          guard let window = self.window else { return }
          if window.level == .floating {
              window.level = .normal
          } else {
              window.level = .floating
          }
      }
  }
  ```

- [ ] **Step 2: AppDelegate 및 전체 메뉴와 단축키 바인딩**
  
  대화 메인 창 구동 및 `Cmd + Shift + P` 입력 시 PDF Chunker 윈도우가 사이드바 보조 창 형태로 기민하게 뜨도록 제어하는 라이프사이클을 빌드합니다.

  `src/AppDelegate.swift`를 생성하고 아래 코드를 작성합니다:
  ```swift
  import Cocoa

  class AppDelegate: NSObject, NSApplicationDelegate {
      var windowController: DeskGPTWindowController?
      var viewController: DeskGPTViewController?
      
      // PDF 분할 주입기용 보조 창 자산
      var pdfWindow: NSWindow?
      var pdfViewController: DeskGPTPDFViewController?
      
      func applicationDidFinishLaunching(_ aNotification: Notification) {
          viewController = DeskGPTViewController()
          windowController = DeskGPTWindowController()
          
          windowController?.contentViewController = viewController
          windowController?.showWindow(nil)
          
          setupMenu()
      }
      
      func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
          if !flag {
              windowController?.window?.makeKeyAndOrderFront(nil)
          }
          return true
      }
      
      // PDF Chunker 보조창 토글 함수
      @objc func togglePDFHelper() {
          if let pdfWin = pdfWindow {
              if pdfWin.isVisible {
                  pdfWin.orderOut(nil)
              } else {
                  pdfWin.makeKeyAndOrderFront(nil)
              }
              return
          }
          
          // 새로 생성
          let win = NSWindow(
              contentRect: NSRect(x: 200, y: 200, width: 450, height: 600),
              styleMask: [.titled, .closable, .resizable],
              backing: .buffered,
              defer: false
          )
          win.title = "PDF Chunker & Injector"
          
          pdfViewController = DeskGPTPDFViewController()
          pdfViewController?.mainViewController = viewController
          
          win.contentViewController = pdfViewController
          pdfWindow = win
          
          // 유틸리티 도구 성격을 살리기 위해 플로팅 스타일 지원
          win.level = .floating
          win.makeKeyAndOrderFront(nil)
      }
      
      private func setupMenu() {
          let mainMenu = NSMenu()
          
          // 1. App Menu
          let appMenu = NSMenu()
          appMenu.addItem(withTitle: "About DeskGPT", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
          appMenu.addItem(NSMenuItem.separator())
          appMenu.addItem(withTitle: "Preferences...", action: nil, keyEquivalent: ",")
          appMenu.addItem(NSMenuItem.separator())
          appMenu.addItem(withTitle: "Hide DeskGPT", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
          appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h").keyEquivalentModifierMask = [.command, .option]
          appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
          appMenu.addItem(NSMenuItem.separator())
          appMenu.addItem(withTitle: "Quit DeskGPT", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
          
          let appMenuItem = NSMenuItem()
          appMenuItem.submenu = appMenu
          mainMenu.addItem(appMenuItem)
          
          // 2. File Menu
          let fileMenu = NSMenu(title: "File")
          fileMenu.addItem(withTitle: "뒤로 가기 (Go Back)", action: #selector(goBackAction), keyEquivalent: "[")
          fileMenu.addItem(withTitle: "앞으로 가기 (Go Forward)", action: #selector(goForwardAction), keyEquivalent: "]")
          fileMenu.addItem(NSMenuItem.separator())
          fileMenu.addItem(withTitle: "새로고침 (Reload)", action: #selector(reloadAction), keyEquivalent: "r")
          fileMenu.addItem(NSMenuItem.separator())
          fileMenu.addItem(withTitle: "창 닫기 (Close Window)", action: #selector(closeWindowAction), keyEquivalent: "w")
          
          let fileMenuItem = NSMenuItem()
          fileMenuItem.submenu = fileMenu
          mainMenu.addItem(fileMenuItem)
          
          // 3. Edit Menu (네이티브 Cmd+C, Cmd+V 복사붙여넣기 핫키 매핑을 위해 필수)
          let editMenu = NSMenu(title: "Edit")
          editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
          editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
          editMenu.addItem(NSMenuItem.separator())
          editMenu.addItem(withTitle: "Cut", action: Selector(("cut:")), keyEquivalent: "x")
          editMenu.addItem(withTitle: "Copy", action: Selector(("copy:")), keyEquivalent: "c")
          editMenu.addItem(withTitle: "Paste", action: Selector(("paste:")), keyEquivalent: "v")
          editMenu.addItem(withTitle: "Select All", action: Selector(("selectAll:")), keyEquivalent: "a")
          
          let editMenuItem = NSMenuItem()
          editMenuItem.submenu = editMenu
          mainMenu.addItem(editMenuItem)
          
          // 4. View Menu (화면 비율 및 Chunker 창 토글)
          let viewMenu = NSMenu(title: "View")
          viewMenu.addItem(withTitle: "확대 (Zoom In)", action: #selector(zoomInAction), keyEquivalent: "=")
          viewMenu.addItem(withTitle: "축소 (Zoom Out)", action: #selector(zoomOutAction), keyEquivalent: "-")
          viewMenu.addItem(withTitle: "화면 배율 기본값 초기화", action: #selector(zoomResetAction), keyEquivalent: "0")
          viewMenu.addItem(NSMenuItem.separator())
          
          let topItem = viewMenu.addItem(withTitle: "항상 위에 유지 (Always on Top)", action: #selector(toggleAlwaysOnTopAction), keyEquivalent: "T")
          topItem.keyEquivalentModifierMask = [.command, .shift]
          
          viewMenu.addItem(NSMenuItem.separator())
          let pdfItem = viewMenu.addItem(withTitle: "PDF Chunker & Injector 켜기/끄기", action: #selector(togglePDFHelper), keyEquivalent: "P")
          pdfItem.keyEquivalentModifierMask = [.command, .shift]
          
          let viewMenuItem = NSMenuItem()
          viewMenuItem.submenu = viewMenu
          mainMenu.addItem(viewMenuItem)
          
          // 5. Help Menu
          let helpMenu = NSMenu(title: "Help")
          helpMenu.addItem(withTitle: "세션 초기화 및 재시작 (Reset Session & Restart)", action: #selector(resetSessionAction), keyEquivalent: "")
          
          let helpMenuItem = NSMenuItem()
          helpMenuItem.submenu = helpMenu
          mainMenu.addItem(helpMenuItem)
          
          NSApplication.shared.mainMenu = mainMenu
      }
      
      @objc func goBackAction() { viewController?.goBack() }
      @objc func goForwardAction() { viewController?.goForward() }
      @objc func reloadAction() { viewController?.reloadPage() }
      @objc func closeWindowAction() { windowController?.window?.orderOut(nil) }
      @objc func zoomInAction() { viewController?.zoomIn() }
      @objc func zoomOutAction() { viewController?.zoomOut() }
      @objc func zoomResetAction() { viewController?.resetZoom() }
      @objc func toggleAlwaysOnTopAction() { windowController?.toggleAlwaysOnTop() }
      @objc func resetSessionAction() { viewController?.resetSession() }
  }
  ```

---

### Task 4: Entry Point (main.swift) 구현

**Files:**
- Create: `src/main.swift`

- [ ] **Step 1: main.swift 작성**
  
  애플리케이션이 시작될 때 구동되는 초경량 루프 진입 코드를 작성합니다.

  `src/main.swift`에 아래 코드를 적어넣습니다:
  ```swift
  import Cocoa

  let app = NSApplication.shared
  let delegate = AppDelegate()
  app.delegate = delegate

  _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
  ```

---

### Task 5: 빌드 패키징 설정 및 빌드 자동화 파일 작성

**Files:**
- Create: `src/Info.plist`
- Create: `build.sh`

- [ ] **Step 1: Info.plist 작성**
  
  앱 번들의 정량 설정값을 세팅합니다.

  `src/Info.plist`를 생성하고 다음 XML을 작성합니다:
  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
      <key>CFBundleDevelopmentRegion</key>
      <string>ko_KR</string>
      <key>CFBundleExecutable</key>
      <string>DeskGPT</string>
      <key>CFBundleIconFile</key>
      <string>AppIcon</string>
      <key>CFBundleIdentifier</key>
      <string>com.myside.DeskGPT</string>
      <key>CFBundleInfoDictionaryVersion</key>
      <string>6.0</string>
      <key>CFBundleName</key>
      <string>DeskGPT</string>
      <key>CFBundlePackageType</key>
      <string>APPL</string>
      <key>CFBundleShortVersionString</key>
      <string>1.0</string>
      <key>CFBundleVersion</key>
      <string>1</string>
      <key>LSMinimumSystemVersion</key>
      <string>11.0</string>
      <key>NSHighResolutionCapable</key>
      <true/>
  </dict>
  </plist>
  ```

- [ ] **Step 2: build.sh 작성**
  
  이전에 생성한 고해상도 **플랫 앱 아이콘** PNG 리소스를 macOS 시스템 규격에 맞춰 여러 사이즈로 sips 리사이징 후 `AppIcon.icns`로 패키징하고, 모든 Swift 소스코드를 한 번에 안전히 컴파일하여 완전한 `DeskGPT.app` 번들로 묶어주는 빌드 셸 스크립트를 작성합니다.

  `build.sh`를 작성하고 다음 코드를 기입합니다:
  ```bash
  #!/bin/bash
  set -e

  # 이전 빌드 정리
  rm -rf build
  mkdir -p build/DeskGPT.app/Contents/MacOS
  mkdir -p build/DeskGPT.app/Contents/Resources

  # 1. 플랫 고해상도 앱 아이콘 ICNS 자동 빌드
  echo "🎨 플랫 앱 아이콘 생성 중..."
  ICON_SRC="/Users/hunchulchoi/.gemini/antigravity/brain/46601610-fd48-492e-bdeb-86cf24510bea/deskgpt_flat_icon_1780031119679.png"
  ICONSET_DIR="build/AppIcon.iconset"
  mkdir -p "$ICONSET_DIR"

  sips -z 16 16     "$ICON_SRC" --out "$ICONSET_DIR/icon_16x16.png"
  sips -z 32 32     "$ICON_SRC" --out "$ICONSET_DIR/icon_16x16@2x.png"
  sips -z 32 32     "$ICON_SRC" --out "$ICONSET_DIR/icon_32x32.png"
  sips -z 64 64     "$ICON_SRC" --out "$ICONSET_DIR/icon_32x32@2x.png"
  sips -z 128 128   "$ICON_SRC" --out "$ICONSET_DIR/icon_128x128.png"
  sips -z 256 256   "$ICON_SRC" --out "$ICONSET_DIR/icon_128x128@2x.png"
  sips -z 256 256   "$ICON_SRC" --out "$ICONSET_DIR/icon_256x256.png"
  sips -z 512 512   "$ICON_SRC" --out "$ICONSET_DIR/icon_256x256@2x.png"
  sips -z 512 512   "$ICON_SRC" --out "$ICONSET_DIR/icon_512x512.png"
  sips -z 1024 1024 "$ICON_SRC" --out "$ICONSET_DIR/icon_512x512@2x.png"

  iconutil -c icns "$ICONSET_DIR" -o build/DeskGPT.app/Contents/Resources/AppIcon.icns
  rm -rf "$ICONSET_DIR"

  # 2. 설정 파일 복사
  cp src/Info.plist build/DeskGPT.app/Contents/Info.plist

  # 3. Swift 컴파일 및 패키징
  echo "🚀 Swift 파일 고속 컴파일 및 패키징..."
  swiftc src/DeskGPTViewController.swift \
         src/DeskGPTPDFViewController.swift \
         src/DeskGPTWindowController.swift \
         src/AppDelegate.swift \
         src/main.swift \
         -o build/DeskGPT.app/Contents/MacOS/DeskGPT \
         -framework Cocoa -framework WebKit -framework PDFKit

  echo "🎉 DeskGPT.app 빌드 성공! 경로: build/DeskGPT.app"
  ```

---

### Task 6: 빌드 가동 및 최종 기능 종합 검증

- [ ] **Step 1: 빌드 및 패키징 실행**
  
  작성한 스크립트를 수행해 완전한 패키지를 형성합니다.

  Run: `chmod +x build.sh && ./build.sh`
  Expected: 오류 메시지 없이 `🎉 DeskGPT.app 빌드 성공!` 출력 및 `build/DeskGPT.app` 디렉토리 정상 생성 완료.

- [ ] **Step 2: 앱 실행 및 복합 고급 기능 교차 검증**
  
  빌드된 독립 앱을 실행하여 로그인 유지, 다운로드/업로드, 그리고 PDF Chunker 기능의 완벽한 텍스트 파싱 및 실시간 주입이 이뤄지는지 교차 확인합니다.
  
  Run: `open build/DeskGPT.app`
  Expected:
  1. 메인 DeskGPT 창이 띄워지고 ChatGPT 사이트 로그인 상태가 정상 보존됨.
  2. `Cmd + Shift + P` 단축키 입력 시 PDF Chunker 보조 유틸리티 창이 켜짐.
  3. PDF 파일을 선택(Select PDF)하면 페이지 텍스트가 조각별(예: 4000자씩)로 순식간에 청킹되어 UI 카드로 표시됨.
  4. 'ChatGPT 주입' 버튼을 눌렀을 때, 메인 창 입력창에 텍스트가 쏙 들어가며 포커싱 처리됨.
  5. `Cmd + Shift + T`로 창을 언제든 최상단에 띄우기 작동 확인.
