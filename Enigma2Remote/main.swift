import Cocoa

// Create and run the application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Start the main run loop
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv) 