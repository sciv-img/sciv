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
    internal var _command = ""
    var command: String {
        set {
            if newValue.characters.count > 3 {
                let end = newValue.endIndex
                self._command = newValue[end.advancedBy(-3)..<end]
            } else {
                self._command = newValue
            }
            self.needsDisplay = true
        }
        get {
            return self._command
        }
    }

    var active = true {
        didSet {
            self.needsDisplay = true
        }
    }

    override func drawRect(dirtyRect: NSRect) {
        let w = dirtyRect.width
        let h = dirtyRect.height

        let frame = NSMakeRect(0, 21, w, 1)
        NSColor.windowFrameColor().setFill()
        NSRectFill(frame)

        let colors = self.active ? [
            NSColor(deviceWhite: 180 / 0xff, alpha: 1),
            NSColor(deviceWhite: 210 / 0xff, alpha: 1)
        ] : [
            NSColor(deviceWhite: 225 / 0xff, alpha: 1),
            NSColor(deviceWhite: 235 / 0xff, alpha: 1)
        ]
        let bg = NSMakeRect(0, 0, w, h - 1)
        NSGradient(colors: colors)!.drawInRect(bg, angle: 90)

        let status = "\(self.currentFile.number)/\(self.numberOfFiles) | \(Int(self.currentFile.size.width))x\(Int(self.currentFile.size.height)) | \(self.currentFile.name)"
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .ByTruncatingTail
        status.drawInRect(
            NSMakeRect(6, 3, w - 41, h - 7),
            withAttributes: [NSParagraphStyleAttributeName: paragraph]
        )

        " | \(self.command)".drawInRect(
            NSMakeRect(w - 36, 3, 36, h - 7), withAttributes: nil
        )
    }
}
