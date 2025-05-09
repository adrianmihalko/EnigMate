import Cocoa
import SwiftUI
import Combine // Needed for ObservableObject in RequestLogger

// MARK: - Debug Logging Infrastructure

struct DebugLogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let url: URL
    var response: String? // Store response data or error message
    var statusCode: Int?
}

class RequestLogger: ObservableObject {
    static let shared = RequestLogger()
    @Published var logEntries: [DebugLogEntry] = []
    @Published var filterCommonRequests: Bool {
        didSet {
            UserDefaults.standard.set(filterCommonRequests, forKey: "debugFilterCommonRequests")
            print("Filter common requests set to: \(filterCommonRequests)")
        }
    }
    private let maxLogEntries = 100 

    private init() {
        self.filterCommonRequests = UserDefaults.standard.object(forKey: "debugFilterCommonRequests") as? Bool ?? true
        print("Initialized RequestLogger with filterCommonRequests = \(self.filterCommonRequests)")
    }

    func logRequest(url: URL) {
        let entry = DebugLogEntry(timestamp: Date(), url: url)
        DispatchQueue.main.async {
            self.logEntries.append(entry)
            if self.logEntries.count > self.maxLogEntries {
                self.logEntries.removeFirst()
            }
            print("Logged request: \(url)")
        }
    }

    func logResponse(for url: URL, statusCode: Int?, data: Data?, error: Error?) {
        DispatchQueue.main.async {
            guard let index = self.logEntries.lastIndex(where: { $0.url == url && $0.response == nil }) else {
                print("Could not find matching request log entry for response: \(url)")
                var responseString = "No matching request found."
                if let error = error {
                    responseString += " Error: \(error.localizedDescription)"
                } else if let data = data, let string = String(data: data, encoding: .utf8) {
                     responseString += " Status: \(statusCode ?? -1). Response: \(string.prefix(200))..." 
                } else if let statusCode = statusCode {
                     responseString += " Status: \(statusCode). No data."
                }
                let entry = DebugLogEntry(timestamp: Date(), url: url, response: responseString, statusCode: statusCode)
                self.logEntries.append(entry)
                if self.logEntries.count > self.maxLogEntries {
                    self.logEntries.removeFirst()
                }
                return
            }

            var responseString: String
            if let error = error {
                responseString = "Error: \(error.localizedDescription)"
            } else if let data = data, let string = String(data: data, encoding: .utf8) {
                 responseString = "Response: \(string.prefix(500))" 
                 if string.count > 500 { responseString += "..." }
            } else {
                responseString = "No data received"
            }
            
            self.logEntries[index].response = responseString
            self.logEntries[index].statusCode = statusCode
            print("Logged response for: \(url) -> Status: \(statusCode ?? -1)")
        }
    }
    
    func clearLogs() {
        DispatchQueue.main.async {
            self.logEntries.removeAll()
            print("Debug logs cleared.")
        }
    }
}

// MARK: - Debug Window Controller (Styled like Preview)
class DebugWindowController: NSWindowController { 
    static let shared = DebugWindowController()
    private var requestLogger = RequestLogger.shared 
    var isWindowVisible: Bool { return window?.isVisible ?? false } 

    override init(window: NSWindow?) {
        let contentRect = NSRect(x: 0, y: 0, width: 450, height: 450) 
        let styleMask: NSWindow.StyleMask = [.titled, .closable] 
        let window = NSWindow(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false) 
        window.title = "Debug Log"
        window.isReleasedWhenClosed = false 
        
        window.minSize = NSSize(width: 450, height: 450)
        window.maxSize = NSSize(width: 450, height: 450)
        window.isRestorable = false
        window.collectionBehavior = .moveToActiveSpace
        window.hasShadow = true
        window.backgroundColor = NSColor.windowBackgroundColor 
        window.isOpaque = false
        window.acceptsMouseMovedEvents = true 

        super.init(window: window)
        
        self.window!.delegate = WindowCloseDelegate.shared 

        let debugView = DebugLogView(logger: requestLogger)
        let hostingView = NSHostingView(rootView: debugView)
        hostingView.frame = contentRect 
        window.contentView = hostingView
        
         window.setFrame(NSRect(x: window.frame.origin.x, 
                               y: window.frame.origin.y, 
                               width: contentRect.width, 
                               height: contentRect.height + (window.frame.height - window.contentRect(forFrameRect: window.frame).height)), 
                        display: true)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        _ = self.window 
        
        let debugView = DebugLogView(logger: requestLogger)
        let hostingView = NSHostingView(rootView: debugView)
        hostingView.frame = self.window?.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 450, height: 450) 
        self.window?.contentView = hostingView
        
        positionWindowToLeftOfMainWindow()
        
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        setupWindowAttachment()
    }
    
    func closeWindow() {
        print("Closing debug window")
        if let window = self.window, let parent = window.parent {
            parent.removeChildWindow(window)
        }
        window?.close()
    }

    func positionWindowToLeftOfMainWindow() {
        guard let mainWindow = NSApplication.shared.windows.first(where: { $0.title == "Enigma2 Remote" }),
              let popupWindow = self.window else {
            print("DebugWindow: Could not find main window or popup window for positioning.")
            return
        }
        
        let mainFrame = mainWindow.frame
        let popupFrame = popupWindow.frame
        let gap: CGFloat = 5 
        
        let newX = mainFrame.minX - popupFrame.width - gap
        let newY = mainFrame.maxY - popupFrame.height
        
        if let screen = mainWindow.screen {
            let screenFrame = screen.visibleFrame
            let adjustedX = max(newX, screenFrame.minX) 
            popupWindow.setFrameOrigin(NSPoint(x: adjustedX, y: newY))
        } else {
            popupWindow.setFrameOrigin(NSPoint(x: newX, y: newY))
        }
        print("Positioned Debug window to left at: \(popupWindow.frame.origin)")
    }

    private func setupWindowAttachment() {
        guard let debugWindow = self.window,
              let mainWindow = NSApplication.shared.windows.first(where: { $0.title == "Enigma2 Remote" }) else {
             print("DebugWindow: Could not find main window or debug window for attachment.")
            return
        }
        
        if debugWindow.parent == nil {
            mainWindow.addChildWindow(debugWindow, ordered: .above)
            print("Attached Debug window to Main window")
        }
    }
}

