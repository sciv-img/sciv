import AppKit
import PathKit
import Cpcre

struct FSEventFlag: OptionSet {
    let rawValue: FSEventStreamEventFlags

    public static let None = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagNone))
    public static let MustScanSubDirs = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs))
    public static let UserDropped = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagUserDropped))
    public static let KernelDropped = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagKernelDropped))
    public static let EventIdsWrapped = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagEventIdsWrapped))
    public static let HistoryDone = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagHistoryDone))
    public static let RootChanged = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagRootChanged))
    public static let Mount = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagMount))
    public static let Unmount = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagUnmount))
    public static let ItemChangeOwner = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemChangeOwner))
    public static let ItemCreated = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated))
    public static let ItemFinderInfoMod = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemFinderInfoMod))
    public static let ItemInodeMetaMod = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemInodeMetaMod))
    public static let ItemIsDir = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsDir))
    public static let ItemIsFile = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile))
    public static let ItemIsHardlink = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsHardlink))
    public static let ItemIsLastHardlink = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsLastHardlink))
    public static let ItemIsSymlink = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsSymlink))
    public static let ItemModified = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified))
    public static let ItemRemoved = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved))
    public static let ItemRenamed = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed))
    public static let ItemXattrMod = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemXattrMod))
    public static let OwnEvent = FSEventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagOwnEvent))
}

struct FSEvent {
    public let path: Path
    public let flag: FSEventFlag

    public let oldPath: Path?
}

class FSEventsMonitor {
    private var stream: FSEventStreamRef?
    private let callback: (FSEvent) -> Void

    init?(_ path: Path, callback: @escaping (FSEvent) -> Void) {
        self.callback = callback

        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        self.stream = FSEventStreamCreate(
            nil, self.streamCallback, &context,
            [path.string] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0, FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagUseCFTypes |
                kFSEventStreamCreateFlagFileEvents
            )
        )
        guard let stream = self.stream else {
            return nil
        }

        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
    }

    deinit {
        if let stream = self.stream {
            FSEventStreamStop(stream)
            FSEventStreamUnscheduleFromRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }

    private let streamCallback: FSEventStreamCallback = {(stream, contextInfo, numEvents, eventPaths, eventFlags, eventIds) in
        guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else {
            return
        }

        let this = unsafeBitCast(contextInfo, to: FSEventsMonitor.self)
        let flags = Array(UnsafeBufferPointer(start: eventFlags, count: numEvents))
        let ids = Array(UnsafeBufferPointer(start: eventIds, count: numEvents))

        for i in stride(from: 0, to: numEvents, by: 2) {
            let p1 = Path(paths[i])
            let f1 = FSEventFlag(rawValue: flags[i])
            let i1 = ids[i]

            if i+1 < numEvents {
                let p2 = Path(paths[i+1])
                let f2 = FSEventFlag(rawValue: flags[i+1])
                let i2 = ids[i+1]

                if f2.contains(.ItemRenamed) && i2 == i1+1 && p1.getDirPath() == p2.getDirPath() {
                    this.callback(FSEvent(path: p2, flag: f2, oldPath: p1))
                    continue
                }
                this.callback(FSEvent(path: p1, flag: f1, oldPath: nil))
                this.callback(FSEvent(path: p2, flag: f2, oldPath: nil))
                continue
            }

            this.callback(FSEvent(path: p1, flag: f1, oldPath: nil))
        }
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
