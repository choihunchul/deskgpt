import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow?
    var viewController: DeskGPTViewController?
    
    var pdfWindow: NSWindow?
    var pdfViewController: DeskGPTPDFViewController?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("🚀 AppDelegate: applicationDidFinishLaunching starting...")
        
        viewController = DeskGPTViewController()
        print("🚀 AppDelegate: DeskGPTViewController instantiated...")
        
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        let win = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1200, height: 800),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        win.title = "DeskGPT"
        win.contentViewController = viewController
        win.delegate = self
        
        // Center the window on the main screen to prevent any off-screen positioning bugs
        win.center()
        
        // Auto-saves window frame dimensions and position using a new cache key (v3) to bypass any corrupted coordinates
        win.setFrameAutosaveName("DeskGPTMainWindow_v3")
        
        self.window = win
        
        // Make the window visible and key
        win.makeKeyAndOrderFront(nil)
        
        // Bring the window and application strictly to the foreground
        NSApp.activate(ignoringOtherApps: true)
        print("🚀 AppDelegate: Direct NSWindow created, ordered front, and app activated...")
        
        setupMenu()
        print("🚀 AppDelegate: setupMenu finished...")
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            window?.makeKeyAndOrderFront(nil)
        }
        return true
    }
    
    // MARK: - NSWindowDelegate: Hide window instead of destroying to keep session active
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender == self.window {
            sender.orderOut(nil)
            return false
        }
        return true
    }
    
    @objc func togglePDFHelper() {
        if let pdfWin = pdfWindow {
            if pdfWin.isVisible {
                pdfWin.orderOut(nil)
            } else {
                pdfWin.makeKeyAndOrderFront(nil)
            }
            return
        }
        
        // Lazy-instantiate the floating utility PDF Chunker window
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
        
        // Keeps the utility tool floated on top of the chat view
        win.level = .floating
        win.makeKeyAndOrderFront(nil)
    }
    
    private func setupMenu() {
        let mainMenu = NSMenu()
        
        // 1. DeskGPT App Menu
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
        
        // 3. Edit Menu (Crucial for Cmd+C / Cmd+V / Cmd+A functionality within text fields)
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
        
        // 4. View Menu (Zooming, Always on Top, PDF Chunker toggles)
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "확대 (Zoom In)", action: #selector(zoomInAction), keyEquivalent: "=")
        viewMenu.addItem(withTitle: "축소 (Zoom Out)", action: #selector(zoomOutAction), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "화면 배율 기본값 초기화", action: #selector(zoomResetAction), keyEquivalent: "0")
        viewMenu.addItem(NSMenuItem.separator())
        
        let topItem = viewMenu.addItem(withTitle: "항상 위에 유지 (Always on Top)", action: #selector(toggleAlwaysOnTopAction), keyEquivalent: "T")
        topItem.keyEquivalentModifierMask = [.command, .shift]
        
        viewMenu.addItem(NSMenuItem.separator())
        let pdfItem = viewMenu.addItem(withTitle: "PDF Chunker & Injector 켜기/끄기", action: #selector(togglePDFHelper), keyEquivalent: "p")
        pdfItem.keyEquivalentModifierMask = [.command, .shift]
        
        let viewMenuItem = NSMenuItem()
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)
        
        // 5. Help / Diagnostic Menu
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(withTitle: "세션 초기화 및 재시작 (Reset Session & Restart)", action: #selector(resetSessionAction), keyEquivalent: "")
        
        let helpMenuItem = NSMenuItem()
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)
        
        NSApplication.shared.mainMenu = mainMenu
    }
    
    // MARK: - Action Delegates forwarding events to controllers
    @objc func goBackAction() { viewController?.goBack() }
    @objc func goForwardAction() { viewController?.goForward() }
    @objc func reloadAction() { viewController?.reloadPage() }
    @objc func closeWindowAction() { window?.orderOut(nil) }
    @objc func zoomInAction() { viewController?.zoomIn() }
    @objc func zoomOutAction() { viewController?.zoomOut() }
    @objc func zoomResetAction() { viewController?.resetZoom() }
    
    @objc func toggleAlwaysOnTopAction() {
        guard let win = self.window else { return }
        if win.level == .floating {
            win.level = .normal
            print("🚀 AppDelegate: Always-on-top OFF")
        } else {
            win.level = .floating
            print("🚀 AppDelegate: Always-on-top ON")
        }
    }
    
    @objc func resetSessionAction() { viewController?.resetSession() }
}
