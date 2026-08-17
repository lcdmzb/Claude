import AVFoundation
import AppKit

/// 程序合成的提醒音：C 大调五声上行琶音 + 温柔下行收尾，钟琴/风铃音色。
///
/// 不依赖任何外部音频文件，因此打包出来的 App 是完全自包含的，
/// 也不存在音频素材的版权问题。
final class ChimePlayer {
    static let shared = ChimePlayer()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private var buffer: AVAudioPCMBuffer?
    private var isConfigured = false

    private init() {}

    // MARK: - 对外接口

    func play(volume: Double) {
        let level = Float(min(max(volume, 0), 1))
        guard level > 0 else { return }

        guard configureIfNeeded(), let buffer else {
            fallback(volume: level)
            return
        }

        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                fallback(volume: level)
                return
            }
        }

        player.stop()
        player.volume = level
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        player.play()
    }

    /// 站立结束时的一声轻柔提示（比提醒音短、更低）
    func playSoftDing(volume: Double) {
        let sound = NSSound(named: NSSound.Name("Tink")) ?? NSSound(named: NSSound.Name("Pop"))
        sound?.volume = Float(min(max(volume, 0), 1))
        sound?.play()
    }

    func stop() {
        player.stop()
    }

    // MARK: - 引擎准备

    private func configureIfNeeded() -> Bool {
        if isConfigured { return buffer != nil }
        isConfigured = true

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            return false
        }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()

        // 插拔耳机、切换到显示器音箱等会让引擎停摆，连接也需要重建
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.engine.connect(self.player, to: self.engine.mainMixerNode, format: format)
            try? self.engine.start()
        }

        buffer = makeChimeBuffer(format: format)
        return buffer != nil
    }

    private func fallback(volume: Float) {
        let sound = NSSound(named: NSSound.Name("Glass")) ?? NSSound(named: NSSound.Name("Ping"))
        sound?.volume = volume
        sound?.play()
    }

    // MARK: - 合成

    private struct Note {
        let frequency: Double   // 基频
        let start: Double       // 起始时间（秒）
        let gain: Double        // 音量
        let decay: Double       // 衰减时间常数（秒）
        let pan: Double         // -1 左 ~ +1 右
    }

    private func makeChimeBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let duration = 4.2
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channels = buf.floatChannelData else { return nil }
        buf.frameLength = frameCount

        // C5 E5 G5 C6 上行，再 G5 E5 C5 温柔回落
        let notes: [Note] = [
            Note(frequency: 523.25, start: 0.00, gain: 0.85, decay: 1.5, pan: -0.25),
            Note(frequency: 659.25, start: 0.20, gain: 0.80, decay: 1.5, pan: 0.10),
            Note(frequency: 783.99, start: 0.40, gain: 0.78, decay: 1.6, pan: -0.10),
            Note(frequency: 1046.50, start: 0.60, gain: 0.72, decay: 1.8, pan: 0.25),
            Note(frequency: 783.99, start: 1.05, gain: 0.55, decay: 1.6, pan: 0.20),
            Note(frequency: 659.25, start: 1.28, gain: 0.52, decay: 1.8, pan: -0.20),
            Note(frequency: 523.25, start: 1.52, gain: 0.60, decay: 2.6, pan: 0.00),
            // 底部铺一层很轻的低音，让整体更温暖
            Note(frequency: 261.63, start: 0.00, gain: 0.22, decay: 3.2, pan: 0.00),
            Note(frequency: 392.00, start: 0.60, gain: 0.16, decay: 2.8, pan: 0.00)
        ]

        // 钟琴音色：基频 + 若干泛音，泛音越高衰减越快
        let partials: [(ratio: Double, gain: Double, decayScale: Double)] = [
            (1.00, 1.00, 1.00),
            (2.00, 0.42, 0.62),
            (3.01, 0.22, 0.45),
            (4.21, 0.11, 0.32),
            (5.43, 0.05, 0.24)
        ]

        var left = [Double](repeating: 0, count: Int(frameCount))
        var right = [Double](repeating: 0, count: Int(frameCount))
        let attack = 0.006  // 6ms 起音，避免爆音

        for note in notes {
            let startFrame = Int(note.start * sampleRate)
            guard startFrame < Int(frameCount) else { continue }
            // 等功率声像
            let angle = (note.pan + 1) * 0.25 * Double.pi
            let gainL = cos(angle)
            let gainR = sin(angle)

            for frame in startFrame..<Int(frameCount) {
                let t = Double(frame - startFrame) / sampleRate

                // 起音 + 指数衰减包络。
                // 提前退出只能看衰减项：起音项在第一帧本来就是 0，
                // 拿它判断会让整个音符一个采样都写不进去（全曲静音）。
                let releaseEnv = exp(-t / note.decay)
                if releaseEnv < 0.0001 { break }
                let attackEnv = t < attack ? t / attack : 1.0
                let env = attackEnv * releaseEnv

                var sample = 0.0
                for p in partials {
                    let partialEnv = exp(-t / (note.decay * p.decayScale))
                    sample += p.gain * partialEnv * sin(2 * Double.pi * note.frequency * p.ratio * t)
                }
                sample *= note.gain * env * 0.28

                left[frame] += sample * gainL
                right[frame] += sample * gainR
            }
        }

        // 整体淡出，确保结尾干净
        let fadeFrames = Int(0.25 * sampleRate)
        for i in 0..<fadeFrames {
            let idx = Int(frameCount) - fadeFrames + i
            guard idx >= 0 else { continue }
            let k = 1.0 - Double(i) / Double(fadeFrames)
            left[idx] *= k
            right[idx] *= k
        }

        // 归一化到 0.85 峰值，防止削波。
        // 万一合成结果异常安静，宁可返回 nil 退回系统提示音，
        // 也不要让用户听到一段「正在播放的无声」。
        var peak = 0.0
        for i in 0..<Int(frameCount) {
            peak = max(peak, max(abs(left[i]), abs(right[i])))
        }
        guard peak > 0.001 else { return nil }
        let scale = 0.85 / peak

        for i in 0..<Int(frameCount) {
            channels[0][i] = Float(left[i] * scale)
            channels[1][i] = Float(right[i] * scale)
        }

        return buf
    }
}
