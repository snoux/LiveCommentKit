import SwiftUI

/// 展示单条直播弹幕的 SwiftUI 视图。
public struct LiveCommentRow: View {
    private let item: LiveCommentItem
    private let style: LiveCommentStyle
    private let showsAvatar: Bool

    /// 创建单条直播弹幕视图。
    /// - Parameters:
    ///   - item: 要展示的弹幕消息。
    ///   - style: 弹幕外观配置。
    ///   - showsAvatar: 是否展示发送者头像。
    public init(
        item: LiveCommentItem,
        style: LiveCommentStyle = LiveCommentStyle(),
        showsAvatar: Bool = true
    ) {
        self.item = item
        self.style = style
        self.showsAvatar = showsAvatar
    }

    /// 单条弹幕视图的 SwiftUI 内容。
    public var body: some View {
        HStack(alignment: .center, spacing: style.contentSpacing) {
            if showsAvatar {
                LiveCommentAvatar(
                    url: item.avatarURL,
                    size: style.avatarSize,
                    placeholderColor: style.avatarPlaceholderColor
                )
            }

            Group {
                Text(item.nickname + "  ")
                    .foregroundColor(style.nicknameColor)
                    .fontWeight(.semibold)
                + Text(item.content)
                    .foregroundColor(style.textColor)
            }
            .font(.subheadline)
            .lineLimit(style.lineLimit)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
        .background(style.backgroundColor(for: item.kind))
        .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.nickname + "，" + item.content)
    }
}
