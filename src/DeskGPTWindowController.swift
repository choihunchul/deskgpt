import Cocoa

class DeskGPTWindowController: NSWindowController, NSWindowDelegate {
    convenience init() {
        print("🚀 DeskGPTWindowController: convenience init starting...")
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
        
        // Auto-saves window frame dimensions and screen position coordinates to User Defaults
        window.setFrameAutosaveName("DeskGPTMainWindow")
        print("🚀 DeskGPTWindowController: convenience init finished...")
    }
    
    // Hide window instead of destroying/terminating window to keep browser WKWebView session active
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
