import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case today = "今天"
    case history = "记录"
    case settings = "设置"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .today: return "timer"
        case .history: return "calendar"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var state: AppState
    @State private var tab: Tab = .today

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    Group {
                        switch tab {
                        case .today:    DashboardView()
                        case .history:  HistoryView()
                        case .settings: SettingsView()
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 4)
                    .padding(.bottom, 26)
                }
            }
        }
        .frame(minWidth: 620, idealWidth: 680, minHeight: 640, idealHeight: 820)
    }

    // MARK: - 顶部栏

    private var header: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                appMark

                VStack(alignment: .leading, spacing: 2) {
                    Text("站立提醒")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(statusLine)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                StreakBadge(days: state.currentStreak)
            }

            tabBar
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var appMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.accent, Theme.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "figure.stand")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 38, height: 38)
        .shadow(color: Theme.accent.opacity(0.35), radius: 8, y: 3)
    }

    private var statusLine: String {
        switch state.phase {
        case .idle:
            return "点击「开始久坐提醒」即可打卡今天"
        case .counting:
            if let fireAt = state.nextFireAt {
                return "计时中 · 下次提醒 \(Format.timeOnly.string(from: fireAt))"
            }
            return "计时中"
        case .standing:
            return "起身活动中 · 剩余 \(Format.clock(state.secondsUntilStandEnds))"
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { item in
                let isSelected = item == tab
                Button {
                    withAnimation(.easeOut(duration: 0.16)) { tab = item }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.system(size: 11, weight: .medium))
                        Text(item.rawValue)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    }
                    .foregroundStyle(isSelected ? Color.white : Theme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? Theme.accent : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(4)
        .background(Capsule(style: .continuous).fill(Theme.track.opacity(0.55)))
    }
}
