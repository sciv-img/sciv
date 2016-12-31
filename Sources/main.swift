import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var windows: [Imager] = []

    func open() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.resolvesAliases = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == NSFileHandlingPanelOKButton {
            for url in panel.urls {
                if url.path == "" {
                    continue
                }
                _ = self.application(NSApp, openFile: url.path)
            }
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        let mainMenu = NSMenu(title: "MainMenu")

        func addMenu(title: String, items: (String, Selector, String)...) {
            let item = mainMenu.addItem(withTitle: title, action: nil, keyEquivalent: "")
            let menu = NSMenu(title: title)
            for item in items {
                menu.addItem(NSMenuItem(
                    title: item.0, action: item.1, keyEquivalent: item.2
                ))
            }
            mainMenu.setSubmenu(menu, for: item)
        }

        addMenu(title: "Apple", items:
            ("Quit sciv", #selector(NSApp.terminate), "q")
        )
        addMenu(title: "File", items:
            ("Open...", #selector(AppDelegate.open), "o")
        )
        NSApp.mainMenu = mainMenu
    }

    func application(_: NSApplication, openFile: String) -> Bool {
        let imager = Imager()
        imager.setup(openFile)
        self.windows.append(imager)
        imager.makeKeyAndOrderFront(self)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        return true // TODO: Make this configurable
    }
}

let app = NSApplication.shared()
let delegate = AppDelegate()

app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true) // FIXME: Should not be necessary
app.delegate = delegate

app.run()
