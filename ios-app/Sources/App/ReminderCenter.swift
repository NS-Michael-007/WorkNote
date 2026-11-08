import Foundation
import UserNotifications

/// 本地通知排期。iOS 的硬限制决定了这里和 Android 不是一回事：
/// - iOS 不允许 App 拦住用户划掉通知，也不能长期置顶浮层，所以「不处理就关不掉」
///   在这里降级成「时效性通知 + 没处理就按间隔反复补发」。
/// - 到点精度由系统决定（本地通知不再保证秒级），不能像 Android 那样 exact alarm。
public enum ReminderCenter {

    public static let categoryIdentifier = "WORKNOTE_REMINDER"
    public static let actionDone = "WORKNOTE_DONE"
    public static let actionDelay = "WORKNOTE_DELAY"
    public static let actionClose = "WORKNOTE_CLOSE"

    /// 一条便签最多补发几次，避免无限刷屏
    public static let maxFollowUps = 5

    public static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            // 结果不影响本地功能，拒绝授权时强提醒会静默失效，界面上要提示用户去设置里开
        }
    }

    public static func registerCategories() {
        let done = UNNotificationAction(identifier: actionDone, title: "标记完成", options: [.authenticationRequired])
        let delay = UNNotificationAction(identifier: actionDelay, title: "延后 30 分钟", options: [.authenticationRequired])
        let close = UNNotificationAction(identifier: actionClose, title: "先放着", options: [])
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [done, delay, close],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// 全量重排：先清掉所有待发通知，再按当前数据重登记。
    /// 导入备份、改设置、处理完一条之后都要调它（契约第四节第 5 条）。
    public static func reschedule(_ notes: [Note], now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for note in notes where note.status.isActive && note.remindAt > 0 {
            guard let fire = ReminderPlanner.nextFire(for: note, after: now) else { continue }
            schedule(note: note, at: fire, followUpIndex: 0)
            guard note.repeatEnabled else { continue }
            for index in 1...maxFollowUps {
                guard let next = ReminderPlanner.nextRepeat(after: fire, minutes: note.repeatMinutes * index) else { break }
                schedule(note: note, at: next, followUpIndex: index)
            }
        }
    }

    private static func schedule(note: Note, at date: Date, followUpIndex: Int) {
        let content = UNMutableNotificationContent()
        content.title = note.title
        content.body = note.remark.isEmpty ? "该处理这条便签了" : note.remark
        content.sound = reminderSound()
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = ["noteId": note.id.uuidString]
        if followUpIndex > 0 {
            content.subtitle = "还没处理，第 \(followUpIndex) 次提醒"
        }
        if #available(iOS 15.0, *) {
            // 时效性通知可以穿透专注模式；系统仍允许用户整体关掉
            content.interruptionLevel = .timeSensitive
        }

        let comps = TimeKey.calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let identifier = "note-\(note.id.uuidString)-\(followUpIndex)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// 铃声：用户挑过且在沙盒里还在，就用它；否则系统默认
    private static func reminderSound() -> UNNotificationSound {
        guard let name = RingtoneStore.shared.fileName,
              RingtoneStore.shared.currentFileURL != nil else {
            return .default
        }
        return UNNotificationSound(named: UNNotificationSoundName(rawValue: name))
    }

    public static func cancel(noteID: UUID) {        let prefix = "note-\(noteID.uuidString)-"
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            guard !ids.isEmpty else { return }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// 当前待发通知条数，给「我」页排查用
    public static func pendingCount(completion: @escaping (Int) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { completion($0.count) }
    }
}
