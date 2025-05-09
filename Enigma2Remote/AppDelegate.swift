import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("Application did finish launching")
        
        // Create a window
        let windowSize = NSSize(width: 280, height: 800) 
        let screenSize = NSScreen.main?.visibleFrame.size ?? NSSize(width: 800, height: 600)
        let rect = NSMakeRect(
            (screenSize.width - windowSize.width) / 2,
            (screenSize.height - windowSize.height) / 2,
            windowSize.width,
            windowSize.height
        )
        
        print("Creating window with size: \(windowSize)")
        
        window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // Set window properties
        window.title = "EnigMate"
        window.minSize = NSSize(width: 280, height: 800) 
        window.isReleasedWhenClosed = false 
        window.backgroundColor = .windowBackgroundColor
        
        // Create and set the view controller
        let viewController = RemoteViewController()
        window.contentViewController = viewController
        
        // Ensure the window is properly sized
        window.setFrame(rect, display: true)
        
        // Show the window
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless() 
        
        // Force window to be visible
        NSApp.activate(ignoringOtherApps: true)
        
        print("Window created and shown with frame: \(window.frame)")
        
        // Add custom Help menu item
        setupHelpMenu()
    }
    
    func setupHelpMenu() {
        guard let mainMenu = NSApp.mainMenu else {
            print("Error: Could not find main menu.")
            return
        }
        
        var helpMenu = mainMenu.item(withTitle: "Help")?.submenu
        
        if helpMenu == nil {
            print("Help menu not found, creating one.")
            let newHelpMenu = NSMenu(title: "Help")
            let helpMenuItem = NSMenuItem(title: "Help", action: nil, keyEquivalent: "")
            helpMenuItem.submenu = newHelpMenu
            mainMenu.addItem(helpMenuItem)
            helpMenu = newHelpMenu
        }
        
        guard let existingHelpMenu = helpMenu else {
             print("Error: Failed to find or create Help menu.")
             return
        }

        // Remove previous custom item if it exists
        if let oldItem = existingHelpMenu.item(withTitle: "Enigma2 Channel List (GitHub)") {
            existingHelpMenu.removeItem(oldItem)
        }
         // Remove potential separator added before
        if let lastItem = existingHelpMenu.items.last, lastItem.isSeparatorItem {
             existingHelpMenu.removeItem(lastItem)
        }


        // Check if our custom "About" item already exists
        if existingHelpMenu.item(withTitle: "About EnigMate") == nil {
            // Add a separator before our custom item
            existingHelpMenu.insertItem(NSMenuItem.separator(), at: 0) // Insert separator at the top of help menu items
            
            // Add the custom "About" menu item
            let aboutMenuItem = NSMenuItem(
                title: "About EnigMate",
                action: #selector(showCustomAboutPanel), // Point to the new action
                keyEquivalent: ""
            )
            aboutMenuItem.target = self // Action is in AppDelegate
            existingHelpMenu.insertItem(aboutMenuItem, at: 1) // Insert after the separator
            print("Added custom About item to Help menu.")
        } else {
             print("Custom About item already exists in Help menu.")
        }
    }

    // Action to show the custom About panel (NSAlert)
    @objc func showCustomAboutPanel() {
        let alert = NSAlert()
        alert.messageText = "EnigMate"
        // Combine name and link in the informative text
        alert.informativeText = "Developed by Adrian Mihalko.\n\nChannel List Info:\nhttp://github.com/adrianmihalko/enigma2hunskchannellist/blob/main/rytec.channels.xml"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        
        // Make the alert appear frontmost
        alert.runModal() 
    }

    // Removed openGitHubLink as it's now part of the About panel

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // Keep the app running even when all windows are closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
