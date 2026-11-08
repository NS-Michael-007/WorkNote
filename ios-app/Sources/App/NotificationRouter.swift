import Foundation
import UserNotifications

/// 通知按钮点击后的落地逻辑。iOS 不需要常驻悬浮窗，动作全在通知里完成。
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationRouter()

    /// App 启动时注入：拿到便签 id 与动作类型后更新数据并重排
    var onAction: ((UUID, ActionType) -> Void)?

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 前台也要弹，否则用户在 App 里就看不到提醒了
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .list])
        } else {
            completionHandler([.alert, .sound])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard let raw = response.notification.request.content.userInfo["noteId"] as? String,
              let id = UUID(uuidString: raw) else { return }

        switch response.actionIdentifier {
        case ReminderCenter.actionDone:
            onAction?(id, .done)
        case ReminderCenter.actionDelay:
            onAction?(id, .delay)
        case ReminderCenter.actionClose:
            onAction?(id, .close)
        default:
            // 用户直接把通知划掉：在 iOS 上拦不住，只能记为「看过但没处理」，保持待处理状态
            onAction?(id, .close)
        }
    }
}
