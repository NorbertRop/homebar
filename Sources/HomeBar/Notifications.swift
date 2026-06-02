import Foundation
import HomeBarCore
import UserNotifications

final class UserNotificationNotifier: Notifier, @unchecked Sendable {
    var enabled = true
    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    func deviceWentOffline(name: String, entityID: String) {
        guard enabled else { return }
        post(title: "\(name) went offline", body: entityID)
    }
    func deviceRecovered(name: String, entityID: String) {
        guard enabled else { return }
        post(title: "\(name) is back online", body: entityID)
    }
    private func post(title: String, body: String) {
        let c = UNMutableNotificationContent(); c.title = title; c.body = body
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