// MARK: - Debug Log View (SwiftUI)
struct DebugLogView: View {
    @ObservedObject var logger: RequestLogger

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Network Request Log")
                    .font(.headline)
                Spacer()
                Toggle("Hide Common", isOn: $logger.filterCommonRequests)
                    .font(.caption)
                    .toggleStyle(SwitchToggleStyle(tint: .secondary)) 
                    .padding(.trailing, 10)
                Button("Clear Logs") {
                    logger.clearLogs()
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor)) 

            Divider()

            List {
                let filteredEntries = logger.logEntries.filter { entry in
                    if !logger.filterCommonRequests { return true }
                    let path = entry.url.path
                    return !path.contains("/web/about") && !path.contains("/grab")
                }
                ForEach(filteredEntries.reversed()) { entry in 
                    VStack(alignment: .leading) {
                        HStack {
                            Text(entry.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(entry.url.absoluteString)
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            if let statusCode = entry.statusCode {
                                Text("Status: \(statusCode)")
                                    .font(.caption)
                                    .foregroundColor(statusCode == 200 ? .green : .orange)
                            }
                        }
                        if let response = entry.response {
                            Text(response)
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                                .padding(.top, 2)
                                .lineLimit(5) 
                        } else {
                            Text("Pending...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(PlainListStyle()) 
            .id(logger.logEntries.count) 
        }
        .frame(minWidth: 450, minHeight: 300) 
    }
}


// MARK: - Connection Manager
class ConnectionManager: ObservableObject {
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var connectionError: String?
    @Published var currentBoxIP = ""
    
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private let reconnectInterval: TimeInterval = 3.0
    
    func testConnection(ipAddress: String, completion: @escaping (Bool) -> Void) {
        guard !ipAddress.isEmpty else {
            self.connectionError = "Please enter an IP address"
            completion(false)
            return
        }
        
        isConnecting = true
        connectionError = nil
        
        let urlString = "http://\(ipAddress)/web/about"
        guard let url = URL(string: urlString) else {
            isConnecting = false
            connectionError = "Invalid IP address format"
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15  
        
        RequestLogger.shared.logRequest(url: url)
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            RequestLogger.shared.logResponse(for: url, statusCode: (response as? HTTPURLResponse)?.statusCode, data: data, error: error)
            
            DispatchQueue.main.async {
                self?.isConnecting = false
                
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == NSURLErrorDomain && 
                       (nsError.code == -1022 || nsError.code == -1004 || nsError.code == -1001) {
                        self?.connectionError = "Unable to find Enigma2 based set-top box"
                    } else {
                        self?.connectionError = "Connection error: \(error.localizedDescription)"
                    }
                    self?.isConnected = false
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.connectionError = "Invalid response from server"
                    self?.isConnected = false
                    completion(false)
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    self?.connectionError = "Server returned status code \(httpResponse.statusCode)"
                    self?.isConnected = false
                    completion(false)
                    return
                }
                
                self?.isConnected = true
                self?.currentBoxIP = ipAddress
                self?.reconnectAttempts = 0
                completion(true)
            }
        }
        task.resume()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            if self?.isConnecting == true {
                self?.isConnecting = false
                self?.connectionError = "Connection timed out - unable to reach the device"
                completion(false)
            }
        }
    }
    
    func disconnect() {
        stopReconnectTimer()
        isConnected = false
        currentBoxIP = ""
    }
    
    func startConnectionMonitoring() {
        stopConnectionMonitoring()
        guard !currentBoxIP.isEmpty else { return }
        // Periodic connection check timer removed based on feedback
    }
    
    func stopConnectionMonitoring() { 
        // No active timer to invalidate now
    }
    
    private func pingDevice(completion: @escaping (Bool) -> Void) {
        guard !currentBoxIP.isEmpty else {
            completion(false)
            return
        }
        let urlString = "http://\(currentBoxIP)/web/about"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5  
        
        RequestLogger.shared.logRequest(url: url)
        
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            RequestLogger.shared.logResponse(for: url, statusCode: (response as? HTTPURLResponse)?.statusCode, data: nil, error: error)
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Ping failed: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false)
                    return
                }
                completion(httpResponse.statusCode == 200)
            }
        }
        task.resume()
    }
    
    private func attemptReconnect() {
        guard !currentBoxIP.isEmpty && !isConnecting && reconnectAttempts < maxReconnectAttempts else {
            if reconnectAttempts >= maxReconnectAttempts {
                connectionError = "Reconnection failed after multiple attempts"
                reconnectAttempts = 0
            }
            return
        }
        
        print("Connection lost. Attempting to reconnect to \(currentBoxIP)...")
        reconnectAttempts += 1
        connectionError = "Connection lost. Attempting to reconnect... (\(reconnectAttempts)/\(maxReconnectAttempts))"
        
        stopReconnectTimer()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: reconnectInterval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.testConnection(ipAddress: self.currentBoxIP) { success in
                if success {
                    print("Reconnected successfully")
                    self.connectionError = nil
                    self.startConnectionMonitoring() // Restart monitoring (though it does nothing now)
                } else if self.reconnectAttempts < self.maxReconnectAttempts {
                    self.attemptReconnect()
                } else {
                    self.connectionError = "Reconnection failed after \(self.maxReconnectAttempts) attempts"
                    self.reconnectAttempts = 0
                }
            }
        }
    }
    
    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
}

class RemoteViewController: NSViewController {
    
    override func loadView() {
        print("Loading view")
        view = NSView()
        print("View loaded with frame: \(view.frame)")
        PreviewWindowController.shared.resetStoredSizes()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("View did load")
        setupUI()
    }
    
    private func setupUI() {
        print("Setting up SwiftUI integration")
        let remoteControlView = NSHostingController(rootView: RemoteControlView())
        addChild(remoteControlView)
        view.addSubview(remoteControlView.view)
        remoteControlView.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            remoteControlView.view.topAnchor.constraint(equalTo: view.topAnchor),
            remoteControlView.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            remoteControlView.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            remoteControlView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        print("SwiftUI view added")
    }
}

class PreviewWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

// MARK: - Separate Preview Window
class PreviewWindowController: NSWindowController {
    static let shared = PreviewWindowController()
    private var currentIP: String = ""
    var refreshInterval: Double = 5.0
    var isWindowVisible: Bool { return window?.isVisible ?? false }
    
    func resetStoredSizes() {
        TVPreviewLoader.shared.standardWindowSize = nil
    }
    
