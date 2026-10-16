import Combine
import Foundation

struct LiveCommentRevealRequest: Equatable {
    let itemID: LiveCommentItem.ID
    let revision: UInt64
}

/// 将异步弹幕处理结果发布给 SwiftUI 的有界缓冲区。
///
/// 去重、优先级排序、容量淘汰和待加载消息合并均在独立 actor 中执行。
/// 主线程只接收已经处理完成且数量受 `capacity` 限制的状态快照。
///
/// 队列不会按固定批次进行“等量进出”。只有当实际数量超过
/// `capacity` 时，处理器才会移除溢出的那部分消息。
@MainActor
public final class LiveCommentBuffer: ObservableObject {
    /// 当前仍保留在展示队列中的消息。
    @Published public private(set) var items: [LiveCommentItem]

    /// 用户暂停跟随最新消息后实际收到的新消息数量。
    @Published public private(set) var pendingCount: Int

    /// 当前是否自动跟随最新消息。
    @Published public private(set) var isFollowingLatest: Bool

    @Published private(set) var immediateRevealRequest: LiveCommentRevealRequest?

    /// 展示 Deque 和待加载 Deque 各自最多保留的消息数量。
    ///
    /// 该值是可配置上限，不是固定窗口大小或批次大小。
    public let capacity: Int

    /// 缓冲区达到容量上限时使用的淘汰策略。
    public let trimmingPolicy: LiveCommentTrimmingPolicy

    private nonisolated let processor: LiveCommentProcessor
    private var lastAppliedRevision: UInt64

    /// 当前最后一条消息的唯一标识。
    public var latestItemID: LiveCommentItem.ID? {
        items.last?.id
    }

    /// 适合直接展示在待加载按钮上的文案。
    ///
    /// 待加载数量最大显示为 `99+`，但 `pendingCount` 仍保留实际收到的消息数量。
    public var pendingCountBadgeText: String {
        pendingCount > 99 ? "99+条新消息" : "\(pendingCount)条新消息"
    }

    /// 创建一个异步处理的有界弹幕缓冲区。
    /// - Parameters:
    ///   - capacity: 展示队列和待加载区各自最多保留的消息数量。小于 1 的值会被修正为 1。
    ///   - trimmingPolicy: 达到容量上限后的消息淘汰策略。
    ///   - initialItems: 需要异步载入的初始消息。
    public init(
        capacity: Int = 300,
        trimmingPolicy: LiveCommentTrimmingPolicy = .lowestPriorityThenOldest,
        initialItems: [LiveCommentItem] = []
    ) {
        let resolvedCapacity = max(1, capacity)
        self.capacity = resolvedCapacity
        self.trimmingPolicy = trimmingPolicy
        self.processor = LiveCommentProcessor(
            capacity: resolvedCapacity,
            trimmingPolicy: trimmingPolicy
        )
        self.items = []
        self.pendingCount = 0
        self.isFollowingLatest = true
        self.immediateRevealRequest = nil
        self.lastAppliedRevision = 0

        if !initialItems.isEmpty {
            Task { [weak self] in
                await self?.enqueue(contentsOf: initialItems)
            }
        }
    }

    /// 异步处理并加入一条消息。
    ///
    /// 此方法可从 WebSocket、网络回调或其他并发上下文调用。数据处理发生在
    /// 独立 actor 中，完成后仅在主线程发布最终快照。队列未超过
    /// `capacity` 时只会追加，不会淘汰旧消息。
    /// - Parameter item: 要加入或更新的消息。
    public nonisolated func enqueue(_ item: LiveCommentItem) async {
        let snapshot = await processor.enqueue(item)
        await apply(snapshot)
    }

    /// 在一次后台任务中批量处理消息，并且只发布一次 UI 快照。
    /// - Parameter newItems: 要加入或更新的消息数组。
    public nonisolated func enqueue(contentsOf newItems: [LiveCommentItem]) async {
        guard !newItems.isEmpty else { return }
        let snapshot = await processor.enqueue(contentsOf: newItems)
        await apply(snapshot)
    }

    /// 异步暂停自动跟随；后续新消息只进入待加载区。
    public func pauseFollowingLatest() async {
        let snapshot = await processor.pauseFollowingLatest()
        apply(snapshot)
    }

    /// 异步合并暂停期间收到的消息，并恢复自动跟随。
    ///
    /// 合并计算在独立 actor 中执行。消息按普通、较高、关键的顺序稳定排列，
    /// 使高优先级消息位于列表底部的最新展示区域。
    public func resumeFollowingLatest() async {
        let snapshot = await processor.resumeFollowingLatest()
        apply(snapshot)
    }

    /// 异步清空展示队列、待加载区和待加载数量。
    public func removeAll() async {
        let snapshot = await processor.removeAll()
        apply(snapshot)
    }

    private func apply(_ snapshot: LiveCommentSnapshot) {
        guard snapshot.revision > lastAppliedRevision else { return }
        lastAppliedRevision = snapshot.revision
        items = snapshot.items
        pendingCount = snapshot.pendingCount
        isFollowingLatest = snapshot.isFollowingLatest
        if let itemID = snapshot.immediateRevealItemID {
            immediateRevealRequest = LiveCommentRevealRequest(
                itemID: itemID,
                revision: snapshot.revision
            )
        }
    }
}
