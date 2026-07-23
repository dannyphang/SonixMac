import Foundation

@MainActor
public class AppLogger: ObservableObject {
    public static let shared = AppLogger()

    @Published public private(set) var logs: [String] = []
    private let maxLines = 500

    private init() {}

    public func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "[\(timestamp)] \(message)"
        print(line)  // also show in Xcode console / Terminal
        logs.append(line)
        if logs.count > maxLines {
            logs.removeFirst(logs.count - maxLines)
        }
    }

    public func clear() {
        logs.removeAll()
    }
}
