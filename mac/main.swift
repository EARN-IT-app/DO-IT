// DO IT for Mac: a menu bar app that closes the apps you pick and sends you to
// the DO IT website instead. The website's photo + video steps end by opening
// doit://break?minutes=N, which gives you that many minutes with the apps.
import AppKit
import SwiftUI
import ServiceManagement

let siteURL = URL(string: "https://wonderbread4912.github.io/DO-IT/?from=mac")!
let maxBreakMinutes = 60.0

// MARK: - Saved settings

final class Store: ObservableObject {
    static let shared = Store()

    @Published var blocked: Set<String> {
        didSet { UserDefaults.standard.set(Array(blocked), forKey: "blocked") }
    }
    @Published var breakUntil: Date {
        didSet { UserDefaults.standard.set(breakUntil.timeIntervalSince1970, forKey: "breakUntil") }
    }

    init() {
        blocked = Set(UserDefaults.standard.stringArray(forKey: "blocked") ?? [])
        breakUntil = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: "breakUntil"))
    }

    var onBreak: Bool { breakUntil > Date() }
    var minutesLeft: Int { max(0, Int(ceil(breakUntil.timeIntervalSinceNow / 60))) }
}

// MARK: - Apps installed on this Mac

struct InstalledApp: Identifiable {
    let id: String   // bundle identifier
    let name: String
    let icon: NSImage
}

func installedApps() -> [InstalledApp] {
    let fm = FileManager.default
    let folders = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications"),
        fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
    ]
    let skip: Set<String> = [Bundle.main.bundleIdentifier ?? "", "com.apple.finder", "com.apple.systempreferences"]
    var seen = Set<String>()
    var apps: [InstalledApp] = []
    for folder in folders {
        guard let items = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { continue }
        for url in items where url.pathExtension == "app" {
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier,
                  !skip.contains(id), !seen.contains(id) else { continue }
            seen.insert(id)
            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            apps.append(InstalledApp(id: id, name: name, icon: NSWorkspace.shared.icon(forFile: url.path)))
        }
    }
    return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

// MARK: - "Pick the apps to block" window

struct ChooserView: View {
    @ObservedObject var store = Store.shared
    let apps: [InstalledApp]
    @State private var search = ""

    var filtered: [InstalledApp] {
        search.isEmpty ? apps : apps.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick the apps DO IT should block")
                .font(.system(size: 20, weight: .bold))
            Text("When you open one of these, DO IT closes it and sends you to do your challenge first. Your choices save right away.")
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField("Search apps", text: $search)
                .textFieldStyle(.roundedBorder)
            List(filtered) { app in
                Toggle(isOn: Binding(
                    get: { store.blocked.contains(app.id) },
                    set: { on in
                        if on { store.blocked.insert(app.id) } else { store.blocked.remove(app.id) }
                    }
                )) {
                    HStack(spacing: 10) {
                        Image(nsImage: app.icon).resizable().frame(width: 24, height: 24)
                        Text(app.name)
                    }
                }
            }
            Text(store.blocked.isEmpty ? "No apps picked yet." : "Blocking \(store.blocked.count) app\(store.blocked.count == 1 ? "" : "s").")
                .font(.callout).bold()
        }
        .padding(20)
        .frame(width: 440, height: 560)
    }
}

// MARK: - The menu bar app

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var chooserWindow: NSWindow?
    var timer: Timer?
    var lastSentToSite = Date.distantPast
    var askedToQuit: [pid_t: Date] = [:]

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Listen for doit://break?minutes=N from the website.
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(handleURL(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        refreshMenu()

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(appEvent(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(appEvent(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.sweep() }

        // First run: start with the Mac, and ask which apps to block.
        if !UserDefaults.standard.bool(forKey: "setUpLogin") {
            UserDefaults.standard.set(true, forKey: "setUpLogin")
            try? SMAppService.mainApp.register()
        }
        if Store.shared.blocked.isEmpty { openChooser() }
    }

    // MARK: Blocking

    @objc func appEvent(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            block(app)
        }
    }

    func sweep() {
        for app in NSWorkspace.shared.runningApplications { block(app) }
        askedToQuit = askedToQuit.filter { pid, _ in NSRunningApplication(processIdentifier: pid) != nil }
        refreshMenu()
    }

    func block(_ app: NSRunningApplication) {
        let store = Store.shared
        guard let id = app.bundleIdentifier, store.blocked.contains(id), !store.onBreak, !app.isTerminated else { return }
        // Ask nicely first; if it is still open a few seconds later, close it for real.
        if let asked = askedToQuit[app.processIdentifier], Date().timeIntervalSince(asked) > 4 {
            app.forceTerminate()
        } else if askedToQuit[app.processIdentifier] == nil {
            askedToQuit[app.processIdentifier] = Date()
            app.terminate()
        }
        sendToSite()
    }

    func sendToSite() {
        guard Date().timeIntervalSince(lastSentToSite) > 15 else { return }
        lastSentToSite = Date()
        NSWorkspace.shared.open(siteURL)
    }

    // MARK: Breaks from the website

    @objc func handleURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let text = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let parts = URLComponents(string: text), parts.scheme == "doit" else { return }
        if parts.host == "break" {
            let asked = Double(parts.queryItems?.first(where: { $0.name == "minutes" })?.value ?? "") ?? 10
            let minutes = min(max(asked, 1), maxBreakMinutes)
            Store.shared.breakUntil = Date().addingTimeInterval(minutes * 60)
            askedToQuit.removeAll()
            refreshMenu()
        }
    }

    // MARK: Menu

    func refreshMenu() {
        let store = Store.shared
        statusItem.button?.title = store.onBreak ? "DO IT · \(store.minutesLeft)m" : "DO IT"

        let menu = NSMenu()
        let status: String
        if store.onBreak {
            status = "Break: \(store.minutesLeft) min left"
        } else if store.blocked.isEmpty {
            status = "No apps picked yet"
        } else {
            status = "Blocking \(store.blocked.count) app\(store.blocked.count == 1 ? "" : "s")"
        }
        let statusLine = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        menu.addItem(item("Pick apps to block…", #selector(openChooser)))
        menu.addItem(item("Open the DO IT website", #selector(openSite)))
        menu.addItem(.separator())
        let login = item("Open DO IT when my Mac starts", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(item("Quit DO IT", #selector(quit)))
        statusItem.menu = menu
    }

    func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc func openChooser() {
        if chooserWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 560),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "DO IT"
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: ChooserView(apps: installedApps()))
            window.center()
            chooserWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        chooserWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func openSite() { NSWorkspace.shared.open(siteURL) }

    @objc func toggleLogin() {
        if SMAppService.mainApp.status == .enabled {
            try? SMAppService.mainApp.unregister()
        } else {
            try? SMAppService.mainApp.register()
        }
        refreshMenu()
    }

    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
