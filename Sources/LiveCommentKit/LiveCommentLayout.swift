import SwiftUI

/// 评论容器的布局配置，不包含 Cell、头像、文字或未读提示的视觉样式。
public struct LiveCommentLayout {
    /// 相邻评论之间的垂直间距。
    public var rowSpacing: CGFloat
    /// 列表顶部渐隐高度，传 0 时关闭渐隐。
    public var topFadeHeight: CGFloat
    /// 滚动动画时长（秒），传 0 时立即定位。
    public var scrollAnimationDuration: Double
    /// 评论行在列表内的水平对齐方式。
    public var rowAlignment: HorizontalAlignment
    /// 自定义未读提示在评论区域内的位置。
    public var pendingAlignment: Alignment

    /// 创建评论容器布局。
    /// - Parameters:
    ///   - rowSpacing: 评论行间距，默认 6。
    ///   - topFadeHeight: 顶部渐隐高度，默认 44。
    ///   - scrollAnimationDuration: 滚动动画时长，默认 0.22 秒。
    ///   - rowAlignment: 评论行水平对齐方式，默认左对齐。
    ///   - pendingAlignment: 未读提示的位置，默认左下角。
    public init(
        rowSpacing: CGFloat = 6,
        topFadeHeight: CGFloat = 44,
        scrollAnimationDuration: Double = 0.22,
        rowAlignment: HorizontalAlignment = .leading,
        pendingAlignment: Alignment = .bottomLeading
    ) {
        self.rowSpacing = max(0, rowSpacing)
        self.topFadeHeight = max(0, topFadeHeight)
        self.scrollAnimationDuration = max(0, scrollAnimationDuration)
        self.rowAlignment = rowAlignment
        self.pendingAlignment = pendingAlignment
    }
}