    override init(window: NSWindow?) {
        let contentRect = NSRect(x: 0, y: 0, width: 720, height: 475)
        let styleMask: NSWindow.StyleMask = [.titled, .closable]
        let window = PreviewWindow(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)
        window.title = "Enigma2 Preview"
        window.setContentSize(NSSize(width: 720, height: 475))
        window.minSize = NSSize(width: 720, height: 475)
        window.maxSize = NSSize(width: 720, height: 475)
        window.contentAspectRatio = NSSize(width: 720, height: 475)
        window.isRestorable = false
        window.collectionBehavior = .moveToActiveSpace
        window.isMovableByWindowBackground = false
        window.hasShadow = true
        window.backgroundColor = NSColor.black
        window.isOpaque = false
        window.acceptsMouseMovedEvents = true
        
        super.init(window: window)
        self.window!.delegate = WindowCloseDelegate.shared
        window.setFrame(NSRect(x: window.frame.origin.x, 
                               y: window.frame.origin.y, 
                               width: 720, 
                               height: 475 + window.frame.height - window.contentRect(forFrameRect: window.frame).height), 
                        display: true)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showPreview(with image: NSImage, fromIP: String, refreshInterval: Double = 5.0) {
        self.currentIP = fromIP
        self.refreshInterval = refreshInterval
        let wrapper = NSHostingView(rootView: 
            LargePreviewView(
                image: image, 
                ipAddress: fromIP, 
                refreshInterval: refreshInterval,
                tvPreviewLoader: TVPreviewLoader.shared,
                isHighResolution: TVPreviewLoader.shared.isHighResolution)
                .id(UUID()) 
        )
        wrapper.frame = NSRect(x: 0, y: 0, width: 720, height: 475)
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        let containerViewController = NSViewController()
        containerViewController.view = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 475))
        containerViewController.view.addSubview(wrapper)
        NSLayoutConstraint.activate([
            wrapper.topAnchor.constraint(equalTo: containerViewController.view.topAnchor),
            wrapper.leadingAnchor.constraint(equalTo: containerViewController.view.leadingAnchor),
            wrapper.widthAnchor.constraint(equalToConstant: 720),
            wrapper.heightAnchor.constraint(equalToConstant: 475),
            containerViewController.view.widthAnchor.constraint(equalToConstant: 720),
            containerViewController.view.heightAnchor.constraint(equalToConstant: 475)
        ])
        window?.contentViewController = containerViewController
        if let window = self.window {
            window.setContentSize(NSSize(width: 720, height: 475))
            let titleBarHeight = window.frame.height - window.contentRect(forFrameRect: window.frame).height
            let correctFrameSize = NSSize(width: 720, height: 475 + titleBarHeight)
            window.setFrame(NSRect(x: window.frame.origin.x,
                                  y: window.frame.origin.y,
                                  width: correctFrameSize.width,
                                  height: correctFrameSize.height),
                           display: true, animate: false)
            print("Preview window set to frame size: \(window.frame.size), content size: \(window.contentView?.frame.size ?? .zero)")
        }
        ensureSpaceForPopupWindow()
        positionWindowNextToMainWindow(forcePosition: true)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        setupWindowAttachment()
    }
    
    private func ensureSpaceForPopupWindow() {
        guard let mainWindow = NSApplication.shared.windows.first(where: { $0.title == "Enigma2 Remote" }),
              let popupWindow = self.window,
              let screen = mainWindow.screen else { return }
        let screenFrame = screen.visibleFrame
        let mainFrame = mainWindow.frame
        let popupWidth = popupWindow.frame.width
        let gap: CGFloat = 5
        let availableSpaceOnRight = screenFrame.maxX - mainFrame.maxX - gap
        if availableSpaceOnRight < popupWidth {
            let needToMoveLeft = popupWidth - availableSpaceOnRight + gap
            let canMoveLeft = mainFrame.minX - screenFrame.minX
            let moveDistance = min(needToMoveLeft, canMoveLeft)
            if moveDistance > 0 {
                var newMainFrame = mainFrame
                newMainFrame.origin.x = max(screenFrame.minX, mainFrame.minX - needToMoveLeft)
                mainWindow.setFrame(newMainFrame, display: true, animate: true)
                Thread.sleep(forTimeInterval: 0.3)
            } else if mainFrame.width > 400 { 
                var newMainFrame = mainFrame
                newMainFrame.size.width = max(400, mainFrame.width - needToMoveLeft)
                mainWindow.setFrame(newMainFrame, display: true, animate: true)
                Thread.sleep(forTimeInterval: 0.3)
            }
        }
    }
    
    func positionWindowNextToMainWindow(forcePosition: Bool = false) {
        guard let mainWindow = NSApplication.shared.windows.first(where: { $0.title == "Enigma2 Remote" }),
              let popupWindow = self.window else { return }
        let mainFrame = mainWindow.frame
        let popupFrame = popupWindow.frame
        let gap: CGFloat = 5 
        let newX = mainFrame.maxX + gap
        let newY = mainFrame.maxY - popupFrame.height
        if let screen = mainWindow.screen {
            let screenFrame = screen.visibleFrame
            let adjustedX = min(newX, screenFrame.maxX - popupFrame.width)
            popupWindow.setFrameOrigin(NSPoint(x: adjustedX, y: newY))
        } else {
            popupWindow.setFrameOrigin(NSPoint(x: newX, y: newY))
        }
    }
    
    private func setupWindowAttachment() {
        guard let previewWindow = self.window,
              let mainWindow = NSApplication.shared.windows.first(where: { $0.title == "Enigma2 Remote" }) else { return }
        if previewWindow.parent == nil {
            mainWindow.addChildWindow(previewWindow, ordered: .above)
        }
    }
    
    func updatePreviewImage(image: NSImage, fromIP: String) {
        guard window?.isVisible ?? false else { return }
        let wrapper = NSHostingView(rootView: LargePreviewView(
            image: image, 
            ipAddress: fromIP, 
            refreshInterval: self.refreshInterval,
            tvPreviewLoader: TVPreviewLoader.shared,
            isHighResolution: TVPreviewLoader.shared.isHighResolution)
        )
        wrapper.frame = NSRect(x: 0, y: 0, width: 720, height: 475)
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        let containerViewController = NSViewController()
        containerViewController.view = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 475))
        containerViewController.view.addSubview(wrapper)
        NSLayoutConstraint.activate([
            wrapper.topAnchor.constraint(equalTo: containerViewController.view.topAnchor),
            wrapper.leadingAnchor.constraint(equalTo: containerViewController.view.leadingAnchor),
            wrapper.widthAnchor.constraint(equalToConstant: 720),
            wrapper.heightAnchor.constraint(equalToConstant: 475),
            containerViewController.view.widthAnchor.constraint(equalToConstant: 720),
            containerViewController.view.heightAnchor.constraint(equalToConstant: 475)
        ])
        window?.contentViewController = containerViewController
        if let window = self.window {
            let contentSize = window.contentView?.frame.size ?? .zero
            if abs(contentSize.width - 720) > 1 || abs(contentSize.height - 475) > 1 {
                DispatchQueue.main.async {
                    window.setContentSize(NSSize(width: 720, height: 475))
                }
            }
        }
    }
    
    func closeWindow() {
        print("Closing preview window and stopping refresh timer")
        if let window = self.window, let parent = window.parent {
            parent.removeChildWindow(window)
        }
        window?.close()
    }
}

