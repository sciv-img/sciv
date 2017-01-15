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

// TODO: Replace with Array extension in Swift 3.1
extension _ArrayProtocol where Iterator.Element == File {
    mutating func appendIfImage(_ path: Path) {
        if path.isImage {
            self.append(File(path))
        }
    }
}

class Files {
    var callback: () -> Void

    private var files: [File]
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
                self.files.shuffle()
            default:
                return
            }
            self.i = self.files.index(where: {$0.path == filepath})!
        }
    }

    var dir: Path
    var monitor: FSEventsMonitor?

    init(_ dirOrFile: String, _ callback: @escaping () -> Void) {
        self.files = []
        self.o = .None
        let dirOrFilePath = Path(dirOrFile)
        if dirOrFilePath.isFile {
            self.dir = dirOrFilePath.getDirPath()
        } else {
            self.dir = dirOrFilePath
        }
        self.callback = callback

        for path in (try? dir.children()) ?? [] {
            self.files.appendIfImage(path)
        }

        self.i = self.files.index(where: {$0.path == dirOrFilePath}) ?? 0

        self.monitor = FSEventsMonitor(self.dir, callback: self.eventHandler)
    }

    private func eventHandler(event: FSEvent) {
        var path = event.path

        func create() {
            let c = self.current
            let o = self.o
            self.files.appendIfImage(path)
            self.o = o
            self.i = self.files.index(where: {$0.path == c})!
        }
        func remove() {
            if let idx = self.files.index(where: {$0.path == path}) {
                self.files.remove(at: idx)

                if idx < self.i {
                    self.i -= 1
                } else {
                    self.i += 0
                }
            }
        }

        if event.flag.contains(.ItemCreated) {
            create()
        } else if event.flag.contains(.ItemRemoved) {
            remove()
        } else if event.flag.contains(.ItemModified) {
            if let idx = self.files.index(where: {$0.path == path}) {
                if idx == self.i {
                    self.callback()
                }
            }
        } else if event.flag.contains(.ItemRenamed) {
            if let oldPath = event.oldPath {
                if path.isImage {
                    if let i = self.files.index(where: {$0.path == oldPath}) {
                        var c = self.current
                        let o = self.o
                        self.files[i] = File(path)
                        self.o = o

                        if path == self.current {
                            c = path
                        }
                        self.i = self.files.index(where: {$0.path == c})!
                    } else {
                        create()
                    }
                } else {
                    path = oldPath
                    remove()
                }
            } else if !path.exists {
                remove()
            } else {
                create()
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
