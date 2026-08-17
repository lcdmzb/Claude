import SwiftUI

// MARK: - 统计小卡片

struct StatTile: View {
    let icon: String
    let title: String
    let value: String
    var unit: String? = nil
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                if let unit {
                    Text(unit)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.track.opacity(0.55))
        )
    }
}

// MARK: - 进度条

struct GoalBar: View {
    let progress: Double
    var tint: Color = Theme.accent

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.75), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, geo.size.width * min(max(progress, 0), 1)))
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
            }
        }
        .frame(height: 10)
    }
}

// MARK: - 主进度环

struct ProgressRing: View {
    let progress: Double
    let primaryText: String
    let secondaryText: String
    let caption: String
    var tint: Color = Theme.accent
    var isActive: Bool = true

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.track, lineWidth: 16)

            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(
                    AngularGradient(
                        colors: [tint.opacity(0.55), tint, Theme.accentSecondary, tint],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.9), value: progress)
                .opacity(isActive ? 1 : 0.35)

            VStack(spacing: 6) {
                Text(secondaryText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Text(primaryText)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(width: 220, height: 220)
    }
}

// MARK: - 近 7 天柱状图

struct WeeklyBars: View {
    let days: [(date: Date, record: DayRecord?)]
    /// 每根柱子的取值（分钟）
    let valueFor: (DayRecord?) -> Int

    private var maxValue: Int {
        max(30, days.map { valueFor($0.record) }.max() ?? 0)
    }

    private static let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]

    private func weekdayLabel(_ date: Date) -> String {
        let index = Calendar.current.component(.weekday, from: date) - 1
        return Self.weekdaySymbols[min(max(index, 0), 6)]
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(days, id: \.date) { item in
                let value = valueFor(item.record)
                let ratio = Double(value) / Double(maxValue)
                let isToday = Calendar.current.isDateInToday(item.date)

                VStack(spacing: 8) {
                    Text(value > 0 ? "\(value)" : "")
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textTertiary)

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            value > 0
                                ? LinearGradient(
                                    colors: [Theme.accent.opacity(0.55), Theme.accent],
                                    startPoint: .bottom, endPoint: .top)
                                : LinearGradient(colors: [Theme.track, Theme.track],
                                                 startPoint: .bottom, endPoint: .top)
                        )
                        .frame(height: max(4, 96 * ratio))

                    Text(weekdayLabel(item.date))
                        .font(.system(size: 11, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? Theme.accent : Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 150, alignment: .bottom)
    }
}

// MARK: - 分区标题

struct SectionTitle: View {
    let icon: String
    let text: String
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}

// MARK: - 连续打卡徽章

struct StreakBadge: View {
    let days: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12))
                .foregroundStyle(days > 0 ? Theme.warning : Theme.textTertiary)
            Text(days > 0 ? "连续打卡 \(days) 天" : "今天开始打卡")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(days > 0 ? Theme.textPrimary : Theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(Theme.track.opacity(0.7)))
    }
}