// Window delegate to handle window closing and movement
class WindowCloseDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowCloseDelegate()
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, 
           window == PreviewWindowController.shared.window {
            if let parent = window.parent { parent.removeChildWindow(window) }
            TVPreviewLoader.shared.stopRefreshing()
        } else if let window = notification.object as? NSWindow,
                  window == DebugWindowController.shared.window {
             if let parent = window.parent {
                 parent.removeChildWindow(window)
                 print("Detached Debug window on close")
             }
        }
        
        DispatchQueue.main.async {
            let isPreviewVisible = PreviewWindowController.shared.isWindowVisible
            let isDebugVisible = DebugWindowController.shared.isWindowVisible
            
            if !isPreviewVisible && !isDebugVisible {
                if let window = NSApplication.shared.windows.first(where: { $0.title == "Enigma2 Remote" }) {
                    let frame = window.frame
                    let newFrame = NSRect(x: frame.origin.x, y: frame.origin.y, width: frame.size.width, height: 800)
                    window.setFrame(newFrame, display: true, animate: true)
                    print("Resized main window as both popups are closed.")
                }
            }
        }
    }
    
    func windowDidMove(_ notification: Notification) {
        guard let movedWindow = notification.object as? NSWindow,
              movedWindow.title == "Enigma2 Remote" else { return }
        
        if let previewWindow = PreviewWindowController.shared.window, previewWindow.isVisible {
            PreviewWindowController.shared.positionWindowNextToMainWindow()
        }
        if let debugWindow = DebugWindowController.shared.window, debugWindow.isVisible {
            DebugWindowController.shared.positionWindowToLeftOfMainWindow()
        }
    }
}

// MARK: - Large Preview View
struct LargePreviewView: View {
    @State var image: NSImage
    let ipAddress: String
    @State private var showSavePanel = false
    @State var lastRefreshTime = Date()
    @State private var refreshInterval: Double
    @State private var isHighResolution: Bool
    @ObservedObject var tvPreviewLoader: TVPreviewLoader
    
    init(image: NSImage, ipAddress: String, refreshInterval: Double, tvPreviewLoader: TVPreviewLoader, isHighResolution: Bool) {
        self.image = image
        self.ipAddress = ipAddress
        self.refreshInterval = refreshInterval
        self.isHighResolution = isHighResolution
        self.tvPreviewLoader = tvPreviewLoader
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
            
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("Refresh:")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize()
                    Slider(
                        value: $refreshInterval,
                        in: 1...30,
                        step: 1,
                        onEditingChanged: { editing in
                            if !editing {
                                tvPreviewLoader.loadPreview(
                                    from: ipAddress, 
                                    refreshInterval: refreshInterval,
                                    highResolution: isHighResolution
                                )
                                PreviewWindowController.shared.refreshInterval = refreshInterval
                            }
                        }
                    )
                    .frame(maxWidth: .infinity)
                    Text("\(Int(refreshInterval))s")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 25, alignment: .trailing)
                        .fixedSize()
                }
                .padding(.horizontal, 8)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enigma2 Box: \(ipAddress)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Auto-refreshing")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle(isOn: Binding(
                        get: { tvPreviewLoader.isHighResolution },
                        set: { newValue in
                            if tvPreviewLoader.isHighResolution == newValue { return }
                            tvPreviewLoader.stopRefreshing()
                            isHighResolution = newValue
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                let refreshInterval = PreviewWindowController.shared.refreshInterval
                                tvPreviewLoader.loadPreview(
                                    from: ipAddress,
                                    refreshInterval: refreshInterval,
                                    highResolution: newValue
                                )
                            }
                        }
                    )) {
                        Text(tvPreviewLoader.isHighResolution ? "HD" : "SD")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .padding(.horizontal, 5)
                    Button(action: { saveImage() }) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save Image")
                    }
                    .padding(.horizontal, 5)
                }
                .padding(.horizontal)
                .padding(.bottom, 5)
            }
            .padding(.top, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .onAppear {
            DispatchQueue.main.async {
                isHighResolution = tvPreviewLoader.isHighResolution
            }
        }
    }
    
    private func saveImage() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.jpeg]
        savePanel.nameFieldStringValue = "Enigma2-Screenshot-\(Int(Date().timeIntervalSince1970)).jpg"
        savePanel.beginSheetModal(for: NSApp.keyWindow!) { response in
            if response == .OK, let url = savePanel.url {
                if let imageData = image.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: imageData),
                   let jpegData = bitmapImage.representation(using: .jpeg, properties: [:]) {
                    try? jpegData.write(to: url)
                }
            }
        }
    }
}

// MARK: - TV Screen Preview
class TVPreviewLoader: ObservableObject {
    static let shared = TVPreviewLoader()
    @Published var image: NSImage?
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastUpdated = Date()
    @Published var standardWindowSize: NSSize?
    @Published var isHighResolution: Bool = UserDefaults.standard.bool(forKey: "previewHighResolution")
    var onFirstImageLoaded: ((NSImage?) -> Void)?
    private var currentIP = ""
    private var refreshTimer: Timer?
    private var dataTask: URLSessionDataTask?
    
    private init() {}
    
