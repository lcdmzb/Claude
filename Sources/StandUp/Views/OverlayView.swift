import SwiftUI

/// 提醒触发时铺满屏幕的醒目提示
struct OverlayView: View {
    @EnvironmentObject private var state: AppState
    let isPrimary: Bool

    @State private var breathe = false
    @State private var appeared = false
    @State private var tip: String = ActivityTips.random()

    /// 显式声明构造器：结构体里有 private 属性时，编译器合成的逐成员构造器也是 private，
    /// 跨文件（OverlayController）就没法调用了。
    init(isPrimary: Bool = true) {
        self.isPrimary = isPrimary
    }

    private var remaining: Int { state.secondsUntilStandEnds }

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 26) {
                header
                ring
                tipCard
                if isPrimary { actions }
                footer
            }
            .padding(44)
            .frame(maxWidth: 520)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 40, y: 18)
            )
            .scaleEffect(appeared ? 1 : 0.92)
            .opacity(appeared ? 1 : 0)
        }
        .ignoresSafeArea()
        .onAppear {
            tip = ActivityTips.random()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { appeared = true }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { breathe = true }
        }
    }

    // MARK: - 背景

    private var backdrop: some View {
        ZStack {
            Color.black.opacity(0.55)

            // 两团缓慢呼吸的光晕，比纯色遮罩更柔和
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.accent.opacity(0.55), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 460
                    )
                )
                .frame(width: 900, height: 900)
                .offset(x: -260, y: -200)
                .scaleEffect(breathe ? 1.12 : 0.92)
                .blur(radius: 30)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.accentSecondary.opacity(0.45), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 420
                    )
                )
                .frame(width: 820, height: 820)
                .offset(x: 280, y: 220)
                .scaleEffect(breathe ? 0.94 : 1.10)
                .blur(radius: 30)
        }
    }

    // MARK: - 内容

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(breathe ? 1.06 : 0.96)

            Text("该起身活动啦")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)

            Text("你已经连续坐了 \(state.settings.intervalMinutes) 分钟")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: 12)

            Circle()
                .trim(from: 0, to: max(0.002, state.ringProgress))
                .stroke(
                    Theme.ringGradient,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.9), value: state.ringProgress)

            VStack(spacing: 4) {
                Text(Format.clock(remaining))
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("建议活动时长")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(width: 190, height: 190)
    }

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(Theme.warning)
                .font(.system(size: 15))
                .padding(.top, 1)
            Text(tip)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                state.completeStandUp()
            } label: {
                Label("我已起身，完成打卡", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle(tint: Theme.accent, wide: true))
            .keyboardShortcut(.defaultAction)

            HStack(spacing: 12) {
                Button("稍后 \(state.settings.snoozeMinutes) 分钟") {
                    state.snooze()
                }
                .buttonStyle(SoftButtonStyle(tint: .white))
                .keyboardShortcut(.cancelAction)

                Button("本次跳过") {
                    state.skipStandUp()
                }
                .buttonStyle(SoftButtonStyle(tint: .white.opacity(0.8)))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "target")
                .font(.system(size: 11))
            Text("今日已完成 \(state.today.standUpsCompleted) / \(state.settings.dailyGoal) 次")
                .font(.system(size: 12))
        }
        .foregroundStyle(.white.opacity(0.55))
    }
}

enum ActivityTips {
    static let all = [
        "站起来伸个懒腰，双手向上举过头顶，保持 15 秒再放下。",
        "转动肩膀：向前绕 10 圈，向后绕 10 圈，缓解肩颈僵硬。",
        "走到窗边，看 20 米以外的地方 20 秒，让眼睛也休息一下。",
        "靠墙站立 1 分钟：后脑、肩胛、臀部贴墙，找回正确体态。",
        "做 10 个深蹲或原地高抬腿，让下肢血液循环起来。",
        "去接一杯水吧，补水的同时也顺便走动了几十步。",
        "颈部拉伸：头缓慢向左右各侧倾 15 秒，动作要轻。",
        "扩胸运动 10 次，把久坐含胸的姿势舒展开。",
        "踮脚尖 20 下，激活小腿肌肉，预防久坐水肿。",
        "深呼吸 5 次：吸气 4 秒、屏息 4 秒、呼气 6 秒。"
    ]

    static func random() -> String {
        all.randomElement() ?? all[0]
    }
}
