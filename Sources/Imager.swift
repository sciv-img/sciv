import AppKit
import PathKit

class Imager: NSWindow, NSWindowDelegate {
    var files: Files!

    let imageView: NSImageView
    let statusView: StatusView
    var alertView: AlertView!
    let defaultMask: NSWindowStyleMask = [
        .closable,
        .miniaturizable,
        .resizable,
        .titled,
    ]

    var isFullScreen: Bool
    var previousBackgroundColor: NSColor?
    var previousFrame: NSRect?

    var timer: Timer?

    let commander: Commander

    init() {
        self.imageView = NSImageView(frame: NSMakeRect(0, 22, 640, 458))
        self.imageView.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        self.statusView = StatusView(frame: NSMakeRect(0, 0, 640, 22))
        self.statusView.autoresizingMask = [.viewWidthSizable]
        self.isFullScreen = false

        self.commander = Commander()

        let rect = NSMakeRect(200, 200, 640, 480)
        super.init(
            contentRect: rect,
            styleMask: self.defaultMask,
            backing: .buffered,
            defer: true
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
        self.commander.addCommand(self.alertHide, Key("a"), Key("h"))
    }

    func alertShow(msg: String) {
        if self.alertView != nil {
            self.alertHide()
        }

        let view = self.contentView!

        self.alertView = AlertView(
            frame: NSMakeRect(0, view.frame.height - 30, view.frame.width, 30),
            message: msg,
            callback: self.alertHide
        )
        view.addSubview(self.alertView)

        let iframe = self.imageView.frame
        self.imageView.setFrameSize(NSMakeSize(iframe.width, iframe.height - 30))
    }

    func alertHide() {
        if self.alertView == nil {
            return
        }

        self.alertView.removeFromSuperview()
        self.alertView = nil
        let iframe = self.imageView.frame
        self.imageView.setFrameSize(NSMakeSize(iframe.width, iframe.height + 30))
    }

    func setup(_ dirOrFile: String) {
        self.files = Files(dirOrFile, self.show)
        self.show()
    }

    func show() {
        self.alertHide()

        let filepath = self.files.current
        let filepathStr = String(describing: filepath)
        var size = NSSize()

        self.title = filepathStr
        self.statusView.currentFile = FileInfo(
            number: self.files.i + 1,
            name: filepath.lastComponent,
            size: size
        )
        self.statusView.numberOfFiles = self.files.count

        let maybeImage = NSImage(byReferencingFile: filepathStr)
        if maybeImage == nil {
            self.alertShow("Cannot open image file: NSImage returned nil")
            return
        }
        let image = maybeImage!
        var square = 0
        for rep in image.representations {
            let maybeSquare = rep.pixelsWide * rep.pixelsHigh
            if maybeSquare > square {
                square = maybeSquare
                size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
            }
        }
        image.size = size
        self.imageView.image = image
        self.statusView.currentFile.size = size
    }

    func next(_ args: [String]) {
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
        self.timer = Timer.scheduledTimer(
            timeInterval: time ?? 2,
            target: self, selector: #selector(Imager.next as (Imager) -> () -> ()),
            userInfo: nil, repeats: true
        )
    }

    func toggleFullScreen() {
        self.isFullScreen = !self.isFullScreen

        if self.isFullScreen {
            guard let screen = NSScreen.main() else {
                self.isFullScreen = false
                return
            }

            self.previousBackgroundColor = self.backgroundColor
            self.previousFrame = self.frame

            NSMenu.setMenuBarVisible(false)
            self.styleMask = NSBorderlessWindowMask
            self.setFrame(screen.frame, display: true, animate: false)
            self.backgroundColor = NSColor.black
            return
        }
        NSMenu.setMenuBarVisible(true)
        self.styleMask = self.defaultMask
        self.title = String(describing: self.files.current)
        self.setFrame(self.previousFrame!, display: true, animate: false)
        self.backgroundColor = self.previousBackgroundColor!
    }

    func runCommand(args: [String]) {
        let supDirs = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )
        var runFile: String?
        for dir in supDirs {
            if dir.path == "" {
                continue
            }
            let maybeRunFile = Path(dir.path) + "sciv" + "run.sh"
            if maybeRunFile.exists {
                runFile = String(describing: maybeRunFile)
            }
        }
        if runFile == nil {
            self.alertShow("Could not find the run.sh file in any known location")
            return
        }

        let pipe = Pipe()
        let task = Process()
        task.launchPath = runFile!
        task.arguments = args
        task.standardInput = pipe
        task.launch()
        let handle = pipe.fileHandleForWriting
        let path = String(describing: self.files.current)
        handle.write(path.data(using: String.Encoding.utf8)!) // FIXME: Check error
        handle.closeFile()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            self.alertShow("Command returned with exit code `\(task.terminationStatus)`")
        }
    }

    override func keyDown(with event: NSEvent) {
        // TODO: Also make "stop point" configurable
        defer {
            self.statusView.command = String(describing: self.commander.current)
        }

        let keys = event.charactersIgnoringModifiers!.utf16
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = Int(keys[keys.startIndex])

        if key == 27 { // Escape
            self.commander.reset()
            return
        }

        self.commander.addKey(Key(key, modifiers))
        self.statusView.command = String(describing: self.commander.current)
        if !self.commander.tryCall() {
            super.keyDown(with: event)
        }
    }

    func windowDidBecomeKey(_: Notification) {
        self.statusView.active = true
        NSMenu.setMenuBarVisible(!self.isFullScreen)
    }

    func windowDidResignKey(_: Notification) {
        self.statusView.active = false
    }

    func windowDidResize(_: Notification) {
        if self.alertView != nil {
            let frame = self.contentView!.frame
            self.alertView.setFrameOrigin(NSMakePoint(0, frame.height - 30))
        }
    }

    override var canBecomeKey: Bool {
        get {
            return true
        }
    }
}
