import AppKit

class Key: Equatable {
    var modifiers: NSEventModifierFlags
    let key: Int

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

class Command: CustomStringConvertible, Hashable {
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

    var description: String {
        return self.keys.map({"\(UnicodeScalar($0.key))"}).joinWithSeparator("")
    }

    var hashValue: Int {
        return self.keys.map({"\($0.modifiers)\($0.key)"}).joinWithSeparator("").hashValue
    }
}

class Commander {
    var commands: [Command: Void -> Void] = [:]
    var regexCommands: [Regex: [String] -> Void] = [:]
    var current: Command = Command()

    func addCommand(callable: Void -> Void, _ keys: Key...) {
        self.commands[Command(keys)] = callable
    }

    func addCommand(callable: [String] -> Void, _ regex: String) {
        if let r = Regex(regex) {
            self.regexCommands[r] = callable
            return
        }
        // TODO: Return error to user
    }

    func addKey(key: Key) {
        self.current.addKey(key)
    }

    func reset() {
        self.current = Command()
    }

    func tryCall() -> Bool {
        if let command = self.commands[self.current] {
            command()
            self.current = Command()
            return true
        }
        for (regex, command) in self.regexCommands {
            let (match, captures) = regex.match(String(self.current))
            if match {
                if captures != nil {
                    command(captures!)
                    self.current = Command()
                }
                return true
            }
        }
        return false
    }
}

// MARK: Equatable

func ==(lhs: Key, rhs: Key) -> Bool {
    return lhs.key == rhs.key && lhs.modifiers == rhs.modifiers
}

func ==(lhs: Command, rhs: Command) -> Bool {
    return lhs.keys == rhs.keys
}
