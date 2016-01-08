import AppKit

class StatusView: NSView {
    var currentFile = 0 {
        didSet {
            self.needsDisplay = true
        }
    }
    var numberOfFiles = 0 {
        didSet {
            self.needsDisplay = true
        }
    }

    override func drawRect(dirtyRect: NSRect) {
        let frame = NSMakeRect(0, 21, dirtyRect.width, 1)
        NSColor.windowFrameColor().setFill()
        NSRectFill(frame)

        let colors: [NSColor]
        if NSApp.active {
            colors = [
                NSColor(deviceWhite: 180 / 0xff, alpha: 1),
                NSColor(deviceWhite: 210 / 0xff, alpha: 1)
            ]
        } else {
            colors = [
                NSColor(deviceWhite: 225 / 0xff, alpha: 1),
                NSColor(deviceWhite: 235 / 0xff, alpha: 1)
            ]
        }
        let bg = NSMakeRect(0, 0, dirtyRect.width, dirtyRect.height - 1)
        NSGradient(colors: colors)!.drawInRect(bg, angle: 90)
        let status = "\(self.currentFile)/\(self.numberOfFiles)"
        status.drawAtPoint(NSPoint(x: 6, y: 3), withAttributes: nil)
    }
}
