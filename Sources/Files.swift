import AppKit
import PathKit

enum OrderType {
    case none
    case nameAsc
    case nameDesc
    case mtimeAsc
    case mtimeDesc
    case random
}

extension Array {
    mutating func shuffle() {
        for i in stride(from: self.count - 1, through: 1, by: -1) {
            let j = Int(arc4random_uniform(UInt32(i)))
            swap(&self[i], &self[j])
        }
    }
}

extension Path {
    // TODO: Move this (done nicely) into PathKit
    func getDirPath() -> Path {
        var components = self.components
        if components[0] == "/" {
            components[0] = ""
        }
        return Path(components[0..<components.count-1].joined(separator: Path.separator))
    }

    var isImage: Bool {
        guard let ext = self.extension else {
            return false
        }
        let kUTTCFE = kUTTagClassFilenameExtension
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTCFE, ext as CFString, nil) {
            if !UTTypeConformsTo(uti.takeRetainedValue(), kUTTypeImage) {
                return false
            }
            return true
        }
        return false
    }
}

class File: Equatable {
    let path: Path
    let mtime: Date

    init(_ path: Path) {
        self.path = path

        var st = stat()
        stat(path.string, &st)
        self.mtime = Date(timeIntervalSince1970: Double(st.st_mtimespec.tv_sec))
    }

    public static func == (lhs: File, rhs: File) -> Bool {
        return lhs.path == rhs.path && lhs.mtime == rhs.mtime
    }
}

extension Array where Iterator.Element == File {
    mutating func appendIfImage(_ path: Path) {
        if path.isImage {
            self.append(File(path))
        }
    }
}

class Files {
    private let dir: Path
    private var dirMonitor: GCDFileMonitor?
    private var currentMonitor: GCDFileMonitor?
    private var isUpdating = false
    private let isUpdatingLock = DispatchSemaphore(value: 1)

    private var files: [File]
    var i: Int {
        didSet {
            if let cm = self.currentMonitor {
                cm.cancel()
            }

            if self.count > 0 {
                if self.i < 0 {
                    self.i = 0
                } else if self.i >= self.count {
                    self.i = self.count - 1
                }

                self.newCurrentMonitor()
            }

            self.updateView()
        }
    }
    var o: OrderType {
        didSet {
            guard let filepath = self.current else {
                return
            }
            if !self.sort() {
                return
            }
            self.i = self.files.index(where: {$0.path == filepath})!
        }
    }

    private let callback: () -> Void

    init(_ dirOrFile: String, _ callback: @escaping () -> Void) {
        self.files = []
        self.o = .none
        let dirOrFilePath = Path(dirOrFile)
        if dirOrFilePath.isFile {
            self.dir = dirOrFilePath.getDirPath()
        } else {
            self.dir = dirOrFilePath
        }
        self.callback = callback

        for path in (try? self.dir.children()) ?? [] {
            self.files.appendIfImage(path)
        }

        self.i = self.files.index(where: {$0.path == dirOrFilePath}) ?? 0

        self.dirMonitor = GCDFileMonitor(self.dir, self.refreshDir)
        self.newCurrentMonitor()
    }

    private func newCurrentMonitor() {
        // [.attrib, .delete, .extend, .funlock, .link, .rename, .revoke, .write]
        self.currentMonitor = GCDFileMonitor(
            self.current!,
            self.refreshCurrent,
            events: [.attrib]
        )
    }

    private func updateView() {
        DispatchQueue.main.async(execute: self.callback)
    }

    private func refreshDir() {
        // XXX: Get event here, spawn need thread with actual code.
        // Then we should be able to process many events quickly.
        // Remember about synchronization!

        self.isUpdatingLock.wait()
        self.isUpdating = true
        self.isUpdatingLock.signal()

        let o = self.o
        let i = self.i

        var files: [File] = []
        for path in (try? self.dir.children()) ?? [] {
            files.appendIfImage(path)
        }

        if o == .random {
            // TODO: Make this more efficient (OrderedSet?)
            let new = files.filter({ !self.files.contains($0) })
            files = self.files.filter({ files.contains($0) })
            self.files = files + new
        } else {
            self.files = files
            self.sort()
        }

        self.i = i

        self.isUpdatingLock.wait()
        self.isUpdating = false
        self.isUpdatingLock.signal()
    }

    private func refreshCurrent() {
        self.isUpdatingLock.wait()
        let isUpdating = self.isUpdating
        self.isUpdatingLock.signal()

        if !isUpdating {
            self.updateView()
        }
    }

    @discardableResult
    private func sort() -> Bool {
        switch self.o {
        case .nameAsc:
            self.files.sort(by: {$0.path < $1.path})
        case .nameDesc:
            self.files.sort(by: {$0.path > $1.path})
        case .mtimeAsc:
            self.files.sort(by: {$0.mtime < $1.mtime})
        case .mtimeDesc:
            self.files.sort(by: {$0.mtime > $1.mtime})
        case .random:
            self.files.shuffle()
        default:
            return false
        }
        return true
    }

    var current: Path? {
        if self.i >= self.count {
            return nil
        }
        return self.files[self.i].path
    }

    var count: Int {
        return self.files.count
    }
}
