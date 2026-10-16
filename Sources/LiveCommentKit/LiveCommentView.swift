import SwiftUI

/// 纵向评论容器，维护滚动和跟随行为，行与未读提示由调用方提供。
///
/// SDK 为行设置稳定 ID；头像加载、行点击及未读数量格式化均由业务视图负责。
@MainActor
public struct LiveCommentView<RowContent: View, PendingContent: View>: View {
    @ObservedObject private var buffer: LiveCommentBuffer
    @State private var didRequestPauseForCurrentDrag = false

    private let layout: LiveCommentLayout
    private let content: (LiveCommentItem) -> RowContent
    private let pending: (Int, @escaping @MainActor () -> Void) -> PendingContent

    /// 创建包含自定义行和自定义未读提示的评论容器。
    /// - Parameters:
    ///   - buffer: 提供评论快照、跟随状态及实际未读数量的缓冲区。
    ///   - layout: 行间距、渐隐、滚动动画及对齐方式。
    ///   - content: 根据每条消息构造业务 Cell，可包含自己的按钮及点击手势。
    ///   - pending: 实际未读数量大于 0 时构造提示；第二个参数恢复跟随并滚动到最新消息。
    public init(
        buffer: LiveCommentBuffer,
        layout: LiveCommentLayout = LiveCommentLayout(),
        @ViewBuilder content: @escaping (LiveCommentItem) -> RowContent,
        @ViewBuilder pending: @escaping (Int, @escaping @MainActor () -> Void) -> PendingContent
    ) {
        self.buffer = buffer
        self.layout = layout
        self.content = content
        self.pending = pending
    }

    /// 评论列表与可选未读提示。
    public var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: layout.pendingAlignment) {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: layout.rowAlignment, spacing: layout.rowSpacing) {
                        ForEach(buffer.items) { item in
                            content(item).id(item.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: Alignment(horizontal: layout.rowAlignment, vertical: .center))
                }
                .defaultScrollAnchor(.bottom)
                .mask(topFadeMask)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { _ in
                            guard !didRequestPauseForCurrentDrag else { return }
                            didRequestPauseForCurrentDrag = true
                            Task { await buffer.pauseFollowingLatest() }
                        }
                        .onEnded { _ in didRequestPauseForCurrentDrag = false }
                )
                .onChange(of: buffer.latestItemID) { _, latestItemID in
                    guard buffer.isFollowingLatest, let latestItemID else { return }
                    scrollToLatest(latestItemID, proxy: proxy)
                }
                .onChange(of: buffer.immediateRevealRequest) { _, request in
                    guard let request else { return }
                    scrollToLatest(request.itemID, proxy: proxy)
                }

                if buffer.pendingCount > 0 {
                    pending(buffer.pendingCount) {
                        Task {
                            await buffer.resumeFollowingLatest()
                            if let latestItemID = buffer.latestItemID {
                                scrollToLatest(latestItemID, proxy: proxy)
                            }
                        }
                    }
                }
            }
        }
    }

    private func scrollToLatest(_ latestItemID: LiveCommentItem.ID, proxy: ScrollViewProxy) {
        guard layout.scrollAnimationDuration > 0 else {
            proxy.scrollTo(latestItemID, anchor: .bottom)
            return
        }
        withAnimation(.easeOut(duration: layout.scrollAnimationDuration)) {
            proxy.scrollTo(latestItemID, anchor: .bottom)
        }
    }

    private var topFadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: layout.topFadeHeight)
            Color.black
        }
    }
}

public extension LiveCommentView where PendingContent == EmptyView {
    /// 仅提供自定义评论行，默认不显示未读提示；数据缓冲及暂停跟随行为保持生效。
    /// - Parameters:
    ///   - buffer: 评论缓冲区。
    ///   - layout: 评论容器布局。
    ///   - content: 每条消息对应的业务 Cell。
    init(
        buffer: LiveCommentBuffer,
        layout: LiveCommentLayout = LiveCommentLayout(),
        @ViewBuilder content: @escaping (LiveCommentItem) -> RowContent
    ) {
        self.init(buffer: buffer, layout: layout, content: content, pending: { _, _ in EmptyView() })
    }
}
