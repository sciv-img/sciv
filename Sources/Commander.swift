import AppKit

class Key: Equatable {
    var modifiers: NSEvent.ModifierFlags
    let key: Int

    convenience init(_ key: Character, _ modifiers: NSEvent.ModifierFlags...) {
        let utf = String(key).utf16
        self.init(Int(utf[utf.startIndex]), modifiers)
    }

    convenience init(_ key: Int, _ modifiers: NSEvent.ModifierFlags...) {
        self.init(key, modifiers)
    }

    init(_ key: Int, _ modifiers: [NSEvent.ModifierFlags]) {
        self.key = key
        self.modifiers = NSEvent.ModifierFlags()
        for modifier in modifiers {
            self.modifiers.insert(modifier)
        }
    }
}

protocol CommandCaller {
    func tryCall(_ command: Command) -> (Bool, Bool)
}

struct Command: Comparable, CustomStringConvertible, Hashable {
    var keys: [Key] = []

    mutating func addKey(_ key: Key) {
        self.keys.append(key)
    }

    func dropFirst(_ n: Int) -> Command {
        return Command(keys: Array(self.keys.dropFirst(n)))
    }

    var description: String {
        return self.keys.map({"\(UnicodeScalar($0.key)!)"}).joined(separator: "")
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.keys.map({"\($0.modifiers)\($0.key)"}).joined(separator: ""))
    }
}

struct KeyCaller: CommandCaller {
    let command: Command
    let callback: () -> Void

    func check(_ command: Command) -> (Bool, Bool) {
        if command == self.command {
            return (true, true)
        }
        return (false, command < self.command)
    }

    func tryCall(_ command: Command) -> (Bool, Bool) {
        let res = self.check(command)
        if res.0 {
            self.callback()
        }
        return res
    }
}

struct RegexCaller: CommandCaller {
    let regex: Regex
    let callback: ([String]) -> Void

    func check(_ command: Command) -> (Bool, Bool, [String]) {
        let (match, captures) = self.regex.match(String(describing: command))
        if match {
            if captures != nil {
                return (true, true, captures!)
            }
            return (false, true, [])
        }
        return (false, false, [])
    }

    func tryCall(_ command: Command) -> (Bool, Bool) {
        let (match, partial, captures) = self.check(command)
        if match {
            self.callback(captures)
        }
        return (match, partial)
    }
}

struct CombinedCaller: CommandCaller {
    let regex: RegexCaller
    let key: KeyCaller

    init(_ regex: Regex, _ keys: [Key], _ callback: @escaping ([String]) -> Void) {
        self.regex = RegexCaller(regex: regex, callback: callback)
        self.key = KeyCaller(command: Command(keys: keys), callback: {})
    }

    func tryCall(_ command: Command) -> (Bool, Bool) {
        let (match, partial, captures) = self.regex.check(command)
        if match {
            let res = self.key.check(command.dropFirst(captures[0].count))
            if res.0 {
                self.regex.callback(captures)
            }
            return res
        }
        return (match, partial)
    }
}

class Commander {
    var commands: [CommandCaller] = []
    var current: Command = Command()

    func addCommand(_ callable: @escaping () -> Void, _ keys: Key...) {
        self.commands.append(KeyCaller(command: Command(keys: keys), callback: callable))
    }

    func addCommand(_ callable: @escaping ([String]) -> Void, _ regex: String) {
        if let r = Regex(regex) {
            self.commands.append(RegexCaller(regex: r, callback: callable))
            return
        }
        // TODO: Return error to user
    }

    func addCommand(_ callable: @escaping ([String]) -> Void, _ regex: String, _ keys: Key...) {
        if let r = Regex(regex) {
            // Prepend to be able to catch Combined ones before modifier-key-level
            // equivalent Regex ones (e.g. Regex containing Space, ` `, and Combined
            // with Shift+Space).
            self.commands.insert(CombinedCaller(r, keys, callable), at: 0)
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
        var maybeCmd = false
        for command in self.commands {
            let (called, partial) = command.tryCall(self.current)
            if called {
                self.current = Command()
                return true
            }
            maybeCmd = maybeCmd || partial
        }
        if !maybeCmd {
            self.current = Command()
        }
        return maybeCmd
    }
}

// MARK: Comparable

func < (lhs: Command, rhs: Command) -> Bool {
    if lhs.keys.count > rhs.keys.count {
        return false
    }
    for (i, key) in lhs.keys.enumerated() where key != rhs.keys[i] {
        return false
    }
    return true
}

// MARK: Equatable

func == (lhs: Key, rhs: Key) -> Bool {
    return lhs.key == rhs.key && lhs.modifiers == rhs.modifiers
}

func == (lhs: Command, rhs: Command) -> Bool {
    return lhs.keys == rhs.keys
}
