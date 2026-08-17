import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @State private var showClearConfirm = false

    var body: some View {
        VStack(spacing: 18) {
            rhythmCard
            alertCard
            generalCard
            dataCard
        }
    }

    // MARK: - 提醒节奏

    private var rhythmCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle(icon: "timer", text: "提醒节奏")

                SettingRow(title: "提醒间隔", subtitle: "久坐多久提醒一次") {
                    PresetPicker(
                        options: [30, 45, 60, 90, 120],
                        suffix: "分钟",
                        selection: $state.settings.intervalMinutes
                    )
                }

                Divider().opacity(0.4)

                SettingRow(title: "活动时长", subtitle: "每次建议起身活动多久") {
                    PresetPicker(
                        options: [60, 180, 300, 600],
                        labels: ["1 分钟", "3 分钟", "5 分钟", "10 分钟"],
                        selection: $state.settings.standSeconds
                    )
                }

                Divider().opacity(0.4)

                SettingRow(title: "稍后提醒", subtitle: "点击「稍后」后延迟多久") {
                    PresetPicker(
                        options: [3, 5, 10, 15],
                        suffix: "分钟",
                        selection: $state.settings.snoozeMinutes
                    )
                }

                Divider().opacity(0.4)

                SettingRow(title: "每日目标", subtitle: "每天希望完成的起身次数") {
                    Stepper(value: $state.settings.dailyGoal, in: 1...24) {
                        Text("\(state.settings.dailyGoal) 次")
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
            }
        }
    }

    // MARK: - 提醒方式

    private var alertCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle(icon: "bell.badge.fill", text: "提醒方式")

                Toggle(isOn: $state.settings.soundEnabled) {
                    Text("播放提醒音乐")
                        .font(.system(size: 13))
                }
                .toggleStyle(.switch)
                .tint(Theme.accent)

                if state.settings.soundEnabled {
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                        Slider(value: $state.settings.volume, in: 0...1)
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                        Button {
                            ChimePlayer.shared.play(volume: state.settings.volume)
                        } label: {
                            Label("试听", systemImage: "play.circle")
                        }
                        .buttonStyle(SoftButtonStyle())
                    }
                }

                Divider().opacity(0.4)

                Toggle(isOn: $state.settings.overlayEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("全屏醒目提醒")
                            .font(.system(size: 13))
                        Text("提醒时在所有显示器上覆盖一层提示卡片")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .toggleStyle(.switch)
                .tint(Theme.accent)

                Toggle(isOn: $state.settings.notificationsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("系统通知")
                            .font(.system(size: 13))
                        Text("同时在通知中心推送一条提醒")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .toggleStyle(.switch)
                .tint(Theme.accent)

                Toggle(isOn: $state.settings.autoDismissOverlay) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("活动结束后自动关闭提醒")
                            .font(.system(size: 13))
                        Text("关闭后需要手动点击「完成打卡」才会继续计时")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .toggleStyle(.switch)
                .tint(Theme.accent)
            }
        }
    }

    // MARK: - 通用

    private var generalCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle(icon: "gearshape.fill", text: "通用")

                Toggle(isOn: $state.settings.autoStartOnLaunch) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("打开 App 时自动开始计时")
                            .font(.system(size: 13))
                        Text("省去每次手动点击「开始」")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .toggleStyle(.switch)
                .tint(Theme.accent)

                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                    Text("想开机自启：系统设置 → 通用 → 登录项，把「站立提醒」加进去。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    // MARK: - 数据

    private var dataCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(icon: "externaldrive.fill", text: "数据")

                Text(Storage.shared.fileURL.path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                    .textSelection(.enabled)
                    .lineLimit(2)

                HStack {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([Storage.shared.fileURL])
                    } label: {
                        Label("在访达中显示", systemImage: "folder")
                    }
                    .buttonStyle(SoftButtonStyle())

                    Spacer()

                    Button {
                        showClearConfirm = true
                    } label: {
                        Label("清空所有打卡记录", systemImage: "trash")
                    }
                    .buttonStyle(SoftButtonStyle(tint: .red))
                }
            }
        }
        .alert("确定要清空所有打卡记录吗？", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) { state.clearAllRecords() }
        } message: {
            Text("所有历史日期、使用时长和起身次数都会被删除，且无法恢复。建议先导出 CSV 备份。")
        }
    }
}

// MARK: - 设置行

private struct SettingRow<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 12)
            content
        }
    }
}

// MARK: - 预设值选择器

private struct PresetPicker: View {
    let options: [Int]
    var labels: [String]? = nil
    var suffix: String = ""
    @Binding var selection: Int

    private func label(_ index: Int) -> String {
        if let labels, index < labels.count { return labels[index] }
        return suffix.isEmpty ? "\(options[index])" : "\(options[index]) \(suffix)"
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options.indices, id: \.self) { index in
                let value = options[index]
                let isSelected = value == selection

                Button {
                    selection = value
                } label: {
                    Text(label(index))
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? Color.white : Theme.textSecondary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? Theme.accent : Theme.track)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
