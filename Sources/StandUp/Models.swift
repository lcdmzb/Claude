import Foundation

// MARK: - 日期工具

enum DayKey {
    /// 统一使用本地时区的 yyyy-MM-dd 作为一天的主键
    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(from key: String) -> Date? {
        formatter.date(from: key)
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// MARK: - 打卡记录

/// 一天的打卡记录：使用时长、提醒次数、完成的起身活动次数
struct DayRecord: Codable, Identifiable, Equatable {
    var day: String                 // yyyy-MM-dd
    var activeSeconds: Int = 0      // 软件处于「计时中」的累计时长
    var standSeconds: Int = 0       // 站立活动累计时长
    var remindersFired: Int = 0     // 触发的提醒次数
    var standUpsCompleted: Int = 0  // 实际完成的起身次数
    var standUpsSkipped: Int = 0    // 跳过的次数
    var firstStartedAt: Date?       // 当天第一次开始计时的时间
    var lastActiveAt: Date?         // 当天最后一次活跃时间

    var id: String { day }

    /// 只要当天真正用过（累计 60 秒以上），就算完成打卡
    var isCheckedIn: Bool { activeSeconds >= 60 }

    var date: Date? { DayKey.date(from: day) }

    init(day: String) {
        self.day = day
    }
}

// MARK: - 设置

struct AppSettings: Codable, Equatable {
    /// 提醒间隔（分钟），默认 60 分钟
    var intervalMinutes: Int = 60
    /// 建议站立活动时长（秒）
    var standSeconds: Int = 300
    /// 稍后提醒的延迟（分钟）
    var snoozeMinutes: Int = 5
    /// 每日目标起身次数
    var dailyGoal: Int = 8

    var soundEnabled: Bool = true
    var volume: Double = 0.7
    var overlayEnabled: Bool = true
    var notificationsEnabled: Bool = true
    /// 覆盖层在站立时长结束后自动关闭
    var autoDismissOverlay: Bool = true
    /// 启动 App 时自动开始计时
    var autoStartOnLaunch: Bool = false

    /// 合法区间保护，避免手改 JSON 造成异常
    mutating func clamp() {
        intervalMinutes = min(max(intervalMinutes, 1), 24 * 60)
        standSeconds = min(max(standSeconds, 30), 3600)
        snoozeMinutes = min(max(snoozeMinutes, 1), 120)
        dailyGoal = min(max(dailyGoal, 1), 48)
        volume = min(max(volume, 0), 1)
    }
}

// MARK: - 持久化容器

struct StoreFile: Codable {
    var settings: AppSettings = AppSettings()
    var records: [String: DayRecord] = [:]
    var version: Int = 1
}

// MARK: - 格式化助手

enum Format {
    /// 3661 -> "1 小时 1 分"
    static func duration(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) 秒" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 {
            return m > 0 ? "\(h) 小时 \(m) 分" : "\(h) 小时"
        }
        return "\(m) 分钟"
    }

    /// 倒计时 mm:ss 或 hh:mm:ss
    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%02d:%02d", m, sec)
    }

    /// 菜单栏用的紧凑倒计时，例如 "45′" / "58″"
    static func compact(_ seconds: Int) -> String {
        let s = max(0, seconds)
        if s >= 60 { return "\(s / 60)′" }
        return "\(s)″"
    }

    static let monthTitle: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy 年 M 月"
        return f
    }()

    static let dayTitle: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M 月 d 日 EEEE"
        return f
    }()

    static let timeOnly: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()
}
