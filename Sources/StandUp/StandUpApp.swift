import SwiftUI
import AppKit

@main
struct StandUpApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        Window("站立提醒", id: "main") {
            ContentView()
                .environmentObject(state)
        }
        .defaultSize(width: 680, height: 840)
        .commands {
            // 去掉「新建」等对本 App 无意义的菜单项
            CommandGroup(replacing: .newItem) {}
            CommandMenu("提醒") {
                Button(state.phase == .idle ? "开始久坐提醒" : "停止计时") {
                    state.toggle()
                }
                .keyboardShortcut("s", modifiers: [.command])

                Button("立即提醒一次") {
                    state.triggerNow()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(state.phase == .standing)
            }
        }

        MenuBarExtra {
            MenuBarPanel()
                .environmentObject(state)
        } label: {
            Image(systemName: menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIcon: String {
        switch state.phase {
        case .idle:     return "figure.stand"
        case .counting: return "timer"
        case .standing: return "figure.walk.motion"
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    /// 关掉主窗口后 App 继续留在菜单栏里计时
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppState.current?.persistNow()
    }
}

// MARK: - 菜单栏面板

struct MenuBarPanel: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }

            GoalBar(progress: state.goalProgress)

            HStack(spacing: 10) {
                Label("\(state.today.activeSeconds / 60) 分钟", systemImage: "clock")
                Label("\(state.today.standUpsCompleted) 次起身", systemImage: "figure.walk")
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.textSecondary)

            Divider()

            VStack(spacing: 8) {
                Button {
                    state.toggle()
                } label: {
                    Label(
                        state.phase == .idle ? "开始久坐提醒" : "停止计时",
                        systemImage: state.phase == .idle ? "play.fill" : "stop.fill"
                    )
                }
                .buttonStyle(PrimaryButtonStyle(tint: state.phase == .idle ? Theme.accent : Theme.textSecondary, wide: true))

                if state.phase == .standing {
                    Button("我已起身，完成打卡") {
                        state.completeStandUp()
                    }
                    .buttonStyle(SoftButtonStyle())
                }

                HStack(spacing: 8) {
                    Button("打开主界面") {
                        openWindow(id: "main")
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    .buttonStyle(SoftButtonStyle())

                    Button("退出") {
                        NSApp.terminate(nil)
                    }
                    .buttonStyle(SoftButtonStyle())
                }
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    private var title: String {
        switch state.phase {
        case .idle:     return "未开始计时"
        case .counting: return "距离下次提醒 \(Format.clock(state.secondsUntilFire))"
        case .standing: return "起身活动中 \(Format.clock(state.secondsUntilStandEnds))"
        }
    }

    private var subtitle: String {
        "今日目标 \(state.today.standUpsCompleted) / \(state.settings.dailyGoal) 次 · 连续打卡 \(state.currentStreak) 天"
    }
}
