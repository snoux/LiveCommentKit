import DequeModule
import Foundation

/// actor 处理完一次队列事务后产生的不可变 UI 快照。
struct LiveCommentSnapshot: Sendable {
    /// 队首到队尾顺序的可见消息。
    let items: [LiveCommentItem]

    /// 浏览历史期间实际收到的新消息数量。
    let pendingCount: Int

    /// 当前是否自动跟随最新消息。
    let isFollowingLatest: Bool

    /// 用于防止旧并发结果覆盖新状态的递增版本号。
    let revision: UInt64

    /// 需要立即滚动到可见位置的当前用户消息标识。
    let immediateRevealItemID: LiveCommentItem.ID?
}

/// 在独立 actor 中管理展示 Deque 和待加载 Deque 的数据处理器。
actor LiveCommentProcessor {
    /// 已进入展示区的 Swift Collections 双端队列。
    private var items: Deque<LiveCommentItem>

    /// 用户翻看历史时暂存新消息的 Swift Collections 双端队列。
    private var pendingItems: Deque<LiveCommentItem>
    private var pendingCount = 0
    private var isFollowingLatest = true
    private var revision: UInt64 = 0

    private let capacity: Int
    private let trimmingPolicy: LiveCommentTrimmingPolicy

    /// 创建弹幕数据处理器。
    /// - Parameters:
    ///   - capacity: 两个 Deque 各自最多保留的消息数量。
    ///   - trimmingPolicy: Deque 超出容量后使用的淘汰策略。
    init(capacity: Int, trimmingPolicy: LiveCommentTrimmingPolicy) {
        self.capacity = capacity
        self.trimmingPolicy = trimmingPolicy
        self.items = Deque()
        self.pendingItems = Deque()
        self.items.reserveCapacity(capacity + 1)
        self.pendingItems.reserveCapacity(capacity + 1)
    }

    /// 处理一条新消息并返回最新快照。
    /// - Parameter item: 要加入或更新的弹幕。
    /// - Returns: 完成去重、入队和裁剪后的状态快照。
    func enqueue(_ item: LiveCommentItem) -> LiveCommentSnapshot {
        let shouldRevealImmediately = !isFollowingLatest && item.kind == .currentUser

        if isFollowingLatest || shouldRevealImmediately {
            appendVisible(item)
        } else {
            appendPending(item)
        }
        advanceRevision()
        return snapshot(
            immediateRevealItemID: shouldRevealImmediately ? item.id : nil
        )
    }

    /// 在同一次 actor 事务中批量处理消息。
    /// - Parameter newItems: 需要按数组顺序入队的弹幕。
    /// - Returns: 整批处理完成后的唯一 UI 快照。
    func enqueue(contentsOf newItems: [LiveCommentItem]) -> LiveCommentSnapshot {
        var immediateRevealItemID: LiveCommentItem.ID?

        for item in newItems {
            let shouldRevealImmediately = !isFollowingLatest && item.kind == .currentUser
            if isFollowingLatest || shouldRevealImmediately {
                appendVisible(item)
                if shouldRevealImmediately {
                    immediateRevealItemID = item.id
                }
            } else {
                appendPending(item)
            }
        }
        advanceRevision()
        return snapshot(immediateRevealItemID: immediateRevealItemID)
    }

    /// 暂停自动跟随，使后续普通消息进入待加载 Deque。
    /// - Returns: 切换跟随状态后的快照。
    func pauseFollowingLatest() -> LiveCommentSnapshot {
        isFollowingLatest = false
        advanceRevision()
        return snapshot()
    }

    /// 按优先级稳定合并待加载消息，并恢复自动跟随。
    /// - Returns: 合并和容量裁剪完成后的快照。
    func resumeFollowingLatest() -> LiveCommentSnapshot {
        isFollowingLatest = true
        for item in prioritizedPendingItems() {
            appendVisible(item)
        }
        pendingItems.removeAll(keepingCapacity: true)
        pendingCount = 0
        advanceRevision()
        return snapshot()
    }

    /// 清空展示 Deque、待加载 Deque 与待加载计数。
    /// - Returns: 清空后的状态快照。
    func removeAll() -> LiveCommentSnapshot {
        items.removeAll(keepingCapacity: true)
        pendingItems.removeAll(keepingCapacity: true)
        pendingCount = 0
        advanceRevision()
        return snapshot()
    }

    /// 将消息加入展示 Deque，然后执行容量裁剪。
    /// - Parameter item: 要展示的消息。
    private func appendVisible(_ item: LiveCommentItem) {
        appendOrUpdate(item, in: &items)
        trimIfNeeded(&items)
    }

    /// 将消息加入待加载 Deque，并维护实际接收计数。
    /// - Parameter item: 浏览历史期间收到的消息。
    private func appendPending(_ item: LiveCommentItem) {
        let isNewMessage = pendingItems.firstIndex(where: { $0.id == item.id }) == nil
        appendOrUpdate(item, in: &pendingItems)
        trimIfNeeded(&pendingItems)

        if isNewMessage {
            pendingCount += 1
        }
    }

    /// 生成按普通到即时优先级稳定排序的待加载消息。
    /// - Returns: 同级内仍保持接收顺序的连续数组。
    private func prioritizedPendingItems() -> [LiveCommentItem] {
        pendingItems
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.priority == rhs.element.priority {
                    return lhs.offset < rhs.offset
                }
                return lhs.element.priority < rhs.element.priority
            }
            .map(\.element)
    }

    /// 按 ID 更新已有元素，或将新元素追加到队尾。
    /// - Parameters:
    ///   - item: 要加入或更新的消息。
    ///   - target: 要修改的双端队列。
    private func appendOrUpdate(
        _ item: LiveCommentItem,
        in target: inout Deque<LiveCommentItem>
    ) {
        if let index = target.firstIndex(where: { $0.id == item.id }) {
            target[index] = item
        } else {
            target.append(item)
        }
    }

    /// 按配置的淘汰策略将 Deque 裁剪到容量上限。
    ///
    /// 队列未超过 `capacity` 时不会移除任何消息。只有发生溢出时，
    /// 才会精确移除 `target.count - capacity` 条消息。
    /// - Parameter target: 要裁剪的双端队列。
    private func trimIfNeeded(_ target: inout Deque<LiveCommentItem>) {
        let overflowCount = max(0, target.count - capacity)
        guard overflowCount > 0 else { return }

        for _ in 0..<overflowCount {
            switch trimmingPolicy {
            case .oldest:
                // 双端队列从队首淘汰最旧消息，均摊 O(1)。
                target.popFirst()
            case .lowestPriorityThenOldest:
                // 先定位最低优先级中最旧的元素，再从较近的一端移动。
                target.remove(at: lowestPriorityOldestIndex(in: target))
            }
        }
    }

    /// 定位最低优先级中最旧的消息。
    /// - Parameter target: 要搜索的双端队列。
    /// - Returns: 应当被淘汰的逻辑下标。
    private func lowestPriorityOldestIndex(
        in target: Deque<LiveCommentItem>
    ) -> Deque<LiveCommentItem>.Index {
        var candidateIndex = target.startIndex
        for index in target.indices.dropFirst() {
            if target[index].priority < target[candidateIndex].priority {
                candidateIndex = index
            }
        }
        return candidateIndex
    }

    /// 为当前已完成的 actor 事务递增版本号。
    private func advanceRevision() {
        revision &+= 1
    }

    /// 将 actor 内的 Deque 状态转换为可发布的连续数组快照。
    /// - Parameter immediateRevealItemID: 需要立即滚动显示的消息标识。
    /// - Returns: 不包含可变 Deque 引用的值语义快照。
    private func snapshot(
        immediateRevealItemID: LiveCommentItem.ID? = nil
    ) -> LiveCommentSnapshot {
        LiveCommentSnapshot(
            items: Array(items),
            pendingCount: pendingCount,
            isFollowingLatest: isFollowingLatest,
            revision: revision,
            immediateRevealItemID: immediateRevealItemID
        )
    }
}
