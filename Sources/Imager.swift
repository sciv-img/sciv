import AppKit
import PathKit

class Imager: NSWindow, NSWindowDelegate {
    var files: Files!

    let imageView: NSImageView
    let statusView: StatusView
    let defaultMask = (
        NSClosableWindowMask |
        NSMiniaturizableWindowMask |
        NSResizableWindowMask |
        NSTitledWindowMask
    )

    var isFullScreen: Bool
    var previousBackgroundColor: NSColor?
    var previousFrame: NSRect?

    var timer: NSTimer?

    let commander: Commander

    required init?(coder: NSCoder) {
        fatalError("Not implemented!")
    }

    init() {
        self.imageView = NSImageView(frame: NSMakeRect(0, 22, 640, 458))
        self.imageView.autoresizingMask = [.ViewWidthSizable, .ViewHeightSizable]
        self.statusView = StatusView(frame: NSMakeRect(0, 0, 640, 22))
        self.statusView.autoresizingMask = [.ViewWidthSizable]
        self.isFullScreen = false

        self.commander = Commander()

        let rect = NSMakeRect(200, 200, 640, 480)
        super.init(
            contentRect: rect,
            styleMask: self.defaultMask,
            backing: .Buffered,
            `defer`: true
        )
        let view = NSView(frame: rect)
        self.contentView = view
        view.addSubview(self.imageView)
        view.addSubview(self.statusView)
        self.delegate = self

        self.commander.addCommand(self.next, "^([0-9]*) ")
        self.commander.addCommand(self.previous, Key(" ", .ShiftKeyMask))
        self.commander.addCommand(self.first, Key("g"), Key("g"))
        self.commander.addCommand(self.last, Key("G", .ShiftKeyMask))
        self.commander.addCommand({self.files.o = .NameAsc}, Key("o"), Key("n"))
        self.commander.addCommand({self.files.o = .NameDesc}, Key("o"), Key("N", .ShiftKeyMask))
        self.commander.addCommand({self.files.o = .MtimeAsc}, Key("o"), Key("m"))
        self.commander.addCommand({self.files.o = .MtimeDesc}, Key("o"), Key("M", .ShiftKeyMask))
        self.commander.addCommand({self.files.o = .Random}, Key("o"), Key("r"))
        self.commander.addCommand(self.toggleTimer, "^([0-9]*)s")
        self.commander.addCommand(self.toggleFullScreen, Key("f"))
        self.commander.addCommand(self.runCommand, "c(.)")
        self.commander.addCommand(self.close, Key("q"))
    }

    func setup(dirOrFile: String) {
        self.files = Files(dirOrFile, self.show)
        self.show()
    }

    func show() {
        let filepath = self.files.current
        let filepathStr = String(filepath)
        self.title = filepathStr
        let maybeImage = NSImage(byReferencingFile: filepathStr)
        if maybeImage == nil {
            return // TODO: Show error to user
        }
        let image = maybeImage!
        var square = 0, size = NSSize()
        for rep in image.representations {
            let maybeSquare = rep.pixelsWide * rep.pixelsHigh
            if maybeSquare > square {
                square = maybeSquare
                size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
            }
        }
        image.size = size
        self.imageView.image = image
        self.statusView.currentFile = FileInfo(
            number: self.files.i + 1,
            name: filepath.lastComponent,
            size: size
        )
        self.statusView.numberOfFiles = self.files.count
    }

    func next(args: [String]) {
        let delta = Int(args[0]) ?? 1
        if self.files.i + delta >= self.files.count {
            return
        }
        self.files.i += delta
    }

    func next() {
        self.next(["1"])
    }

    func previous() {
        if self.files.i <= 0 {
            return
        }
        self.files.i -= 1
    }

    func first() {
        self.files.i = 0
    }

    func last() {
        self.files.i = self.files.count < 2 ? 0 : self.files.count - 1
    }

    func toggleTimer(args: [String]) {
        let time = Double(args[0])

        if self.timer != nil {
            self.timer!.invalidate()
            self.timer = nil
            if time == nil {
                return
            }
        }
        self.timer = NSTimer.scheduledTimerWithTimeInterval(
            time ?? 2,
            target: self, selector: "next",
            userInfo: nil, repeats: true
        )
    }

    func toggleFullScreen() {
        self.isFullScreen = !self.isFullScreen

        if self.isFullScreen {
            guard let screen = NSScreen.mainScreen() else {
                self.isFullScreen = false
                return
            }

            self.previousBackgroundColor = self.backgroundColor
            self.previousFrame = self.frame

            NSMenu.setMenuBarVisible(false)
            self.styleMask = NSBorderlessWindowMask
            self.setFrame(screen.frame, display: true, animate: false)
            self.backgroundColor = NSColor.blackColor()
            return
        }
        NSMenu.setMenuBarVisible(true)
        self.styleMask = self.defaultMask
        self.title = String(self.files.current)
        self.setFrame(self.previousFrame!, display: true, animate: false)
        self.backgroundColor = self.previousBackgroundColor!
    }

    func runCommand(args: [String]) {
        let supDirs = NSFileManager.defaultManager().URLsForDirectory(
            .ApplicationSupportDirectory, inDomains:.UserDomainMask
        )
        var runFile: String?
        for dir in supDirs {
            if dir.path == nil {
                continue
            }
            let maybeRunFile = Path(dir.path!) + "sciv" + "run.sh"
            if maybeRunFile.exists {
                runFile = String(maybeRunFile)
            }
        }
        if runFile == nil {
            return // TODO: Tell user
        }

        let pipe = NSPipe()
        let task = NSTask()
        task.launchPath = runFile!
        task.arguments = args
        task.standardInput = pipe
        task.launch()
        let handle = pipe.fileHandleForWriting
        let path = String(self.files.current)
        handle.writeData(path.dataUsingEncoding(NSUTF8StringEncoding)!) // FIXME: Check error
        handle.closeFile()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            // TODO: Tell user
        }
    }

    override func keyDown(event: NSEvent) {
        // TODO: Also make "stop point" configurable
        defer {
            self.statusView.command = String(self.commander.current)
        }

        let keys = event.charactersIgnoringModifiers!.utf16
        let modifiers = event.modifierFlags.intersect(.DeviceIndependentModifierFlagsMask)
        let key = Int(keys[keys.startIndex])

        if key == 27 { // Escape
            self.commander.reset()
            return
        }

        self.commander.addKey(Key(key, modifiers))
        self.statusView.command = String(self.commander.current)
        if !self.commander.tryCall() {
            super.keyDown(event)
        }
    }

    func windowDidBecomeKey(_: NSNotification) {
        self.statusView.active = true
        NSMenu.setMenuBarVisible(!self.isFullScreen)
    }

    func windowDidResignKey(_: NSNotification) {
        self.statusView.active = false
    }

    override var canBecomeKeyWindow: Bool {
        get {
            return true
        }
    }
}
