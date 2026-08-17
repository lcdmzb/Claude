import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct HistoryView: View {
    @EnvironmentObject private var state: AppState

    @State private var monthAnchor: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedDay: String = DayKey.string(from: Date())

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 18) {
            calendarCard
            detailCard
            summaryCard
        }
    }

    // MARK: - 月历

    private var calendarCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                monthHeader
                weekdayHeader
                monthGrid
                legend
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            SectionTitle(icon: "calendar", text: "打卡日历")
            Spacer()
            HStack(spacing: 4) {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .padding(6)

                Text(Format.monthTitle.string(from: monthAnchor))
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .frame(minWidth: 110)
                    .foregroundStyle(Theme.textPrimary)

                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .padding(6)
                .disabled(isCurrentMonth)
                .opacity(isCurrentMonth ? 0.3 : 1)
            }
            .foregroundStyle(Theme.textSecondary)
        }
    }

    /// 表头顺序跟随系统「每周从星期几开始」的设置
    private var weekdaySymbols: [String] {
        let base = ["日", "一", "二", "三", "四", "五", "六"]
        let offset = calendar.firstWeekday - 1
        return (0..<7).map { base[($0 + offset) % 7] }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 8) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let cells = monthCells()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
            ForEach(cells.indices, id: \.self) { index in
                if let date = cells[index] {
                    dayCell(date)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let key = DayKey.string(from: date)
        let record = state.record(for: key)
        let level = state.heatLevel(for: record)
        let isToday = calendar.isDateInToday(date)
        let isSelected = key == selectedDay
        let isFuture = date > Date()

        return Button {
            selectedDay = key
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 12, weight: level >= 3 ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(level >= 3 ? Color.white : Theme.textPrimary.opacity(isFuture ? 0.25 : 0.85))

                Circle()
                    .fill(((record?.standUpsCompleted ?? 0) > 0) ? Color.white.opacity(0.9) : Color.clear)
                    .frame(width: 4, height: 4)
                    .opacity(level >= 3 ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.heatColor(level: level))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isSelected ? Theme.accentSecondary : (isToday ? Theme.accent : .clear),
                        lineWidth: isSelected ? 2 : 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .help(cellTooltip(date: date, record: record))
    }

    private func cellTooltip(date: Date, record: DayRecord?) -> String {
        let title = Format.dayTitle.string(from: date)
        guard let record, record.isCheckedIn else { return "\(title)：未打卡" }
        return "\(title)：使用 \(Format.duration(record.activeSeconds))，起身 \(record.standUpsCompleted) 次"
    }

    private var legend: some View {
        HStack(spacing: 8) {
            Text("少")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
            ForEach(0...4, id: \.self) { level in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.heatColor(level: level))
                    .frame(width: 14, height: 14)
            }
            Text("多")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
            Spacer()
            Text("颜色深浅代表当天使用时长")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: - 选中日详情

    private var detailCard: some View {
        let record = state.record(for: selectedDay)
        let date = DayKey.date(from: selectedDay) ?? Date()

        return Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(
                    icon: "doc.text.magnifyingglass",
                    text: Format.dayTitle.string(from: date),
                    trailing: (record?.isCheckedIn ?? false) ? "已打卡" : "未打卡"
                )

                if let record, record.isCheckedIn {
                    HStack(spacing: 12) {
                        StatTile(icon: "clock.fill", title: "使用时长",
                                 value: "\(record.activeSeconds / 60)", unit: "分钟")
                        StatTile(icon: "figure.walk", title: "完成起身",
                                 value: "\(record.standUpsCompleted)", unit: "次")
                        StatTile(icon: "bell.fill", title: "提醒次数",
                                 value: "\(record.remindersFired)", unit: "次",
                                 tint: Theme.accentSecondary)
                        StatTile(icon: "arrow.uturn.right", title: "跳过次数",
                                 value: "\(record.standUpsSkipped)", unit: "次",
                                 tint: Theme.warning)
                    }

                    if let start = record.firstStartedAt, let end = record.lastActiveAt {
                        Text("首次开始 \(Format.timeOnly.string(from: start))，最后活跃 \(Format.timeOnly.string(from: end))")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.zzz")
                            .foregroundStyle(Theme.textTertiary)
                        Text("这一天没有使用记录")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - 总览

    private var summaryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(icon: "chart.pie.fill", text: "累计统计")

                HStack(spacing: 12) {
                    StatTile(icon: "checkmark.seal.fill", title: "累计打卡",
                             value: "\(state.totalCheckInDays)", unit: "天")
                    StatTile(icon: "flame.fill", title: "连续打卡",
                             value: "\(state.currentStreak)", unit: "天",
                             tint: Theme.warning)
                    StatTile(icon: "figure.walk", title: "累计起身",
                             value: "\(state.totalStandUps)", unit: "次")
                    StatTile(icon: "hourglass", title: "累计使用",
                             value: "\(state.totalActiveSeconds / 3600)", unit: "小时",
                             tint: Theme.accentSecondary)
                }

                HStack {
                    Button {
                        exportCSV()
                    } label: {
                        Label("导出 CSV", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(SoftButtonStyle())

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([Storage.shared.fileURL])
                    } label: {
                        Label("在访达中显示数据", systemImage: "folder")
                    }
                    .buttonStyle(SoftButtonStyle())

                    Spacer()
                }
            }
        }
    }

    // MARK: - 辅助

    private var isCurrentMonth: Bool {
        calendar.isDate(monthAnchor, equalTo: Date(), toGranularity: .month)
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: monthAnchor) else { return }
        if delta > 0, next > Date() { return }
        withAnimation(.easeOut(duration: 0.18)) { monthAnchor = next }
    }

    /// 生成月历格子：开头补 nil 对齐星期，长度补齐到整周
    private func monthCells() -> [Date?] {
        guard
            let interval = calendar.dateInterval(of: .month, for: monthAnchor),
            let dayCount = calendar.range(of: .day, in: .month, for: monthAnchor)?.count
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: interval.start) // 1 = 周日
        let leading = firstWeekday - calendar.firstWeekday
        let padding = (leading + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: padding)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: interval.start))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "站立提醒-打卡记录.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        // 加 BOM，Excel 打开中文表头不会乱码
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(state.exportCSV().data(using: .utf8) ?? Data())
        try? data.write(to: url)
    }
}
