import Foundation

/// 弹幕消息的展示优先级。
public enum LiveCommentPriority: Int, Codable, CaseIterable, Comparable, Sendable {
    /// 普通用户评论。
    case normal = 0

    /// 需要更醒目展示的评论，例如粉丝团或礼物消息。
    case elevated = 1

    /// 应优先保留的关键消息，例如主播或系统公告。
    case critical = 2

    /// 需要立即进入展示区的消息，例如当前用户自己发送的弹幕。
    case immediate = 3

    /// 比较两条优先级的高低。
    /// - Parameters:
    ///   - lhs: 左侧优先级。
    ///   - rhs: 右侧优先级。
    /// - Returns: 当左侧优先级低于右侧时返回 `true`。
    public static func < (lhs: LiveCommentPriority, rhs: LiveCommentPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
