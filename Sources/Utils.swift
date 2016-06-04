import AppKit
import pcre

class Regex: Hashable {
    let regex: COpaquePointer
    let hash: Int // For Hashable

    init?(_ regex: String) {
        self.hash = regex.hashValue

        let error = UnsafeMutablePointer<UnsafePointer<Int8>>.alloc(1)
        let offset = UnsafeMutablePointer<Int32>.alloc(1)
        defer {
            error.dealloc(1)
            error.destroy()
            offset.dealloc(1)
            offset.destroy()
        }
        self.regex = pcre_compile(regex, 0, error, offset, nil)
        if self.regex == nil {
            return nil
        }
    }

    deinit {
        pcre_free?(UnsafeMutablePointer<Void>(self.regex))
    }

    func match(string: String) -> (Bool, [String]?) {
        let ovector = UnsafeMutablePointer<Int32>.alloc(3 * 32)
        defer {
            ovector.dealloc(3 * 32)
            ovector.destroy()
        }
        let matches = pcre_exec(
            self.regex, nil, string, Int32(string.characters.count),
            0, pcre.PCRE_PARTIAL, ovector, 3 * 32
        )
        if matches == pcre.PCRE_ERROR_PARTIAL {
            return (true, nil)
        }
        if matches < 0 {
            return (false, nil)
        }
        // TODO: Make this more generic?
        let si = string.startIndex
        let start = si.advancedBy(Int(ovector[2]))
        let end = si.advancedBy(Int(ovector[3]))
        return (true, [string[start..<end]])
    }

    var hashValue: Int {
        return self.hash
    }
}

extension NSDate: Comparable {}

public func <(lhs: NSDate, rhs: NSDate) -> Bool {
    return lhs.compare(rhs) == .OrderedAscending
}

func ==(lhs: NSDate, rhs: NSDate) -> Bool {
    return lhs === rhs || lhs.compare(rhs) == .OrderedSame
}

func ==(lhs: Regex, rhs: Regex) -> Bool {
    return lhs.hash == rhs.hash
}
