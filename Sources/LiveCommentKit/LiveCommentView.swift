import SwiftUI

/// 位于直播画面左下角、纵向滚动的评论弹幕视图。
public struct LiveCommentView: View {
    @ObservedObject private var buffer: LiveCommentBuffer
    @State private var didRequestPauseForCurrentDrag = false

    private let style: LiveCommentStyle
    private let showsAvatar: Bool
    private let showsJumpToLatestButton: Bool
    private let onCommentTap: ((LiveCommentItem) -> Void)?

    /// 创建一个直播弹幕列表。
    /// - Parameters:
    ///   - buffer: 持有弹幕数据及跟随状态的有界缓冲区。
    ///   - style: 弹幕外观配置。
    ///   - showsAvatar: 是否展示发送者头像。
    ///   - showsJumpToLatestButton: 用户上滑后是否展示“新消息”按钮。
    ///   - onCommentTap: 点击某条弹幕后的回调。
    public init(
        buffer: LiveCommentBuffer,
        style: LiveCommentStyle = LiveCommentStyle(),
        showsAvatar: Bool = true,
        showsJumpToLatestButton: Bool = true,
        onCommentTap: ((LiveCommentItem) -> Void)? = nil
    ) {
        self.buffer = buffer
        self.style = style
        self.showsAvatar = showsAvatar
        self.showsJumpToLatestButton = showsJumpToLatestButton
        self.onCommentTap = onCommentTap
    }

    /// 弹幕列表的 SwiftUI 内容。
    public var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomLeading) {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: style.rowSpacing) {
                        ForEach(buffer.items) { item in
                            LiveCommentRow(
                                item: item,
                                style: style,
                                showsAvatar: showsAvatar
                            )
                            .id(item.id)
                            .onTapGesture {
                                onCommentTap?(item)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .mask(topFadeMask)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { _ in
                            guard !didRequestPauseForCurrentDrag else { return }
                            didRequestPauseForCurrentDrag = true
                            Task {
                                await buffer.pauseFollowingLatest()
                            }
                        }
                        .onEnded { _ in
                            didRequestPauseForCurrentDrag = false
                        }
                )
                .onChange(of: buffer.latestItemID) { _, latestItemID in
                    guard buffer.isFollowingLatest, let latestItemID else { return }
                    scrollToLatest(latestItemID, proxy: proxy)
                }
                .onChange(of: buffer.immediateRevealRequest) { _, request in
                    guard let request else { return }
                    scrollToLatest(request.itemID, proxy: proxy)
                }

                if showsJumpToLatestButton && buffer.pendingCount > 0 {
                    Button {
                        Task {
                            await buffer.resumeFollowingLatest()
                            if let latestItemID = buffer.latestItemID {
                                scrollToLatest(latestItemID, proxy: proxy)
                            }
                        }
                    } label: {
                        Text(buffer.pendingCountBadgeText)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.black.opacity(0.72))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 4)
                    .accessibilityHint("轻点后恢复自动滚动到最新弹幕")
                }
            }
        }
    }

    private func scrollToLatest(
        _ latestItemID: LiveCommentItem.ID,
        proxy: ScrollViewProxy
    ) {
        guard style.scrollAnimationDuration > 0 else {
            proxy.scrollTo(latestItemID, anchor: .bottom)
            return
        }

        withAnimation(.easeOut(duration: style.scrollAnimationDuration)) {
            proxy.scrollTo(latestItemID, anchor: .bottom)
        }
    }

    private var topFadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: style.topFadeHeight)

            Color.black
        }
    }

}
