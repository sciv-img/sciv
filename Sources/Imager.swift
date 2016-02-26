import AppKit

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

    var modifier: Character?

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
        let modifiers = event.modifierFlags
        switch event.charactersIgnoringModifiers! {
        case " ":
            if modifiers.contains(.ShiftKeyMask) {
                self.previous()
            } else {
                self.next()
            }
        case "s":
            self.toggleTimer() // TODO: Move timer to separate object?
        case "f":
            self.toggleFullScreen()
        case "o":
            self.modifier = self.modifier != nil ? nil : "o"
            return
        case "n" where self.modifier == "o":
            self.order(.NameAsc)
        case "N" where self.modifier == "o":
            self.order(.NameDesc)
        case "m" where self.modifier == "o":
            self.order(.MtimeAsc)
        case "M" where self.modifier == "o":
            self.order(.MtimeDesc)
        case "r" where self.modifier == "o":
            self.order(.Random)
        case "g":
            if self.modifier == "g" {
                self.first()
            } else {
                self.modifier = "g"
                return
            }
        case "G":
            self.last()
        case "q":
            self.close()
        default:
            super.keyDown(event)
        }
        if self.modifier != nil {
            self.modifier = nil
        }
    }

    func windowDidBecomeKey(_: NSNotification) {
        self.statusView.active = true
    }

    func windowDidResignKey(_: NSNotification) {
        self.statusView.active = false
    }
}
