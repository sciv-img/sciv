import AppKit
import PathKit
import pcre

class Regex: Hashable {
    // FIXME: Handle deinit
    let regex: COpaquePointer
    let hash: Int // For Hashable

    init?(_ regex: String) {
        self.hash = regex.hashValue

        let error = UnsafeMutablePointer<UnsafePointer<Int8>>.alloc(1)
        let offset = UnsafeMutablePointer<Int32>.alloc(1)
        defer {
            error.destroy()
            offset.destroy()
        }
        self.regex = pcre_compile(regex, 0, error, offset, nil)
        if self.regex == nil {
            return nil
        }
    }

    func match(string: String) -> (Bool, [String]?) {
        let ovector = UnsafeMutablePointer<Int32>.alloc(3 * 32)
        defer {
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

class File {
    let path: Path
    let mtime: NSDate

    init(_ path: Path) {
        self.path = path

        var st = stat()
        stat(String(path), &st)
        self.mtime = NSDate(timeIntervalSince1970: Double(st.st_mtimespec.tv_sec))
    }
}

extension Array {
    mutating func shuffleInPlace() {
        for i in (self.count - 1).stride(through: 1, by: -1) {
            let j = Int(arc4random_uniform(UInt32(i)))
            swap(&self[i], &self[j])
        }
    }
}

enum OrderType {
    case NameAsc
    case NameDesc
    case MtimeAsc
    case MtimeDesc
    case Random
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
