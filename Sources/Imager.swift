import AppKit
import PathKit

class Imager: NSWindow, NSWindowDelegate {
    var files: [File]
    var i: Int {
        didSet {
            self.show()
        }
    }

    var imageView: NSImageView
    var statusView: StatusView
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

    var commander: Commander

    required init?(coder: NSCoder) {
        fatalError("Not implemented!")
    }

    init() {
        self.files = []
        self.i = 0
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

        self.commander.addCommand(self.next, Key(" "))
        self.commander.addCommand(self.previous, Key(" ", .ShiftKeyMask))
        self.commander.addCommand(self.first, Key("g"), Key("g"))
        self.commander.addCommand(self.last, Key("G", .ShiftKeyMask))
        self.commander.addCommand({self.order(.NameAsc)}, Key("o"), Key("n"))
        self.commander.addCommand({self.order(.NameDesc)}, Key("o"), Key("N", .ShiftKeyMask))
        self.commander.addCommand({self.order(.MtimeAsc)}, Key("o"), Key("m"))
        self.commander.addCommand({self.order(.MtimeDesc)}, Key("o"), Key("M", .ShiftKeyMask))
        self.commander.addCommand({self.order(.Random)}, Key("o"), Key("r"))
        self.commander.addCommand(self.toggleTimer, Key("s"))
        self.commander.addCommand(self.toggleFullScreen, Key("f"))
        self.commander.addCommand(self.close, Key("q"))
    }

    func setup(dirOrFile: String) {
        // TODO: Handle errors
        var dir: Path
        let dirOrFilePath = Path(dirOrFile)
        if dirOrFilePath.isFile {
            // TODO: Move this (done nicely) into PathKit
            let components = dirOrFilePath.components
            dir = Path(components[0..<components.count - 1].joinWithSeparator(Path.separator))
        } else {
            dir = dirOrFilePath
        }
        for path in try! dir.children() {  // FIXME: Safety
            let ext = path.`extension`
            if ext == nil {
                continue
            }
            let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext!, nil)
            if !UTTypeConformsTo(uti!.takeRetainedValue(), kUTTypeImage) { // FIXME: Safety
                continue
            }
            self.files.append(File(path))
        }

        self.statusView.numberOfFiles = self.files.count
        self.i = self.files.indexOf({$0.path == dirOrFilePath}) ?? 0
    }

    func show() {
        let filepath = self.files[self.i].path
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
            number: self.i + 1,
            name: filepath.lastComponent,
            size: size
        )
    }

    func next() {
        if self.i + 1 >= self.files.count {
            return
        }
        self.i += 1
    }

    func previous() {
        if self.i <= 0 {
            return
        }
        self.i -= 1
    }

    func first() {
        self.i = 0
    }

    func last() {
        self.i = self.files.count < 2 ? 0 : self.files.count - 1
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

    func toggleFullScreen() {
        self.isFullScreen = !self.isFullScreen

        if self.isFullScreen {
            self.previousBackgroundColor = self.backgroundColor
            self.previousFrame = self.frame

            NSMenu.setMenuBarVisible(false)
            self.styleMask = NSBorderlessWindowMask
            self.setFrame(NSScreen.mainScreen()!.frame, display: true, animate: true) // FIXME: Safety
            self.backgroundColor = NSColor.blackColor()
        } else {
            NSMenu.setMenuBarVisible(true)
            self.styleMask = self.defaultMask
            self.title = String(self.files[self.i].path)
            self.setFrame(self.previousFrame!, display: true, animate: true)
            self.backgroundColor = self.previousBackgroundColor!
        }
    }

    func order(type: OrderType) {
        let filepath = self.files[self.i].path
        switch type {
        case .NameAsc:
            self.files.sortInPlace({$0.path < $1.path})
        case .NameDesc:
            self.files.sortInPlace({$0.path > $1.path})
        case .MtimeAsc:
            self.files.sortInPlace({$0.mtime < $1.mtime})
        case .MtimeDesc:
            self.files.sortInPlace({$0.mtime > $1.mtime})
        case .Random:
            self.files.shuffleInPlace()
        }
        self.i = self.files.indexOf({$0.path == filepath})!
    }

    override func keyDown(event: NSEvent) {
        // TODO: Also make "stop point" configurable
        let keys = event.charactersIgnoringModifiers!.utf16
        let modifiers = event.modifierFlags.intersect(.DeviceIndependentModifierFlagsMask)
        let key = Int(keys[keys.startIndex])

        if key == 27 { // Escape
            self.commander.reset()
            return
        }

        self.commander.addKey(Key(key, modifiers))
        let callable = self.commander.getCallable()
        if callable != nil {
            callable!()
            return
        }
        super.keyDown(event)
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
