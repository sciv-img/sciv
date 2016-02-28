import AppKit

class Key: Equatable {
    var modifiers: NSEventModifierFlags
    var key: Int

    convenience init(_ key: Character, _ modifiers: NSEventModifierFlags...) {
        let utf = String(key).utf16
        self.init(Int(utf[utf.startIndex]), modifiers)
    }

    convenience init(_ key: Int, _ modifiers: NSEventModifierFlags...) {
        self.init(key, modifiers)
    }

    init(_ key: Int, _ modifiers: [NSEventModifierFlags]) {
        self.key = key
        self.modifiers = NSEventModifierFlags()
        for modifier in modifiers {
            self.modifiers.insert(modifier)
        }
    }
}

func ==(lhs: Key, rhs: Key) -> Bool {
    return lhs.key == rhs.key && lhs.modifiers == rhs.modifiers
}

class Command: Hashable {
    var keys: [Key]

    init(_ keys: [Key]) {
        self.keys = keys
    }

    convenience init(_ keys: Key...) {
        self.init(keys)
    }

    func addKey(key: Key) {
        self.keys.append(key)
    }

    var hashValue: Int {
        get {
            return self.keys.map({"\($0.modifiers)\($0.key)"}).joinWithSeparator("").hashValue
        }
    }
}

func ==(lhs: Command, rhs: Command) -> Bool {
    return lhs.keys == rhs.keys
}

class Commander {
    var commands: [Command: Void -> Void] = [:]
    var current: Command = Command()

    func addCommand(callable: Void -> Void, _ keys: Key...) {
        self.commands[Command(keys)] = callable
    }

    func addKey(key: Key) {
        self.current.addKey(key)
    }

    func reset() {
        self.current = Command()
    }

    func getCallable() -> (Void -> Void)? {
        let callable = self.commands[self.current]
        if callable != nil {
            self.current = Command()
        }
        return callable
    }
}
