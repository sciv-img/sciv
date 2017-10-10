import AppKit
import PathKit
import Cpcre

class GCDFileMonitor {
    private static let dq = DispatchQueue(label: "sx.kenji.sciv", attributes: .concurrent)

    private let file: Int32
    private let dsfso: DispatchSourceFileSystemObject

    init(_ dirOrFilePath: Path, _ callback: @escaping () -> Void, events: DispatchSource.FileSystemEvent = .all) {
        self.file = open(dirOrFilePath.string, O_EVTONLY)
        self.dsfso = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: self.file,
            eventMask: events,
            queue: GCDFileMonitor.dq
        )
        self.dsfso.setEventHandler(handler: callback)
        self.dsfso.setCancelHandler(handler: {
            close(self.file)
        })
        self.dsfso.resume()
    }

    deinit {
        self.cancel()
    }

    func cancel() {
        self.dsfso.cancel()
    }
}

class Regex: Hashable, Equatable {
    let regex: OpaquePointer?
    let hash: Int // For Hashable

    init?(_ regex: String) {
        self.hash = regex.hashValue

        let error = UnsafeMutablePointer<UnsafePointer<Int8>?>.allocate(capacity: 1)
        let offset = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        defer {
            error.deallocate(capacity: 1)
            error.deinitialize()
            offset.deallocate(capacity: 1)
            offset.deinitialize()
        }
        self.regex = pcre_compile(regex, 0, error, offset, nil)
        if self.regex == nil {
            return nil
        }
    }

    deinit {
        pcre_free?(UnsafeMutableRawPointer(self.regex))
    }

    func match(_ string: String) -> (Bool, [String]?) {
        let ovector = UnsafeMutablePointer<Int32>.allocate(capacity: 3 * 32)
        defer {
            ovector.deallocate(capacity: 3 * 32)
            ovector.deinitialize()
        }
        let matches = pcre_exec(
            self.regex, nil, string, Int32(string.characters.count),
            0, Cpcre.PCRE_PARTIAL, ovector, 3 * 32
        )
        if matches == Cpcre.PCRE_ERROR_PARTIAL {
            return (true, nil)
        }
        if matches < 0 {
            return (false, nil)
        }
        // TODO: Make this more generic?
        let si = string.startIndex
        let start = string.index(si, offsetBy: Int(ovector[2]))
        let end = string.index(si, offsetBy: Int(ovector[3]))
        return (true, [string[start..<end]])
    }

    var hashValue: Int {
        return self.hash
    }

    static func == (lhs: Regex, rhs: Regex) -> Bool {
        return lhs.hash == rhs.hash
    }
}