    func loadPreview(from ipAddress: String, refreshInterval: Double, highResolution: Bool) {
        stopRefreshing()
        currentIP = ipAddress
        UserDefaults.standard.set(highResolution, forKey: "previewHighResolution")
        isHighResolution = highResolution
        print("Starting preview @ \(ipAddress) resolution: \(highResolution ? "HD" : "SD")")
        fetchImage(ipAddress: ipAddress, highResolution: highResolution)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            self.fetchImage(ipAddress: ipAddress, highResolution: highResolution)
        }
        RunLoop.main.add(refreshTimer!, forMode: .common)
    }
    
    func stopRefreshing() {
        dataTask?.cancel()
        dataTask = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
        print("Preview refresh stopped")
    }
    
    func fetchImage(ipAddress: String, highResolution: Bool) {
        guard !ipAddress.isEmpty else { return }
        let urlString = highResolution ? "http://\(ipAddress)/grab?format=jpg&mode=all" : "http://\(ipAddress)/grab?format=jpg&r=720"
        guard let url = URL(string: urlString) else {
            error = "Invalid URL"
            return
        }
        isLoading = true
        dataTask?.cancel()
        RequestLogger.shared.logRequest(url: url)
        dataTask = URLSession.shared.dataTask(with: url) { [weak self] data, resp, err in
            RequestLogger.shared.logResponse(for: url, statusCode: (resp as? HTTPURLResponse)?.statusCode, data: data, error: err)
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                if let nsErr = err as NSError?, nsErr.code == NSURLErrorCancelled { return }
                if let err = err {
                    self.error = "Error: \(err.localizedDescription)"
                    return
                }
                guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                      let data = data, let img = NSImage(data: data) else {
                    self.error = "Invalid response or no data"
                    return
                }
                let isFirstImage = self.image == nil
                self.image = img
                self.error = nil
                self.lastUpdated = Date()
                if isFirstImage, let callback = self.onFirstImageLoaded {
                    callback(img)
                    self.onFirstImageLoaded = nil
                }
                if PreviewWindowController.shared.isWindowVisible {
                    PreviewWindowController.shared.updatePreviewImage(image: img, fromIP: ipAddress)
                }
            }
        }
        dataTask?.resume()
    }
}

// MARK: - SwiftUI Remote Control View
struct RemoteControlView: View {
    @State private var ipAddress: String = ""
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var isConnecting: Bool = false
    @State private var lastCommandSent: Int? = nil
    @State private var showPreview: Bool = false
    @State private var refreshInterval: Double = 5.0
    @State private var showPowerConfirmation: Bool = false
    @StateObject private var tvPreviewLoader = TVPreviewLoader.shared
    @StateObject private var connectionManager = ConnectionManager()
    @StateObject private var debugLogger = RequestLogger.shared 
    
    @State private var savedDevices: [String] = UserDefaults.standard.stringArray(forKey: "savedDevices") ?? []
    @State private var showDevicesDropdown: Bool = false
    @State private var selectedDeviceIndex: Int = -1
    
    let defaultWindowHeight: CGFloat = 800
    private let buttonSize: CGFloat = 50
    private let numberButtonSize: CGFloat = 40
    private let spacing: CGFloat = 8
    private let verticalSpacing: CGFloat = 4
    private let cornerRadius: CGFloat = 8
    private let remoteWidth: CGFloat = 280
    private let topButtonHeight: CGFloat = 35 
    
