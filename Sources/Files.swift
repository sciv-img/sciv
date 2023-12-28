import AppKit
import PathKit
import OSet

enum OrderType {
    case none
    case nameAsc
    case nameDesc
    case mtimeAsc
    case mtimeDesc
    case random
}

extension OSet {
    mutating func shuffle() {
        for i in stride(from: self.count - 1, through: 1, by: -1) {
            let j = Int(arc4random_uniform(UInt32(i)))
            self.swapAt(i, j)
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
}

extension URL {
    var isImage: Bool {
        let ext = self.pathExtension
        guard ext != "" else {
            return false
        }
        let uti = UTTypeCreatePreferredIdentifierForTag(
            kUTTagClassFilenameExtension, ext as CFString, kUTTypeImage
        )
        return uti != nil && !(uti!.takeRetainedValue() as String).hasPrefix("dyn.")
    }
}

class File: Hashable, Comparable {
    let path: Path
    let mtime: Date

    init(_ path: Path) {
        self.path = path

        var st = stat()
        stat(path.string, &st)
        self.mtime = Date(timeIntervalSince1970: Double(st.st_mtimespec.tv_sec))
    }

    convenience init(_ url: URL) {
        self.init(Path(url.path))
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.mtime)
        hasher.combine(self.path)
    }

    public static func == (lhs: File, rhs: File) -> Bool {
        return lhs.path == rhs.path && lhs.mtime == rhs.mtime
    }

    public static func < (lhs: File, rhs: File) -> Bool {
        return lhs.path < rhs.path
    }
}

class Files {
    private let dir: Path
    private var dirMonitor: GCDFileMonitor?
    private var currentMonitor: GCDFileMonitor?

    private let isUpdatingLock = DispatchSemaphore(value: 1)
    private var _isUpdating = false
    private var isUpdating: Bool {
        set {
            self.isUpdatingLock.wait()
            self._isUpdating = newValue
            self.isUpdatingLock.signal()
        }
        get {
            self.isUpdatingLock.wait()
            defer { self.isUpdatingLock.signal() }
            return self._isUpdating
        }
    }

    private var files: OSet<File>
    private var currentFile: File
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

            self.currentFile = self.files[self.i]

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
            self.i = self.files.firstIndex(where: {$0.path == filepath})!
        }
    }

    private let callback: () -> Void

    init(_ dirOrFile: String, _ callback: @escaping () -> Void) {
        self.o = .none
        let dirOrFilePath = Path(dirOrFile)
        if dirOrFilePath.isFile {
            self.dir = dirOrFilePath.getDirPath()
        } else {
            self.dir = dirOrFilePath
        }
        self.callback = callback

        self.files = Files.getDirContents(self.dir)

        self.i = self.files.firstIndex(where: {$0.path == dirOrFilePath}) ?? 0
        self.currentFile = self.files[self.i]

        self.dirMonitor = GCDFileMonitor(self.dir, self.refreshDir)
        self.newCurrentMonitor()
    }

    private class func getDirContents(_ dir: Path) -> OSet<File> {
        return OSet(
            ((try? FileManager.default.contentsOfDirectory(
                at: dir.url,
                includingPropertiesForKeys: []
            )) ?? []).lazy.filter({ $0.isImage }).map({ File($0) })
        )
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
        // XXX: Get event here, spawn new thread with actual code.
        // Then we should be able to process many events quickly.
        // Remember about synchronization!

        self.isUpdating = true
        defer { self.isUpdating = false }

        let o = self.o
        let i = self.i

        let files = Files.getDirContents(self.dir)

        if o == .random {
            let new = files.subtracting(self.files)
            self.files.formIntersection(files)
            self.files.formUnion(new)
        } else {
            self.files = files
            self.sort()
        }

        self.i = self.files.firstIndex(where: {$0.path == self.currentFile.path}) ?? i
    }

    private func refreshCurrent() {
        if !self.isUpdating {
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
