import Foundation

/// 弹幕消息的业务类型。
public enum LiveCommentKind: String, Codable, CaseIterable, Sendable {
    /// 普通用户评论。
    case comment

    /// 当前用户自己发送的评论。
    ///
    /// 该类别默认立即进入展示区，不受“正在翻看历史”状态阻塞。
    case currentUser

    /// 新观众进入直播间时的欢迎消息。
    case viewerJoined

    /// 主播发送的评论。
    case host

    /// 房管或管理员发送的评论。
    case moderator

    /// 系统公告。
    case system

    /// 礼物或互动事件。
    case gift

    /// 当前消息类别默认使用的优先级。
    ///
    /// 当前用户消息默认为即时优先级；主播、管理员和系统消息默认为
    /// 关键优先级；新观众欢迎消息和礼物消息默认为较高优先级。
    public var defaultPriority: LiveCommentPriority {
        switch self {
        case .comment:
            return .normal
        case .currentUser:
            return .immediate
        case .viewerJoined, .gift:
            return .elevated
        case .host, .moderator, .system:
            return .critical
        }
    }
}
