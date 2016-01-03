import AppKit
import PathKit

class Imager: NSWindow {
    var files: [Path]
    var i: Int
    var visited: [Int]

    var view: NSImageView

    var timer: NSTimer?

    required init?(coder: NSCoder) {
        fatalError("Not implemented!")
    }

    init() {
        self.files = []
        self.i = 0
        self.visited = []
        let rect = NSMakeRect(200, 200, 640, 480)
        self.view = NSImageView(frame: rect)
        super.init(
            contentRect: rect,
            styleMask: NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask | NSTitledWindowMask,
            backing: .Buffered,
            defer: true
        )
    }

    func setup(dirOrFile: String) {
        // TODO: Handle errors
        var dir: Path
        let dirOrFilePath = Path(dirOrFile)
        if dirOrFilePath.isFile {
            let components = dirOrFilePath.components
            dir = Path(components[0..<components.count - 1].joinWithSeparator(Path.separator))
        } else {
            dir = dirOrFilePath
        }
        for path in try! dir.children() {  // FIXME: Safety
            Swift.print(path)
            let ext = path.`extension`
            if ext == nil {
                continue
            }
            let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext!, nil)
            if !UTTypeConformsTo(uti!.takeRetainedValue(), kUTTypeImage) { // FIXME: Safety
                continue
            }
            self.files.append(path)
        }

        self.contentView = self.view
    }

    func show() {
        let filename = self.files[self.i]
        let image = NSImage(byReferencingFile: String(Path("/Users/kenji/Pictures/jb") + filename))
        self.view.image = image
    }

    func next() {
        self.i += 1
        self.show()
    }

    func toggleTimer() {
        if self.timer == nil {
            self.timer = NSTimer.scheduledTimerWithTimeInterval(
                2, target: self, selector: "next", userInfo: nil, repeats: true
            )
            return
        }
        self.timer!.invalidate()
        self.timer = nil
    }

    override func keyDown(event: NSEvent) {
        let modifiers = event.modifierFlags
        switch event.charactersIgnoringModifiers! {
        case " ":
            if modifiers.contains(.ShiftKeyMask) && self.i > 0 {
                self.i -= 1
            } else if self.i < self.files.count - 1 {
                self.i += 1
            }
        case "r":
            // TODO: Improve this routine, it seems weird
            // TODO: Also make "stop point" optional
            if self.visited.count == self.files.count {
                return
            }
            repeat {
                self.i = Int(arc4random_uniform(UInt32(self.files.count) - 1))
            } while self.visited.contains(self.i)
            self.visited.append(self.i)
        case "s":
            self.toggleTimer() // TODO: Move timer to separate object?
        default:
            super.keyDown(event)
            return
        }
        self.show()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: Imager

    override init() {
        self.window = Imager()
        super.init()
    }

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
        self.window.setup(openFile)
        return true
    }

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // if Process.arguments.count >= 2 {
        //     self.window.setup(Process.arguments[1])
        // }
        self.window.show()
        self.window.makeKeyAndOrderFront(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(app: NSApplication) -> Bool {
        return true
    }
}

let app = NSApplication.sharedApplication()
let delegate = AppDelegate()

app.setActivationPolicy(.Regular)
app.activateIgnoringOtherApps(true) // FIXME: Should not be necessary
app.delegate = delegate

app.run()
