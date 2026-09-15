import Foundation

final class Logger: @unchecked Sendable {
    static let shared = Logger()
    private let queue = DispatchQueue(label: "expo.libmpv.logger")
    private init() {}

    func log(_ message: String, type: String = "General") {
        queue.async {
            #if DEBUG
            print("[libmpv][\(type)] \(message)")
            #endif
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("LoggerNotification"),
                    object: nil,
                    userInfo: ["message": message, "type": type, "timestamp": Date()]
                )
            }
        }
    }
}