    var body: some View {
        ZStack {
            backgroundGradient
            contentScroll
            if isConnecting {
                ProgressView()
                VStack {
                    ProgressView().scaleEffect(1.0).padding()
                    Text("Connecting...").font(.caption)
                }
                .padding(15)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
                .cornerRadius(8)
                .shadow(radius: 5)
            }
        }
        .frame(width: remoteWidth)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .alert("Power Down Device?", isPresented: $showPowerConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Power Down", role: .destructive) { sendCommand(116) }
        } message: {
            Text("Are you sure you want to power down the Enigma2 device?")
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let window = NSApplication.shared.windows.first {
                    var frame = window.frame
                    frame.size.height = defaultWindowHeight
                    window.setFrame(frame, display: true, animate: false)
                }
            }
        }
        .onTapGesture { showDevicesDropdown = false }
        .onChange(of: connectionManager.isConnected) { _, newValue in
            if newValue { connectionManager.startConnectionMonitoring() }
        }
        .onDisappear {
            if PreviewWindowController.shared.isWindowVisible {
                PreviewWindowController.shared.closeWindow()
            }
            if DebugWindowController.shared.isWindowVisible {
                 DebugWindowController.shared.closeWindow()
            }
            tvPreviewLoader.stopRefreshing()
        }
    }
    
    private var contentScroll: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Enigma2 Remote")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .padding(.top, 8)
                
                HStack {
                    Circle()
                        .fill(connectionManager.isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(connectionManager.isConnected ? "Connected to \(connectionManager.currentBoxIP)" : "Not Connected")
                        .font(.system(size: 12))
                        .foregroundColor(connectionManager.isConnected ? .secondary : .red)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 0)
                
                ipAddressInput // Use the modified ipAddressInput with Toggle switch
                
                if let error = connectionManager.connectionError, !connectionManager.isConnected {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 2)
                }
                
                VStack(spacing: 6) {
                    HStack {
                        Spacer()

                        // Debug Button (Left)
                        Button(action: {
                            if DebugWindowController.shared.isWindowVisible {
                                DebugWindowController.shared.closeWindow()
                            } else {
                                DebugWindowController.shared.showWindow()
                            }
                        }) {
                            VStack(spacing: 2) {
                                Image(systemName: DebugWindowController.shared.isWindowVisible ? "ladybug.fill" : "ladybug") 
                                    .font(.system(size: 14))
                                Text("Debug")
                                    .font(.system(size: 9))
                            }
                            .frame(height: topButtonHeight) 
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(!connectionManager.isConnected) 
                        .help("Click to \(DebugWindowController.shared.isWindowVisible ? "hide" : "show") request logs")
                        .padding(.trailing, 10) 
                        
                        // Screen Button (Right)
                        Button(action: {
                            if PreviewWindowController.shared.isWindowVisible {
                                PreviewWindowController.shared.closeWindow()
                                tvPreviewLoader.stopRefreshing()
                            } else {
                                if let currentImage = tvPreviewLoader.image {
                                    PreviewWindowController.shared.showPreview(
                                        with: currentImage,
                                        fromIP: connectionManager.currentBoxIP,
                                        refreshInterval: refreshInterval
                                    )
                                } else {
                                    tvPreviewLoader.loadPreview(
                                        from: connectionManager.currentBoxIP, 
                                        refreshInterval: refreshInterval,
                                        highResolution: tvPreviewLoader.isHighResolution
                                    )
                                    tvPreviewLoader.onFirstImageLoaded = { image in
                                        if let image = image {
                                            PreviewWindowController.shared.showPreview(
                                                with: image, 
                                                fromIP: connectionManager.currentBoxIP,
                                                refreshInterval: refreshInterval
                                            )
                                        }
                                    }
                                }
                            }
                        }) {
                            VStack(spacing: 2) {
                                Image(systemName: PreviewWindowController.shared.isWindowVisible ? "tv.fill" : "tv")
                                    .font(.system(size: 14))
                                Text("Screen")
                                    .font(.system(size: 9))
                            }
                            .frame(height: topButtonHeight) 
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(!connectionManager.isConnected)
                        .help("Click to \(PreviewWindowController.shared.isWindowVisible ? "hide" : "show") live TV preview")
                        
                    }
                    .padding(.horizontal, 16) 
                }
                
                // Function buttons
                VStack(spacing: verticalSpacing) {
                    HStack {
                        Spacer().frame(width: 50)
                        Button { sendPowerStateCommand(newState: 0) } label: { // Updated Action
                            VStack(spacing: 2) {
                                Image(systemName: "powersleep").font(.system(size: 12))
                                Text("Standby").font(.system(size: 8))
                            }.frame(width: buttonSize, height: buttonSize/1.5)
                        }.buttonStyle(.bordered).controlSize(.mini).disabled(!connectionManager.isConnected)
                        Spacer()
                        Button { sendCommand(388) } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "text.alignleft").font(.system(size: 12))
                                Text("Text").font(.system(size: 8))
                            }.frame(width: buttonSize, height: buttonSize/1.5)
                        }.buttonStyle(.bordered).controlSize(.mini).disabled(!connectionManager.isConnected)
                        Spacer()
                        Button { showPowerDownConfirmation() } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "power").font(.system(size: 12))
                                Text("Power").font(.system(size: 8))
                            }.frame(width: buttonSize, height: buttonSize/1.5)
                        }.buttonStyle(.bordered).controlSize(.mini).disabled(!connectionManager.isConnected)
                        Spacer().frame(width: 50)
                    }
                    HStack {
                        Spacer().frame(width: 50)
                        Button { sendCommand(370) } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "captions.bubble").font(.system(size: 12))
                                Text("Sub").font(.system(size: 8))
                            }.frame(width: buttonSize, height: buttonSize/1.5)
                        }.buttonStyle(.bordered).controlSize(.mini).disabled(!connectionManager.isConnected)
                        Spacer()
                        Button { sendCommand(227) } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "tv.and.mediabox").font(.system(size: 12))
                                Text("AV").font(.system(size: 8))
                            }.frame(width: buttonSize, height: buttonSize/1.5)
                        }.buttonStyle(.bordered).controlSize(.mini).disabled(!connectionManager.isConnected)
                        Spacer()
                        Button { sendCommand(138) } label: { 
                            VStack(spacing: 2) {
                                Image(systemName: "questionmark.circle").font(.system(size: 12))
                                Text("Help").font(.system(size: 8))
                            }.frame(width: buttonSize, height: buttonSize/1.5)
                        }.buttonStyle(.bordered).controlSize(.mini).disabled(!connectionManager.isConnected)
                        Spacer().frame(width: 50)
                    }
                }
                .frame(width: remoteWidth)
                .padding(.vertical, 6)
                
                // Navigation buttons section
                VStack(spacing: verticalSpacing) {
                    let leftMargin: CGFloat = 50
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.clear).frame(width: remoteWidth, height: buttonSize)
                        RemoteButton(icon: "list.bullet.rectangle", label: "PVR", command: 393, action: sendCommand)
                            .frame(width: buttonSize, height: buttonSize).disabled(!connectionManager.isConnected)
                            .position(x: leftMargin + buttonSize/2, y: buttonSize/2)
                        RemoteButton(icon: "list.bullet", label: "MENU", command: 139, action: sendCommand)
                            .frame(width: buttonSize, height: buttonSize).disabled(!connectionManager.isConnected)
                            .position(x: remoteWidth - leftMargin - buttonSize/2, y: buttonSize/2)
                    }.frame(width: remoteWidth, height: buttonSize)
                    HStack {
                        Spacer()
                        RemoteButton(icon: "chevron.up", label: "", command: 103, action: sendCommand)
                            .frame(width: buttonSize, height: buttonSize).disabled(!connectionManager.isConnected)
                        Spacer()
                    }.frame(width: remoteWidth)
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.clear).frame(width: remoteWidth, height: buttonSize)
                        RemoteButton(icon: "chevron.left", label: "", command: 105, action: sendCommand)
                            .frame(width: buttonSize, height: buttonSize).disabled(!connectionManager.isConnected)
                            .position(x: leftMargin + buttonSize/2, y: buttonSize/2)
                        RemoteButton(icon: "checkmark.circle", label: "OK", command: 352, action: sendCommand)
                            .frame(width: buttonSize, height: buttonSize).disabled(!connectionManager.isConnected)
                            .position(x: remoteWidth/2, y: buttonSize/2)
                        RemoteButton(icon: "chevron.right", label: "", command: 106, action: sendCommand)
                            .frame(width: buttonSize, height: buttonSize).disabled(!connectionManager.isConnected)
                            .position(x: remoteWidth - leftMargin - buttonSize/2, y: buttonSize/2)
                    }.frame(width: remoteWidth, height: buttonSize)
                    HStack {
                        Spacer()
                        RemoteButton(icon: "chevron.down", label: "", command: 108, action: sendCommand)
                            .frame(width: buttonSize, height: buttonSize).disabled(!connectionManager.isConnected)
                        Spacer()
                    }.frame(width: remoteWidth)
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.clear).frame(width: remoteWidth, height: buttonSize)
                        RemoteButton(icon: "calendar", label: "EPG", command: 358, action: sendCommand)
                            .frame(width: buttonSize, height: buttonSize).disabled(!connectionManager.isConnected)
                            .position(x: leftMargin + buttonSize/2, y: buttonSize/2)
                        RemoteButton(icon: "escape", label: "EXIT", command: 174, action: sendCommand)
                            .frame(width: buttonSize, height: buttonSize).disabled(!connectionManager.isConnected)
                            .position(x: remoteWidth - leftMargin - buttonSize/2, y: buttonSize/2)
                    }.frame(width: remoteWidth, height: buttonSize)
                }
                .padding(.bottom, 2)
                
                // Number buttons
                VStack(spacing: verticalSpacing) {
                    ForEach(0..<3) { row in
                        HStack(spacing: spacing) {
                            Spacer().frame(width: 70)
                            ForEach(1...3, id: \.self) { col in
                                let number = row * 3 + col
                                NumberButton(number: number, action: sendCommand)
                                    .frame(width: numberButtonSize, height: numberButtonSize).disabled(!connectionManager.isConnected)
                                if col < 3 { Spacer() }
                            }
                            Spacer().frame(width: 70)
                        }
                    }
                    HStack(spacing: spacing) {
                        Spacer().frame(width: 70)
                        Spacer()
                        NumberButton(number: 0, action: sendCommand)
                            .frame(width: numberButtonSize, height: numberButtonSize).disabled(!connectionManager.isConnected)
                        Spacer()
                        Spacer().frame(width: 70)
                    }
                }
                .padding(.vertical, 3)
                .frame(width: remoteWidth)
                
                // Color buttons
                HStack(spacing: spacing) {
                    Spacer()
                    ColoredButton(color: .red, label: "Red", command: 398, action: sendCommand).disabled(!connectionManager.isConnected)
                    ColoredButton(color: .green, label: "Green", command: 399, action: sendCommand).disabled(!connectionManager.isConnected)
                    ColoredButton(color: .yellow, label: "Yellow", command: 400, action: sendCommand).disabled(!connectionManager.isConnected)
                    ColoredButton(color: .blue, label: "Blue", command: 401, action: sendCommand).disabled(!connectionManager.isConnected)
                    Spacer()
                }
                .padding(.bottom, 8)
                .frame(width: remoteWidth)
            }
            .frame(width: remoteWidth)
        }
    }
    
    private func handleDownArrow() {
        if !savedDevices.isEmpty {
            if !showDevicesDropdown {
                showDevicesDropdown = true
                selectedDeviceIndex = 0
            } else {
                selectedDeviceIndex = min(selectedDeviceIndex + 1, savedDevices.count - 1)
            }
        }
    }
    
    private func handleUpArrow() {
        if showDevicesDropdown && !savedDevices.isEmpty {
            if selectedDeviceIndex > 0 {
                selectedDeviceIndex -= 1
            } else {
                showDevicesDropdown = false
            }
        }
    }
    
    private func connectToBox() {
        isConnecting = true 
        connectionManager.testConnection(ipAddress: ipAddress) { success in
            isConnecting = false 
            if success {
                if !savedDevices.contains(ipAddress) {
                    savedDevices.append(ipAddress)
                    UserDefaults.standard.set(savedDevices, forKey: "savedDevices")
                }
                connectionManager.startConnectionMonitoring()
            } else {
                alertMessage = connectionManager.connectionError ?? "Connection failed"
                showAlert = true
            }
        }
    }
    
    private func disconnectFromBox() {
        connectionManager.disconnect()
        if PreviewWindowController.shared.isWindowVisible { PreviewWindowController.shared.closeWindow() }
        if DebugWindowController.shared.isWindowVisible { DebugWindowController.shared.closeWindow() } 
        tvPreviewLoader.stopRefreshing()
    }
    
    private func sendCommand(_ command: Int) {
        guard connectionManager.isConnected else {
            alertMessage = "Not connected to an Enigma2 box"
            showAlert = true
            return
        }
        let ipAddress = connectionManager.currentBoxIP
        let urlString = "http://\(ipAddress)/web/remotecontrol?command=\(command)"
        guard let url = URL(string: urlString) else {
            alertMessage = "Invalid IP address"
            showAlert = true
            return
        }
        lastCommandSent = command
        RequestLogger.shared.logRequest(url: url)
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            RequestLogger.shared.logResponse(for: url, statusCode: (response as? HTTPURLResponse)?.statusCode, data: data, error: error)
            DispatchQueue.main.async {
                if let error = error {
                    alertMessage = "Error: \(error.localizedDescription)"
                    showAlert = true
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    alertMessage = "Invalid response from server"
                    showAlert = true
                    return
                }
                if httpResponse.statusCode != 200 {
                    alertMessage = "Error: Server returned status code \(httpResponse.statusCode)"
                    showAlert = true
                }
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
                if PreviewWindowController.shared.isWindowVisible {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        let currentResolution = TVPreviewLoader.shared.isHighResolution
                        TVPreviewLoader.shared.fetchImage(ipAddress: ipAddress, highResolution: currentResolution)
                    }
                }
            }
        }
        task.resume()
    }
    
    // New function to send power state commands
    private func sendPowerStateCommand(newState: Int) {
         guard connectionManager.isConnected else {
             alertMessage = "Not connected to an Enigma2 box"
             showAlert = true
             return
         }
         
         let ipAddress = connectionManager.currentBoxIP
         let urlString = "http://\(ipAddress)/web/powerstate?newstate=\(newState)"
         guard let url = URL(string: urlString) else {
             alertMessage = "Invalid IP address or command format"
             showAlert = true
             return
         }
         
         RequestLogger.shared.logRequest(url: url)
         
         let task = URLSession.shared.dataTask(with: url) { data, response, error in
             RequestLogger.shared.logResponse(for: url, statusCode: (response as? HTTPURLResponse)?.statusCode, data: data, error: error)
             DispatchQueue.main.async {
                 if let error = error {
                     alertMessage = "Error: \(error.localizedDescription)"
                     showAlert = true
                     return
                 }
                 guard let httpResponse = response as? HTTPURLResponse else {
                     alertMessage = "Invalid response from server"
                     showAlert = true
                     return
                 }
                 if httpResponse.statusCode != 200 {
                     alertMessage = "Error: Server returned status code \(httpResponse.statusCode)"
                     showAlert = true
                 }
                 // Optionally provide feedback or update UI based on response data if needed
                 NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
             }
         }
         task.resume()
     }

    
    private func showPowerDownConfirmation() {
        showPowerConfirmation = true
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color(NSColor.windowBackgroundColor), Color(NSColor.controlBackgroundColor)]),
            startPoint: .top,
            endPoint: .bottom
        )
        .edgesIgnoringSafeArea(.all)
    }
    
    // Modified ipAddressInput to include Connect/Disconnect Toggle switch on the right
    private var ipAddressInput: some View {
        VStack(spacing: 4) {
            HStack(alignment: .center) { 
                Image(systemName: "network").foregroundColor(.secondary).font(.system(size: 14)) // Keep network icon on left
                
                // Text Field and Dropdown container
                HStack(spacing: 0) {
                    TextField("IP Address", text: $ipAddress, onCommit: {
                        if !connectionManager.isConnected && !ipAddress.isEmpty { connectToBox() }
                    })
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14))
                    .disabled(connectionManager.isConnecting || connectionManager.isConnected) 
                    .onKeyPress(.downArrow) { handleDownArrow(); return .handled }
                    .onKeyPress(.upArrow) { handleUpArrow(); return .handled }
                    .onKeyPress(.escape) { if showDevicesDropdown { showDevicesDropdown = false; return .handled }; return .ignored }
                    .onKeyPress(.return) { if showDevicesDropdown && selectedDeviceIndex >= 0 && selectedDeviceIndex < savedDevices.count { ipAddress = savedDevices[selectedDeviceIndex]; showDevicesDropdown = false; return .handled }; return .ignored }
                    
                    Button(action: {
                        if !savedDevices.isEmpty {
                            showDevicesDropdown.toggle()
                            if showDevicesDropdown { selectedDeviceIndex = -1 }
                        }
                    }) {
                        Image(systemName: "chevron.down").font(.system(size: 12)).foregroundColor(.secondary).frame(width: 20)
                    }
                    .disabled(connectionManager.isConnecting || connectionManager.isConnected) 
                }
                .padding(EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 4)) 
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                .layoutPriority(1) // Allow text field/dropdown to take space

                Spacer(minLength: 8) // Space before toggle

                // Connect/Disconnect Toggle Switch
                Toggle("", isOn: Binding(
                    get: { connectionManager.isConnected },
                    set: { newValue in
                        // Prevent toggling on if IP is empty
                        if newValue && ipAddress.isEmpty {
                            // Optionally show an alert or just do nothing
                            print("Cannot connect with empty IP address")
                            // Force the toggle back off visually if needed (though disabled should prevent this)
                             DispatchQueue.main.async {
                                 connectionManager.objectWillChange.send()
                             }
                            return 
                        }
                        
                        if newValue {
                            connectToBox()
                        } else {
                            disconnectFromBox()
                        }
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: connectionManager.isConnected ? .green : .gray))
                .disabled(connectionManager.isConnecting || (!connectionManager.isConnected && ipAddress.isEmpty)) 
                .help(connectionManager.isConnected ? "Disconnect" : "Connect")
                .frame(width: 40) 
                 
            }
            .padding(.horizontal, 16)

            // Saved devices dropdown (remains below)
            if showDevicesDropdown && !savedDevices.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(savedDevices.enumerated()), id: \.element) { index, device in
                        HStack {
                            Text(device)
                                .font(.system(size: 12))
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .background(selectedDeviceIndex == index ? Color.blue.opacity(0.2) : Color.clear)
                                .onTapGesture {
                                    ipAddress = device
                                    showDevicesDropdown = false
                                    if !connectionManager.isConnected {
                                        connectToBox()
                                    }
                                }
                            Button(action: {
                                if let deviceIndex = savedDevices.firstIndex(of: device) {
                                    savedDevices.remove(at: deviceIndex)
                                    UserDefaults.standard.set(savedDevices, forKey: "savedDevices")
                                    if selectedDeviceIndex >= deviceIndex && selectedDeviceIndex > 0 {
                                        selectedDeviceIndex -= 1
                                    }
                                }
                            }) {
                                Image(systemName: "trash").font(.system(size: 10)).foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.trailing, 8)
                        }
                        .background(selectedDeviceIndex == index ? Color.blue.opacity(0.2) : Color(NSColor.textBackgroundColor))
                        if device != savedDevices.last { Divider().padding(.leading, 8) }
                    }
                }
                .background(Color(NSColor.windowBackgroundColor)) 
                .cornerRadius(6)
                .shadow(radius: 3)
                .padding(.horizontal, 16) 
                .offset(y: -2) 
                .zIndex(1) 
            }
        }
    }
}

