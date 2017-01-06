import AppKit

class AlertView: NSView {
    private var callback: ()->()

    private var message: String

    required init?(coder: NSCoder) {
        fatalError("Not implemented!")
    }

    init(frame: NSRect, message: String, callback: @escaping ()->()) {
        self.message = message
        self.callback = callback

        super.init(frame: frame)

        self.autoresizingMask = [.viewWidthSizable]
    }

    override func draw(_ dirtyRect: NSRect) {
        let w = dirtyRect.width
        let h = dirtyRect.height

        NSGradient(colors: [
            NSColor(deviceRed: 254 / 0xff, green: 239 / 0xff, blue: 174 / 0xff, alpha: 1),
            NSColor(deviceRed: 250 / 0xff, green: 230 / 0xff, blue: 146 / 0xff, alpha: 1)
        ])!.draw(in: dirtyRect, angle: 90)

        self.message.draw(
            in: NSMakeRect(6, 2, w - 6, h - 8),
            withAttributes: nil
        )

        NSColor.windowFrameColor.setFill()
        NSRectFill(NSMakeRect(0, 0, w, 1))
    }
}