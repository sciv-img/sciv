import AppKit
import PathKit

enum OrderType {
    case None
    case NameAsc
    case NameDesc
    case MtimeAsc
    case MtimeDesc
    case Random
}

extension Array {
    mutating func shuffleInPlace() {
        for i in stride(from: self.count - 1, through: 1, by: -1) {
            let j = Int(arc4random_uniform(UInt32(i)))
            swap(&self[i], &self[j])
        }
    }
}

class File {
    let path: Path
    let mtime: Date

    init(_ path: Path) {
        self.path = path

        var st = stat()
        stat(String(describing: path), &st)
        self.mtime = Date(timeIntervalSince1970: Double(st.st_mtimespec.tv_sec))
    }
}

class Files {
    var callback: () -> ()

    var files: [File]
    var i: Int {
        didSet {
            if self.i < 0 {
                self.i = 0
            } else if self.i >= self.files.count {
                self.i = self.files.count - 1
            }
            self.callback()
        }
    }
    var o: OrderType {
        didSet {
            let filepath = self.files[self.i].path
            switch self.o {
            case .NameAsc:
                self.files.sort(by: {$0.path < $1.path})
            case .NameDesc:
                self.files.sort(by: {$0.path > $1.path})
            case .MtimeAsc:
                self.files.sort(by: {$0.mtime < $1.mtime})
            case .MtimeDesc:
                self.files.sort(by: {$0.mtime > $1.mtime})
            case .Random:
                self.files.shuffleInPlace()
            default:
                return
            }
            self.i = self.files.index(where: {$0.path == filepath})!
        }
    }

    var dir: Path
    var monitor: FSEventsMonitor?

    init(_ dirOrFile: String, _ callback: @escaping () -> ()) {
        self.files = []
        self.o = .None
        let dirOrFilePath = Path(dirOrFile)
        if dirOrFilePath.isFile {
            self.dir = Files.getDirPath(path: dirOrFilePath)
        } else {
            self.dir = dirOrFilePath
        }
        self.callback = callback

        for path in (try? dir.children()) ?? [] {
            let ext = path.`extension`
            if ext == nil {
                continue
            }
            let kUTTCFE = kUTTagClassFilenameExtension
            if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTCFE, ext! as CFString, nil) {
                if !UTTypeConformsTo(uti.takeRetainedValue(), kUTTypeImage) {
                    continue
                }
                self.files.append(File(path))
            }
        }

        self.i = self.files.index(where: {$0.path == dirOrFilePath}) ?? 0

        self.monitor = FSEventsMonitor(self.dir, callback: self.eventHandler)
    }

    private class func getDirPath(path: Path) -> Path {
        // TODO: Move this (done nicely) into PathKit
        var components = path.components
        if components[0] == "/" {
            components[0] = ""
        }
        return Path(components[0..<components.count - 1].joined(separator: Path.separator))
    }

    private func eventHandler(event: FSEvent) {
        if event.flag.contains(.ItemRenamed) {
            if !event.path.exists {
                if let idx = self.files.index(where: {$0.path == event.path}) {
                    let i = self.i
                    self.files.remove(at: idx)
                    self.i = i
                }
            } else {
                // TODO: Where to put i when "real" rename within dir?
                let i = self.i
                let o = self.o
                self.files.append(File(event.path))
                self.o = o
                self.i = i
            }
        }
    }

    var current: Path {
        return self.files[self.i].path
    }

    var count: Int {
        return self.files.count
    }
}
