import AppKit

typealias FileInfo = (number: Int, name: String, size: NSSize)

class StatusView: NSView {
    var currentFile = FileInfo(0, "", NSSize()) {
        didSet {
            self.needsDisplay = true
        }
    }
    var numberOfFiles = 0 {
        didSet {
            self.needsDisplay = true
        }
    }
    private var commandI = ""
    var command: String {
        set {
            if newValue.count > 3 {
                let end = newValue.endIndex
                self.commandI = String(newValue[newValue.index(end, offsetBy: -3)..<end])
            } else {
                self.commandI = newValue
            }
            self.needsDisplay = true
        }
        get {
            return self.commandI
        }
    }

    var active = true {
        didSet {
            self.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let w = dirtyRect.width
        let h = dirtyRect.height

        let frame = NSRect(x: 0, y: 21, width: w, height: 1)
        NSColor.windowFrameColor.setFill()
        frame.fill()

        let colors = self.active ? [
            NSColor(deviceWhite: 180 / 0xff, alpha: 1),
            NSColor(deviceWhite: 210 / 0xff, alpha: 1)
        ] : [
            NSColor(deviceWhite: 225 / 0xff, alpha: 1),
            NSColor(deviceWhite: 235 / 0xff, alpha: 1)
        ]
        let bg = NSRect(x: 0, y: 0, width: w, height: h - 1)
        NSGradient(colors: colors)!.draw(in: bg, angle: 90)

        let status = "\(self.currentFile.number)/\(self.numberOfFiles) | \(Int(self.currentFile.size.width))x\(Int(self.currentFile.size.height)) | \(self.currentFile.name)"
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        status.draw(
            in: NSRect(x: 6, y: 3, width: w - 41, height: h - 7),
            withAttributes: [.paragraphStyle: paragraph]
        )

        " | \(self.command)".draw(
            in: NSRect(x: w - 36, y: 3, width: 36, height: h - 7), withAttributes: nil
        )
    }
}
