import XCTest
@testable import LiveCommentKit

@MainActor
final class LiveCommentBufferTests: XCTestCase {
    func testOldestPolicyKeepsCapacityBounded() async {
        let buffer = LiveCommentBuffer(capacity: 3)

        await buffer.enqueue(contentsOf: [
            makeItem(id: "1"),
            makeItem(id: "2"),
            makeItem(id: "3"),
            makeItem(id: "4"),
        ])

        XCTAssertEqual(buffer.items.map(\.id), ["2", "3", "4"])
    }

    func testPriorityPolicyRetainsCriticalMessage() async {
        let buffer = LiveCommentBuffer(
            capacity: 3,
            trimmingPolicy: .lowestPriorityThenOldest
        )

        await buffer.enqueue(contentsOf: [
            makeItem(id: "critical", priority: .critical),
            makeItem(id: "normal-1"),
            makeItem(id: "normal-2"),
            makeItem(id: "normal-3"),
        ])

        XCTAssertEqual(buffer.items.map(\.id), ["critical", "normal-2", "normal-3"])
    }

    func testPendingMessagesLoadByPriorityAndKeepStableOrderWithinLevel() async {
        let buffer = LiveCommentBuffer(capacity: 10)
        await buffer.pauseFollowingLatest()

        await buffer.enqueue(makeItem(id: "critical-1", priority: .critical))
        await buffer.enqueue(makeItem(id: "normal-1"))
        await buffer.enqueue(makeItem(id: "elevated-1", priority: .elevated))
        await buffer.enqueue(makeItem(id: "normal-2"))
        await buffer.enqueue(makeItem(id: "critical-2", priority: .critical))

        await buffer.resumeFollowingLatest()

        XCTAssertEqual(
            buffer.items.map(\.id),
            ["normal-1", "normal-2", "elevated-1", "critical-1", "critical-2"]
        )
    }

    func testPausedBufferCountsPendingMessages() async {
        let buffer = LiveCommentBuffer(capacity: 10)
        await buffer.pauseFollowingLatest()

        await buffer.enqueue(makeItem(id: "1"))
        await buffer.enqueue(makeItem(id: "2"))

        XCTAssertEqual(buffer.pendingCount, 2)
        XCTAssertEqual(buffer.pendingCountBadgeText, "2条新消息")
        XCTAssertFalse(buffer.isFollowingLatest)
        XCTAssertTrue(buffer.items.isEmpty)

        await buffer.resumeFollowingLatest()

        XCTAssertEqual(buffer.pendingCount, 0)
        XCTAssertTrue(buffer.isFollowingLatest)
        XCTAssertEqual(buffer.items.map(\.id), ["1", "2"])
    }

    func testPendingBadgeStopsAtNinetyNinePlus() async {
        let buffer = LiveCommentBuffer(capacity: 120)
        await buffer.pauseFollowingLatest()

        await buffer.enqueue(
            contentsOf: (0..<100).map { makeItem(id: "\($0)") }
        )

        XCTAssertEqual(buffer.pendingCount, 100)
        XCTAssertEqual(buffer.pendingCountBadgeText, "99+条新消息")
        XCTAssertTrue(buffer.items.isEmpty)
    }

    func testCurrentUserMessageBypassesPendingQueueAndRequestsReveal() async {
        let buffer = LiveCommentBuffer(capacity: 10)
        await buffer.pauseFollowingLatest()
        await buffer.enqueue(makeItem(id: "other"))

        await buffer.enqueue(
            makeItem(
                id: "mine",
                priority: .immediate,
                kind: .currentUser
            )
        )

        XCTAssertEqual(buffer.items.map(\.id), ["mine"])
        XCTAssertEqual(buffer.pendingCount, 1)
        XCTAssertEqual(buffer.immediateRevealRequest?.itemID, "mine")
        XCTAssertFalse(buffer.isFollowingLatest)
    }

    func testPendingStorageIsBoundedAndRetainsPriority() async {
        let buffer = LiveCommentBuffer(capacity: 3)
        await buffer.pauseFollowingLatest()

        await buffer.enqueue(makeItem(id: "critical", priority: .critical))
        await buffer.enqueue(makeItem(id: "normal-1"))
        await buffer.enqueue(makeItem(id: "normal-2"))
        await buffer.enqueue(makeItem(id: "normal-3"))

        XCTAssertEqual(buffer.pendingCount, 4)
        XCTAssertTrue(buffer.items.isEmpty)

        await buffer.resumeFollowingLatest()

        XCTAssertEqual(buffer.items.map(\.id), ["normal-2", "normal-3", "critical"])
    }

    func testDuplicateIdentifierUpdatesInPlace() async {
        let buffer = LiveCommentBuffer(capacity: 10)
        await buffer.enqueue(makeItem(id: "same", content: "旧内容"))
        await buffer.enqueue(makeItem(id: "same", content: "新内容"))

        XCTAssertEqual(buffer.items.count, 1)
        XCTAssertEqual(buffer.items.first?.content, "新内容")
    }

    func testHighVolumeBatchKeepsNewestItemsWithOldestPolicy() async {
        let buffer = LiveCommentBuffer(
            capacity: 300,
            trimmingPolicy: .oldest
        )

        await buffer.enqueue(
            contentsOf: (0..<2_000).map { makeItem(id: "\($0)") }
        )

        XCTAssertEqual(buffer.items.count, 300)
        XCTAssertEqual(buffer.items.first?.id, "1700")
        XCTAssertEqual(buffer.items.last?.id, "1999")
    }

    func testMessagesAreEvictedOnlyByActualOverflowCount() async {
        let buffer = LiveCommentBuffer(
            capacity: 30,
            trimmingPolicy: .oldest
        )

        await buffer.enqueue(
            contentsOf: (0..<20).map { makeItem(id: "\($0)") }
        )
        XCTAssertEqual(buffer.items.count, 20)
        XCTAssertEqual(buffer.items.first?.id, "0")

        await buffer.enqueue(
            contentsOf: (20..<30).map { makeItem(id: "\($0)") }
        )
        XCTAssertEqual(buffer.items.count, 30)
        XCTAssertEqual(buffer.items.first?.id, "0")

        await buffer.enqueue(
            contentsOf: (30..<40).map { makeItem(id: "\($0)") }
        )
        XCTAssertEqual(buffer.items.count, 30)
        XCTAssertEqual(buffer.items.first?.id, "10")
        XCTAssertEqual(buffer.items.last?.id, "39")
    }

    private func makeItem(
        id: String,
        content: String = "测试弹幕",
        priority: LiveCommentPriority = .normal,
        kind: LiveCommentKind = .comment
    ) -> LiveCommentItem {
        LiveCommentItem(
            id: id,
            nickname: "测试用户",
            content: content,
            kind: kind,
            priority: priority
        )
    }
}
