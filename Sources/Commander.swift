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

class Command: Comparable, CustomStringConvertible, Hashable {
    var keys: [Key]

    init(_ keys: [Key]) {
        self.keys = keys
    }

    convenience init(_ keys: Key...) {
        self.init(keys)
    }

    func addKey(_ key: Key) {
        self.keys.append(key)
    }

    var description: String {
        return self.keys.map({"\(UnicodeScalar($0.key)!)"}).joined(separator: "")
    }

    var hashValue: Int {
        return self.keys.map({"\($0.modifiers)\($0.key)"}).joined(separator: "").hashValue
    }
}

// TODO: Regex with ModifierKeys
class Commander {
    var commands: [Command: (Void) -> Void] = [:]
    var regexCommands: [Regex: ([String]) -> Void] = [:]
    var current: Command = Command()

    func addCommand(_ callable: @escaping (Void) -> Void, _ keys: Key...) {
        self.commands[Command(keys)] = callable
    }

    func addCommand(_ callable: @escaping ([String]) -> Void, _ regex: String) {
        if let r = Regex(regex) {
            self.regexCommands[r] = callable
            return
        }
        // TODO: Return error to user
    }

    func addKey(_ key: Key) {
        self.current.addKey(key)
    }

    func reset() {
        self.current = Command()
    }

    func tryCall() -> Bool {
        // TODO: Refactor
        // TODO: There may be situation where `commands` is a partial
        // match, but `regex` is full match, it should be supported.
        for (command, callable) in self.commands {
            if self.current == command {
                callable()
                self.current = Command()
                return true
            }
            if self.current < command {
                return true
            }
        }
        for (regex, callable) in self.regexCommands {
            let (match, captures) = regex.match(String(describing: self.current))
            if match {
                if captures != nil {
                    callable(captures!)
                    self.current = Command()
                }
                return true
            }
        }
        self.current = Command()
        return false
    }
}

// MARK: Comparable

func <(lhs: Command, rhs: Command) -> Bool {
    if lhs.keys.count > rhs.keys.count {
        return false
    }
    for (i, key) in lhs.keys.enumerated() {
        if key != rhs.keys[i] {
            return false
        }
    }
    return true
}

// MARK: Equatable

func ==(lhs: Key, rhs: Key) -> Bool {
    return lhs.key == rhs.key && lhs.modifiers == rhs.modifiers
}

func ==(lhs: Command, rhs: Command) -> Bool {
    return lhs.keys == rhs.keys
}
