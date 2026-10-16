import Foundation

/// 一条可展示的直播弹幕消息。
public struct LiveCommentItem: Identifiable, Hashable, Codable, Sendable {
    /// 消息的唯一标识。
    public let id: String

    /// 发送者的业务标识。
    public let userID: String?

    /// 展示在内容前的昵称。
    public let nickname: String

    /// 弹幕正文。
    public let content: String

    /// 发送者头像地址。
    public let avatarURL: URL?

    /// 消息的业务类型。
    public let kind: LiveCommentKind

    /// 消息的展示优先级。
    public let priority: LiveCommentPriority

    /// 消息产生的时间。
    public let timestamp: Date

    /// 创建一条直播弹幕消息。
    /// - Parameters:
    ///   - id: 消息唯一标识。默认自动生成 UUID 字符串。
    ///   - userID: 发送者业务标识。没有发送者时可传 `nil`。
    ///   - nickname: 展示昵称。
    ///   - content: 弹幕正文。
    ///   - avatarURL: 头像地址。传 `nil` 时展示占位图。
    ///   - kind: 消息业务类型。
    ///   - priority: 消息展示优先级。传 `nil` 时使用 `kind.defaultPriority`。
    ///   - timestamp: 消息产生时间。
    public init(
        id: String = UUID().uuidString,
        userID: String? = nil,
        nickname: String,
        content: String,
        avatarURL: URL? = nil,
        kind: LiveCommentKind = .comment,
        priority: LiveCommentPriority? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.userID = userID
        self.nickname = nickname
        self.content = content
        self.avatarURL = avatarURL
        self.kind = kind
        self.priority = priority ?? kind.defaultPriority
        self.timestamp = timestamp
    }
}
