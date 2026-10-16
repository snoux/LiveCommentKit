import SDWebImage
import SDWebImageSwiftUI
import SwiftUI

/// 使用 SDWebImageSwiftUI 加载并缓存的圆形直播头像。
public struct LiveCommentAvatar: View {
    @Environment(\.displayScale) private var displayScale

    private let url: URL?
    private let size: CGFloat
    private let placeholderColor: Color

    /// 创建一个直播头像视图。
    /// - Parameters:
    ///   - url: 头像地址。传 `nil` 时仅展示占位图。
    ///   - size: 头像的显示边长。
    ///   - placeholderColor: 加载中或加载失败时的占位背景颜色。
    public init(
        url: URL?,
        size: CGFloat = 30,
        placeholderColor: Color = Color.white.opacity(0.18)
    ) {
        self.url = url
        self.size = size
        self.placeholderColor = placeholderColor
    }

    /// 头像视图的 SwiftUI 内容。
    public var body: some View {
        WebImage(
            url: url,
            options: [.retryFailed, .scaleDownLargeImages],
            context: [
                .imageThumbnailPixelSize: CGSize(
                    width: size * displayScale,
                    height: size * displayScale
                )
            ]
        ) { image in
            image.resizable()
        } placeholder: {
            ZStack {
                Circle()
                    .fill(placeholderColor)
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
            }
        }
        .scaledToFill()
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
