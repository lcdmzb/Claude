import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 18) {
            timerCard
            todayCard
            weeklyCard
        }
    }

    // MARK: - 计时卡片

    private var timerCard: some View {
        Card(padding: 26) {
            VStack(spacing: 20) {
                ProgressRing(
                    progress: state.ringProgress,
                    primaryText: ringPrimaryText,
                    secondaryText: ringSecondaryText,
                    caption: ringCaption,
                    tint: state.phase == .standing ? Theme.warning : Theme.accent,
                    isActive: state.phase != .idle
                )

                controls
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var ringPrimaryText: String {
        switch state.phase {
        case .idle:     return Format.clock(state.settings.intervalMinutes * 60)
        case .counting: return Format.clock(state.secondsUntilFire)
        case .standing: return Format.clock(state.secondsUntilStandEnds)
        }
    }

    private var ringSecondaryText: String {
        switch state.phase {
        case .idle:     return "未开始"
        case .counting: return "距离下次提醒"
        case .standing: return "起身活动中"
        }
    }

    private var ringCaption: String {
        switch state.phase {
        case .idle:
            return "每 \(state.settings.intervalMinutes) 分钟提醒一次"
        case .counting:
            guard let fireAt = state.nextFireAt else { return "" }
            return "将于 \(Format.timeOnly.string(from: fireAt)) 响铃"
        case .standing:
            return "站起来，动一动"
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    state.toggle()
                } label: {
                    Label(
                        state.phase == .idle ? "开始久坐提醒" : "停止",
                        systemImage: state.phase == .idle ? "play.fill" : "stop.fill"
                    )
                }
                .buttonStyle(PrimaryButtonStyle(tint: state.phase == .idle ? Theme.accent : Theme.textSecondary))

                if state.phase == .counting {
                    Button {
                        state.triggerNow()
                    } label: {
                        Label("立即提醒", systemImage: "bell.badge")
                    }
                    .buttonStyle(SoftButtonStyle())
                }

                if state.phase == .standing {
                    Button {
                        state.completeStandUp()
                    } label: {
                        Label("完成打卡", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.accent))
                }
            }

            if state.phase != .idle {
                Text("本次已计时 \(Format.duration(state.sessionSeconds))")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    // MARK: - 今日卡片

    private var todayCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(
                    icon: "sun.max.fill",
                    text: "今天",
                    trailing: Format.dayTitle.string(from: Date())
                )

                HStack(spacing: 12) {
                    StatTile(icon: "clock.fill", title: "使用时长",
                             value: "\(state.today.activeSeconds / 60)", unit: "分钟")
                    StatTile(icon: "figure.walk", title: "完成起身",
                             value: "\(state.today.standUpsCompleted)", unit: "次")
                    StatTile(icon: "bell.fill", title: "提醒次数",
                             value: "\(state.today.remindersFired)", unit: "次",
                             tint: Theme.accentSecondary)
                    StatTile(icon: "figure.stand", title: "站立时长",
                             value: "\(state.today.standSeconds / 60)", unit: "分钟",
                             tint: Theme.warning)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("今日目标")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("\(state.today.standUpsCompleted) / \(state.settings.dailyGoal) 次起身")
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(state.goalProgress >= 1 ? Theme.accent : Theme.textSecondary)
                    }
                    GoalBar(progress: state.goalProgress)

                    if state.goalProgress >= 1 {
                        Label("今日目标已完成，做得很好！", systemImage: "party.popper.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }

    // MARK: - 一周趋势

    private var weeklyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(icon: "chart.bar.fill", text: "最近 7 天使用时长", trailing: "单位：分钟")
                WeeklyBars(days: state.recentDays(7)) { record in
                    (record?.activeSeconds ?? 0) / 60
                }
            }
        }
    }
}
