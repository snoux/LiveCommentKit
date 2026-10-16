import Foundation

/// 有界弹幕缓冲区达到容量上限时的淘汰策略。
public enum LiveCommentTrimmingPolicy: Sendable {
    /// 始终淘汰最早进入缓冲区的消息。
    case oldest

    /// 优先淘汰较低优先级中最早进入缓冲区的消息。
    case lowestPriorityThenOldest
}
