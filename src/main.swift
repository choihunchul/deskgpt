import Cocoa

// Turn off standard output buffering so prints appear immediately in logs
setbuf(stdout, nil)

print("🚀 DeskGPT main: Starting app...")

let app = NSApplication.shared
app.setActivationPolicy(.regular)

print("🚀 DeskGPT main: Creating AppDelegate...")
let delegate = AppDelegate()
app.delegate = delegate

print("🚀 DeskGPT main: Entering app.run() loop...")
withExtendedLifetime(delegate) {
    app.run()
}
print("🚀 DeskGPT main: Exited app.run()")
