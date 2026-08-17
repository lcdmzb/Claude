import Foundation

/// 把设置与打卡记录保存到 ~/Library/Application Support/StandUp/store.json
///
/// 采用「写临时文件再原子替换」的方式，避免进程被强杀时留下半截 JSON。
final class Storage {
    static let shared = Storage()

    private let queue = DispatchQueue(label: "com.standup.storage")
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {}

    var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("StandUp", isDirectory: true)
    }

    var fileURL: URL {
        directoryURL.appendingPathComponent("store.json")
    }

    func load() -> StoreFile {
        guard let data = try? Data(contentsOf: fileURL) else { return StoreFile() }
        guard var store = try? decoder.decode(StoreFile.self, from: data) else {
            // 文件损坏时备份一份，避免用户的历史记录被静默覆盖
            let backup = directoryURL.appendingPathComponent("store.corrupted-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try? data.write(to: backup)
            return StoreFile()
        }
        store.settings.clamp()
        return store
    }

    /// 异步落盘；调用方可以放心地高频调用
    func save(_ store: StoreFile) {
        guard let data = try? encoder.encode(store) else { return }
        let dir = directoryURL
        let target = fileURL
        queue.async {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let tmp = dir.appendingPathComponent("store.json.tmp")
                try data.write(to: tmp, options: .atomic)
                if FileManager.default.fileExists(atPath: target.path) {
                    _ = try FileManager.default.replaceItemAt(target, withItemAt: tmp)
                } else {
                    try FileManager.default.moveItem(at: tmp, to: target)
                }
            } catch {
                // 落盘失败时退化为直接写入，最坏情况下丢失本次增量
                try? data.write(to: target, options: .atomic)
            }
        }
    }

    /// 退出前同步落盘，保证最后一次数据不丢
    func saveSynchronously(_ store: StoreFile) {
        guard let data = try? encoder.encode(store) else { return }
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    /// 导出为 CSV，方便用户自己做统计
    func exportCSV(records: [DayRecord]) -> String {
        var lines = ["日期,使用时长(分钟),站立时长(分钟),提醒次数,完成起身,跳过次数,是否打卡"]
        for r in records.sorted(by: { $0.day < $1.day }) {
            lines.append([
                r.day,
                String(r.activeSeconds / 60),
                String(r.standSeconds / 60),
                String(r.remindersFired),
                String(r.standUpsCompleted),
                String(r.standUpsSkipped),
                r.isCheckedIn ? "是" : "否"
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }
}
