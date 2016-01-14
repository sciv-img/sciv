import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var windows: [Imager] = []

    func applicationWillFinishLaunching(aNotification: NSNotification) {
        let mainMenu = NSMenu(title: "MainMenu")

        func addMenu(title: String, items: (String, Selector, String)...) {
            let item = mainMenu.addItemWithTitle(title, action: nil, keyEquivalent: "")!
            let menu = NSMenu(title: title)
            for item in items {
                menu.addItem(NSMenuItem(
                    title: item.0, action: item.1, keyEquivalent: item.2
                ))
            }
            mainMenu.setSubmenu(menu, forItem: item)
        }

        addMenu("Apple", items:
            ("Quit sciv", "terminate:", "q")
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

    func applicationShouldTerminateAfterLastWindowClosed(app: NSApplication) -> Bool {
        return true // TODO: Make this configurable
    }
}

let app = NSApplication.sharedApplication()
let delegate = AppDelegate()

app.setActivationPolicy(.Regular)
app.activateIgnoringOtherApps(true) // FIXME: Should not be necessary
app.delegate = delegate

app.run()
