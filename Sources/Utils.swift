import AppKit

enum OrderType {
    case NameAsc
    case NameDesc
    case MtimeAsc
    case MtimeDesc
    case Random
}

class File {
    var path: Path
    var mtime: NSDate

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

extension NSDate: Comparable {}

public func ==(lhs: NSDate, rhs: NSDate) -> Bool {
    return lhs === rhs || lhs.compare(rhs) == .OrderedSame
}

public func <(lhs: NSDate, rhs: NSDate) -> Bool {
    return lhs.compare(rhs) == .OrderedAscending
}