// MARK: - Tooltip View
struct TooltipView: View {
    let text: String
    @State private var showTooltip = false
    var body: some View {
        ZStack(alignment: .top) {
            if showTooltip {
                Text(text).font(.caption).foregroundColor(.white).padding(6).background(Color.black.opacity(0.7)).cornerRadius(5).offset(y: 30).transition(.opacity).zIndex(1)
            }
        }
        .onAppear {
            withAnimation(.easeIn.delay(0.5)) { showTooltip = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { withAnimation { showTooltip = false } }
        }
    }
}

// MARK: - TV Preview View
struct TVPreviewView: View {
    @ObservedObject var previewLoader: TVPreviewLoader
    var onTap: (() -> Void)? = nil
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color.black).shadow(radius: 2)
            if let image = previewLoader.image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).cornerRadius(6)
                    .overlay(
                        HStack {
                            Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 14)).foregroundColor(.white).padding(5).background(Color.black.opacity(0.6)).cornerRadius(4).padding(4)
                        }.opacity(0.8).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    )
                    .onTapGesture { if let onTap = onTap { onTap() } }
                    .contentShape(Rectangle()) 
            } else if previewLoader.isLoading {
                ProgressView().scaleEffect(0.8)
            } else if let error = previewLoader.error {
                VStack {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 20)).foregroundColor(.yellow)
                    Text(error).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                }
            } else {
                VStack {
                    Image(systemName: "tv").font(.system(size: 24)).foregroundColor(.gray)
                    Text("No preview available").font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Button Components
struct RemoteButton: View {
    let icon: String
    let label: String
    let command: Int
    let action: (Int) -> Void
    @Environment(\.isEnabled) private var isEnabled
    var body: some View {
        Button { action(command) } label: {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                if !label.isEmpty { Text(label).font(.system(size: 9)) }
            }.frame(minWidth: 40, minHeight: 40).contentShape(Rectangle())
        }.buttonStyle(.bordered).controlSize(.small)
    }
}

struct NumberButton: View {
    let number: Int
    let action: (Int) -> Void
    @Environment(\.isEnabled) private var isEnabled
    var body: some View {
        Button { action(number + 100) } label: {
            Text("\(number)").font(.system(size: 18, weight: .medium, design: .rounded)).frame(minWidth: 35, minHeight: 35).contentShape(Rectangle())
        }.buttonStyle(.bordered).controlSize(.small)
    }
}

struct ColoredButton: View {
    let color: Color
    let label: String
    let command: Int
    let action: (Int) -> Void
    @Environment(\.isEnabled) private var isEnabled
    var body: some View {
        Button { action(command) } label: {
            VStack(spacing: 2) {
                Circle().fill(isEnabled ? color : color.opacity(0.5)).frame(width: 14, height: 14)
                Text(label).font(.system(size: 9))
            }.frame(minWidth: 40, minHeight: 40).contentShape(Rectangle())
        }.buttonStyle(.bordered).controlSize(.small)
    }
}
