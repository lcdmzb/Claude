import SwiftUI
import AppKit
import Combine

enum RunPhase: Equatable {
    case idle       // 未开始
    case counting   // 久坐计时中
    case standing   // 提醒已触发，正在站立活动
}

/// 全局状态：计时、提醒调度、打卡记录
@MainActor
final class AppState: ObservableObject {

    // MARK: - 已发布状态

    @Published var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            settings.clamp()
            // 间隔变化时立即按新间隔重排下一次提醒
            if phase == .counting, settings.intervalMinutes != oldValue.intervalMinutes {
                scheduleNextFire(from: Date())
            }
            // 交给 ticker 在下一秒统一落盘，避免拖动滑块时高频写文件
            pendingSave = true
        }
    }

    @Published private(set) var records: [String: DayRecord] = [:]
    @Published private(set) var phase: RunPhase = .idle
    @Published private(set) var nextFireAt: Date?
    @Published private(set) var standEndsAt: Date?
    /// 每秒刷新一次，驱动所有倒计时 UI
    @Published private(set) var now = Date()
    /// 本次会话（从点击开始算起）的累计秒数
    @Published private(set) var sessionSeconds: Int = 0

    // MARK: - 私有

    private var ticker: Timer?
    private var lastTick = Date()
    private var currentDayKey = DayKey.string(from: Date())
    private var pendingSave = false
    private var saveCounter = 0

    var overlayController: OverlayController?

    /// 供 AppDelegate 在退出时同步落盘用
    static private(set) weak var current: AppState?

    // MARK: - 生命周期

    init() {
        let store = Storage.shared.load()
        self.settings = store.settings
        self.records = store.records
        ensureTodayRecord()
        startTicker()
        observeSystemEvents()
        overlayController = OverlayController(state: self)
        AppState.current = self

        if settings.autoStartOnLaunch {
            start()
        }
    }

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // .common 模式，保证拖动窗口 / 打开菜单时倒计时不停
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        lastTick = Date()
    }

    private func observeSystemEvents() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                // 睡眠期间不计入使用时长，唤醒后立即检查是否已经错过提醒
                self?.lastTick = Date()
                self?.tick()
            }
        }
    }

    // MARK: - 主循环

    private func tick() {
        let current = Date()
        let delta = current.timeIntervalSince(lastTick)
        lastTick = current
        now = current

        rolloverDayIfNeeded(current)

        // 只累计「合理」的时间片：系统休眠 / 进程被挂起时不应计入使用时长
        if phase != .idle, delta > 0, delta <= 5 {
            let seconds = Int(delta.rounded())
            if seconds > 0 {
                sessionSeconds += seconds
                mutateToday { record in
                    record.activeSeconds += seconds
                    record.lastActiveAt = current
                    if phase == .standing {
                        record.standSeconds += seconds
                    }
                }
            }
        }

        switch phase {
        case .counting:
            if let fireAt = nextFireAt, current >= fireAt {
                fireReminder()
            }
        case .standing:
            if settings.autoDismissOverlay, let end = standEndsAt, current >= end {
                completeStandUp(auto: true)
            }
        case .idle:
            break
        }

        // 每 30 秒落盘一次
        saveCounter += 1
        if saveCounter >= 30 || pendingSave {
            saveCounter = 0
            pendingSave = false
            persist()
        }
    }

    private func rolloverDayIfNeeded(_ date: Date) {
        let key = DayKey.string(from: date)
        guard key != currentDayKey else { return }
        currentDayKey = key
        sessionSeconds = 0
        ensureTodayRecord()
        persist()
    }

    // MARK: - 控制

    func toggle() {
        phase == .idle ? start() : stop()
    }

    /// 点击「开始」：立即打卡，并排定第一次提醒
    func start() {
        guard phase == .idle else { return }
        let current = Date()
        lastTick = current
        sessionSeconds = 0
        mutateToday { record in
            if record.firstStartedAt == nil { record.firstStartedAt = current }
            record.lastActiveAt = current
        }
        phase = .counting
        scheduleNextFire(from: current)
        NotificationManager.shared.requestAuthorizationIfNeeded(enabled: settings.notificationsEnabled)
        persist()
    }

    func stop() {
        guard phase != .idle else { return }
        overlayController?.dismiss()
        ChimePlayer.shared.stop()
        phase = .idle
        nextFireAt = nil
        standEndsAt = nil
        persist()
    }

    /// 手动跳过本轮等待，立刻提醒一次（也用于「试听效果」）
    func triggerNow() {
        guard phase != .standing else { return }
        if phase == .idle { start() }
        fireReminder()
    }

    private func scheduleNextFire(from date: Date) {
        nextFireAt = date.addingTimeInterval(TimeInterval(settings.intervalMinutes * 60))
    }

    // MARK: - 提醒

    private func fireReminder() {
        let current = Date()
        phase = .standing
        standEndsAt = current.addingTimeInterval(TimeInterval(settings.standSeconds))
        nextFireAt = nil

        mutateToday { $0.remindersFired += 1 }

        if settings.soundEnabled {
            ChimePlayer.shared.play(volume: settings.volume)
        }
        if settings.overlayEnabled {
            overlayController?.present()
        }
        if settings.notificationsEnabled {
            NotificationManager.shared.postReminder(standSeconds: settings.standSeconds)
        }
        // 即使覆盖层被关掉，Dock 图标跳动也能起到醒目提醒的作用
        NSApp.requestUserAttention(.criticalRequest)

        persist()
    }

    /// 完成一次起身活动
    func completeStandUp(auto: Bool = false) {
        guard phase == .standing else { return }
        mutateToday { $0.standUpsCompleted += 1 }
        if auto, settings.soundEnabled {
            ChimePlayer.shared.playSoftDing(volume: settings.volume * 0.8)
        }
        finishStanding()
    }

    /// 跳过本次（记录下来，用于统计依从性）
    func skipStandUp() {
        guard phase == .standing else { return }
        mutateToday { $0.standUpsSkipped += 1 }
        finishStanding()
    }

    /// 稍后提醒
    func snooze() {
        guard phase == .standing else { return }
        overlayController?.dismiss()
        ChimePlayer.shared.stop()
        standEndsAt = nil
        phase = .counting
        nextFireAt = Date().addingTimeInterval(TimeInterval(settings.snoozeMinutes * 60))
        persist()
    }

    private func finishStanding() {
        overlayController?.dismiss()
        ChimePlayer.shared.stop()
        standEndsAt = nil
        phase = .counting
        scheduleNextFire(from: Date())
        persist()
    }

    // MARK: - 记录读写

    var todayKey: String { currentDayKey }

    var today: DayRecord {
        records[currentDayKey] ?? DayRecord(day: currentDayKey)
    }

    func record(for day: String) -> DayRecord? {
        records[day]
    }

    private func ensureTodayRecord() {
        if records[currentDayKey] == nil {
            records[currentDayKey] = DayRecord(day: currentDayKey)
        }
    }

    private func mutateToday(_ body: (inout DayRecord) -> Void) {
        var record = records[currentDayKey] ?? DayRecord(day: currentDayKey)
        body(&record)
        records[currentDayKey] = record
        pendingSave = true
    }

    // MARK: - 统计

    /// 距离下一次提醒的剩余秒数
    var secondsUntilFire: Int {
        guard let fireAt = nextFireAt else { return settings.intervalMinutes * 60 }
        return max(0, Int(fireAt.timeIntervalSince(now).rounded()))
    }

    /// 站立活动剩余秒数
    var secondsUntilStandEnds: Int {
        guard let end = standEndsAt else { return settings.standSeconds }
        return max(0, Int(end.timeIntervalSince(now).rounded()))
    }

    /// 主进度环的进度（0~1）
    var ringProgress: Double {
        switch phase {
        case .idle:
            return 0
        case .counting:
            let total = Double(settings.intervalMinutes * 60)
            guard total > 0 else { return 0 }
            return min(1, max(0, 1 - Double(secondsUntilFire) / total))
        case .standing:
            let total = Double(settings.standSeconds)
            guard total > 0 else { return 1 }
            return min(1, max(0, 1 - Double(secondsUntilStandEnds) / total))
        }
    }

    /// 今日目标完成度
    var goalProgress: Double {
        guard settings.dailyGoal > 0 else { return 0 }
        return min(1, Double(today.standUpsCompleted) / Double(settings.dailyGoal))
    }

    /// 连续打卡天数（今天没打卡时，从昨天往前算，不打断已有的记录）
    var currentStreak: Int {
        let calendar = Calendar.current
        var cursor = calendar.startOfDay(for: Date())
        var streak = 0

        if !(records[DayKey.string(from: cursor)]?.isCheckedIn ?? false) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        while let record = records[DayKey.string(from: cursor)], record.isCheckedIn {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    var totalCheckInDays: Int {
        records.values.filter { $0.isCheckedIn }.count
    }

    var totalStandUps: Int {
        records.values.reduce(0) { $0 + $1.standUpsCompleted }
    }

    var totalActiveSeconds: Int {
        records.values.reduce(0) { $0 + $1.activeSeconds }
    }

    /// 最近 n 天（含今天），按时间正序
    func recentDays(_ count: Int) -> [(date: Date, record: DayRecord?)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<count).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (date, records[DayKey.string(from: date)])
        }
    }

    /// 热力等级 0~4，按当天使用时长划分
    func heatLevel(for record: DayRecord?) -> Int {
        guard let record, record.isCheckedIn else { return 0 }
        let minutes = record.activeSeconds / 60
        switch minutes {
        case ..<60: return 1
        case ..<180: return 2
        case ..<360: return 3
        default: return 4
        }
    }

    // MARK: - 持久化

    func persist() {
        Storage.shared.save(StoreFile(settings: settings, records: records))
    }

    func persistNow() {
        Storage.shared.saveSynchronously(StoreFile(settings: settings, records: records))
    }

    func exportCSV() -> String {
        Storage.shared.exportCSV(records: Array(records.values))
    }

    func clearAllRecords() {
        records = [:]
        ensureTodayRecord()
        persistNow()
    }
}
