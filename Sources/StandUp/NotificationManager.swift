import Foundation
import UserNotifications
import AppKit

/// 系统通知中心的封装。
///
/// UNUserNotificationCenter 只有在「打包成 .app 且有 bundle identifier」时才可用，
/// 直接 `swift run` 出来的裸可执行文件会崩溃，所以这里做了可用性判断：
/// 不可用时静默降级，覆盖层提醒依旧正常工作。
final class NotificationManager {
    static let shared = NotificationManager()

    private var didRequestAuthorization = false
    private var isAuthorized = false

    private lazy var isAvailable: Bool = {
        guard Bundle.main.bundleIdentifier != nil else { return false }
        return Bundle.main.bundleURL.pathExtension == "app"
    }()

    private init() {}

    func requestAuthorizationIfNeeded(enabled: Bool) {
        guard enabled, isAvailable, !didRequestAuthorization else { return }
        didRequestAuthorization = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            self?.isAuthorized = granted
        }
    }

    func postReminder(standSeconds: Int) {
        guard isAvailable else { return }

        let content = UNMutableNotificationContent()
        content.title = "该起身活动啦"
        content.subtitle = "久坐提醒"
        content.body = "站起来走动 \(Format.duration(standSeconds))，伸展一下肩颈和腰背。"
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "standup.reminder.\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
