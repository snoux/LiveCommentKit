import SwiftUI

/// `LiveCommentView` 的外观配置。
public struct LiveCommentStyle {
    /// 头像的边长。
    public var avatarSize: CGFloat

    /// 行内元素的水平间距。
    public var contentSpacing: CGFloat

    /// 相邻弹幕之间的垂直间距。
    public var rowSpacing: CGFloat

    /// 列表顶部内容逐渐透明的高度。
    public var topFadeHeight: CGFloat

    /// 滚动到最新弹幕时的动画时长，单位为秒。传 `0` 可关闭滚动动画。
    public var scrollAnimationDuration: Double

    /// 单条弹幕的水平内边距。
    public var horizontalPadding: CGFloat

    /// 单条弹幕的垂直内边距。
    public var verticalPadding: CGFloat

    /// 单条弹幕的圆角半径。
    public var cornerRadius: CGFloat

    /// 正文最多显示的行数。传 `nil` 时不限制。
    public var lineLimit: Int?

    /// 昵称颜色。
    public var nicknameColor: Color

    /// 正文颜色。
    public var textColor: Color

    /// 普通评论背景颜色。
    public var commentBackgroundColor: Color

    /// 当前用户自己发送的评论背景颜色。
    public var currentUserBackgroundColor: Color

    /// 主播评论背景颜色。
    public var hostBackgroundColor: Color

    /// 管理员评论背景颜色。
    public var moderatorBackgroundColor: Color

    /// 新观众欢迎消息背景颜色。
    public var viewerJoinedBackgroundColor: Color

    /// 系统公告背景颜色。
    public var systemBackgroundColor: Color

    /// 礼物消息背景颜色。
    public var giftBackgroundColor: Color

    /// 头像占位背景颜色。
    public var avatarPlaceholderColor: Color

    /// 创建弹幕视图的外观配置。
    /// - Parameters:
    ///   - avatarSize: 头像边长。
    ///   - contentSpacing: 行内元素的水平间距。
    ///   - rowSpacing: 相邻弹幕之间的垂直间距。
    ///   - topFadeHeight: 列表顶部内容逐渐透明的高度。
    ///   - scrollAnimationDuration: 滚动到最新弹幕时的动画时长，传 `0` 可关闭动画。
    ///   - horizontalPadding: 单条弹幕的水平内边距。
    ///   - verticalPadding: 单条弹幕的垂直内边距。
    ///   - cornerRadius: 单条弹幕的圆角半径。
    ///   - lineLimit: 正文最多显示的行数。
    ///   - nicknameColor: 昵称颜色。
    ///   - textColor: 正文颜色。
    ///   - commentBackgroundColor: 普通评论背景颜色。
    ///   - currentUserBackgroundColor: 当前用户自己发送的评论背景颜色。
    ///   - hostBackgroundColor: 主播评论背景颜色。
    ///   - moderatorBackgroundColor: 管理员评论背景颜色。
    ///   - viewerJoinedBackgroundColor: 新观众欢迎消息背景颜色。
    ///   - systemBackgroundColor: 系统公告背景颜色。
    ///   - giftBackgroundColor: 礼物消息背景颜色。
    ///   - avatarPlaceholderColor: 头像占位背景颜色。
    public init(
        avatarSize: CGFloat = 30,
        contentSpacing: CGFloat = 8,
        rowSpacing: CGFloat = 6,
        topFadeHeight: CGFloat = 44,
        scrollAnimationDuration: Double = 0.22,
        horizontalPadding: CGFloat = 10,
        verticalPadding: CGFloat = 7,
        cornerRadius: CGFloat = 14,
        lineLimit: Int? = 2,
        nicknameColor: Color = Color.white.opacity(0.75),
        textColor: Color = .white,
        commentBackgroundColor: Color = Color.black.opacity(0.48),
        currentUserBackgroundColor: Color = Color.cyan.opacity(0.78),
        hostBackgroundColor: Color = Color.orange.opacity(0.78),
        moderatorBackgroundColor: Color = Color.purple.opacity(0.78),
        viewerJoinedBackgroundColor: Color = Color.green.opacity(0.68),
        systemBackgroundColor: Color = Color.blue.opacity(0.78),
        giftBackgroundColor: Color = Color.pink.opacity(0.78),
        avatarPlaceholderColor: Color = Color.white.opacity(0.18)
    ) {
        self.avatarSize = avatarSize
        self.contentSpacing = contentSpacing
        self.rowSpacing = rowSpacing
        self.topFadeHeight = max(0, topFadeHeight)
        self.scrollAnimationDuration = max(0, scrollAnimationDuration)
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.cornerRadius = cornerRadius
        self.lineLimit = lineLimit
        self.nicknameColor = nicknameColor
        self.textColor = textColor
        self.commentBackgroundColor = commentBackgroundColor
        self.currentUserBackgroundColor = currentUserBackgroundColor
        self.hostBackgroundColor = hostBackgroundColor
        self.moderatorBackgroundColor = moderatorBackgroundColor
        self.viewerJoinedBackgroundColor = viewerJoinedBackgroundColor
        self.systemBackgroundColor = systemBackgroundColor
        self.giftBackgroundColor = giftBackgroundColor
        self.avatarPlaceholderColor = avatarPlaceholderColor
    }

    /// 返回指定消息类型对应的背景颜色。
    /// - Parameter kind: 消息业务类型。
    /// - Returns: 该类型应使用的背景颜色。
    public func backgroundColor(for kind: LiveCommentKind) -> Color {
        switch kind {
        case .comment:
            return commentBackgroundColor
        case .currentUser:
            return currentUserBackgroundColor
        case .viewerJoined:
            return viewerJoinedBackgroundColor
        case .host:
            return hostBackgroundColor
        case .moderator:
            return moderatorBackgroundColor
        case .system:
            return systemBackgroundColor
        case .gift:
            return giftBackgroundColor
        }
    }
}
