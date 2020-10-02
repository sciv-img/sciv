import AppKit
import PathKit
import Cwebp

extension NSImage {
    convenience init?(_ filepath: Path) {
        let filepathStr = filepath.string

        if filepath.extension == "webp" {
            guard let data = NSData(contentsOfFile: filepathStr) else {
                return nil
            }

            var w32: Int32 = 0
            var h32: Int32 = 0

            if WebPGetInfo(data.bytes.assumingMemoryBound(to: UInt8.self), data.length, &w32, &h32) == 0 {
                return nil
            }

            guard let bytes = WebPDecodeRGBA(data.bytes.assumingMemoryBound(to: UInt8.self), data.length, &w32, &h32) else {
                return nil
            }

            let width = Int(w32)
            let height = Int(h32)

            let maybeProvider = CGDataProvider(
                dataInfo: nil,
                data: UnsafeRawPointer(bytes),
                size: width * height * 4,
                releaseData: { (_: UnsafeMutableRawPointer?, data: UnsafeRawPointer, _: Int) -> Void in
                    free(UnsafeMutableRawPointer(mutating: data))
                }
            )
            guard let provider = maybeProvider else {
                return nil
            }

            let maybeImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: CGColorRenderingIntent.defaultIntent
            )
            guard let image = maybeImage else {
                return nil
            }

            self.init(cgImage: image, size: NSSize(width: width, height: height))
        } else {
            self.init(byReferencingFile: filepathStr)
        }
    }
}

class Imager: NSWindow, NSWindowDelegate {
    var files: Files!

    let imageView: NSImageView
    let statusView: StatusView
    var alertView: AlertView!
    let defaultMask: NSWindow.StyleMask = [
        .closable,
        .miniaturizable,
        .resizable,
        .titled
    ]

    var isFullScreen: Bool
    var previousBackgroundColor: NSColor?
    var previousFrame: NSRect?

    var timer: Timer?

    let commander: Commander

    init() {
        self.imageView = NSImageView(frame: NSRect(x: 0, y: 22, width: 640, height: 458))
        self.imageView.autoresizingMask = [.width, .height]
        self.statusView = StatusView(frame: NSRect(x: 0, y: 0, width: 640, height: 22))
        self.statusView.autoresizingMask = [.width]
        self.isFullScreen = false

        self.commander = Commander()

        let rect = NSRect(x: 200, y: 200, width: 640, height: 480)
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
        self.commander.addCommand(self.previous, "^([0-9]*)", Key(" ", .shift))
        self.commander.addCommand(self.first, Key("g"), Key("g"))
        self.commander.addCommand(self.last, Key("G", .shift))
        self.commander.addCommand({self.files.o = .nameAsc}, Key("o"), Key("n"))
        self.commander.addCommand({self.files.o = .nameDesc}, Key("o"), Key("N", .shift))
        self.commander.addCommand({self.files.o = .mtimeAsc}, Key("o"), Key("m"))
        self.commander.addCommand({self.files.o = .mtimeDesc}, Key("o"), Key("M", .shift))
        self.commander.addCommand({self.files.o = .random}, Key("o"), Key("r"))
        self.commander.addCommand(self.toggleTimer, "^([0-9]*)s")
        self.commander.addCommand(self.toggleFullScreen, Key("f"))
        self.commander.addCommand(self.runCommand, "c(.)")
        self.commander.addCommand(self.close, Key("q"))
        self.commander.addCommand(self.alertHide, Key("a"), Key("h"))
    }

    func alertShow(_ msg: String) {
        if self.alertView != nil {
            self.alertHide()
        }

        let view = self.contentView!

        self.alertView = AlertView(
            frame: NSRect(x: 0, y: view.frame.height - 30, width: view.frame.width, height: 30),
            message: msg,
            callback: self.alertHide
        )
        view.addSubview(self.alertView)

        let iframe = self.imageView.frame
        self.imageView.setFrameSize(NSSize(width: iframe.width, height: iframe.height - 30))
    }

    func alertHide() {
        if self.alertView == nil {
            return
        }

        self.alertView.removeFromSuperview()
        self.alertView = nil
        let iframe = self.imageView.frame
        self.imageView.setFrameSize(NSSize(width: iframe.width, height: iframe.height + 30))
    }

    func setup(_ dirOrFile: String) {
        self.files = Files(dirOrFile, self.show)
        self.show()
    }

    func show() {
        self.alertHide()

        guard let filepath = self.files.current else {
            self.close()
            return
        }

        var size = NSSize()

        self.title = filepath.string
        self.statusView.currentFile = FileInfo(
            number: self.files.i + 1,
            name: filepath.lastComponent,
            size: size
        )
        self.statusView.numberOfFiles = self.files.count

        guard let image = NSImage(filepath) else {
            self.alertShow("Cannot open image file: NSImage returned nil")
            return
        }
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

    @objc
    func next() {
        self.next(["1"])
    }

    func previous(_ args: [String]) {
        let delta = Int(args[0]) ?? 1
        if self.files.i - delta < 0 {
            return
        }
        self.files.i -= delta
    }

    @objc
    func previous() {
        self.previous(["1"])
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
            target: self, selector: #selector(Imager.next as (Imager) -> () -> Void),
            userInfo: nil, repeats: true
        )
    }

    func toggleFullScreen() {
        self.isFullScreen = !self.isFullScreen

        if self.isFullScreen {
            guard let screen = NSScreen.main else {
                self.isFullScreen = false
                return
            }

            self.previousBackgroundColor = self.backgroundColor
            self.previousFrame = self.frame

            NSMenu.setMenuBarVisible(false)
            self.styleMask = .borderless
            self.setFrame(screen.frame, display: true, animate: false)
            self.backgroundColor = NSColor.black
            return
        }
        NSMenu.setMenuBarVisible(true)
        self.styleMask = self.defaultMask
        self.title = self.files.current?.string ?? ""
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
                runFile = maybeRunFile.string
            }
        }
        if runFile == nil {
            self.alertShow("Could not find the run.sh file in any known location")
            return
        }
        guard let file = self.files.current else {
            self.alertShow("There is no current file")
            return
        }

        let pipe = Pipe()
        let task = Process()
        task.launchPath = runFile!
        task.arguments = args
        task.standardInput = pipe
        task.launch()
        let handle = pipe.fileHandleForWriting
        if let cstr = file.string.data(using: String.Encoding.utf8) {
            handle.write(cstr)
        } else {
            self.alertShow("Failed filename encoding")
        }
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

    override var canBecomeKey: Bool {
        return true
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
            self.alertView.setFrameOrigin(NSPoint(x: 0, y: frame.height - 30))
        }
    }

    func windowWillClose(_: Notification) {
        NSMenu.setMenuBarVisible(true)
    }
}
