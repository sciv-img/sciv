import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var windows: [Imager] = []

    func applicationWillFinishLaunching(aNotification: NSNotification) {
        let tree = [
            "Apple": [
                NSMenuItem(title: "Quit", action: "terminate:", keyEquivalent: "q")
            ]
        ]
        let mainMenu = NSMenu(title: "MainMenu")
        for (title, items) in tree {
            let menu = NSMenu(title: title)
            if let item = mainMenu.addItemWithTitle(title, action: nil, keyEquivalent: "") {
                mainMenu.setSubmenu(menu, forItem: item)
                for item in items {
                    menu.addItem(item)
                }
            }
        }
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
