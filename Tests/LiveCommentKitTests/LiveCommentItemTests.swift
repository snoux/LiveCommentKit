import XCTest
@testable import LiveCommentKit

final class LiveCommentItemTests: XCTestCase {
    func testKindsProvideDefaultPriorityLevels() {
        XCTAssertEqual(makeItem(kind: .comment).priority, .normal)
        XCTAssertEqual(makeItem(kind: .currentUser).priority, .immediate)
        XCTAssertEqual(makeItem(kind: .viewerJoined).priority, .elevated)
        XCTAssertEqual(makeItem(kind: .gift).priority, .elevated)
        XCTAssertEqual(makeItem(kind: .host).priority, .critical)
        XCTAssertEqual(makeItem(kind: .moderator).priority, .critical)
        XCTAssertEqual(makeItem(kind: .system).priority, .critical)
    }

    func testExplicitPriorityOverridesKindDefault() {
        let item = LiveCommentItem(
            nickname: "主播",
            content: "这条消息主动降级",
            kind: .host,
            priority: .normal
        )

        XCTAssertEqual(item.priority, .normal)
    }

    func testItemCanRoundTripThroughJSON() throws {
        let item = LiveCommentItem(
            id: "message-1",
            userID: "user-1",
            nickname: "小满",
            content: "主播今天状态真好",
            avatarURL: URL(string: "https://example.com/avatar.png"),
            kind: .comment,
            priority: .normal,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(LiveCommentItem.self, from: data)

        XCTAssertEqual(decoded, item)
    }

    private func makeItem(kind: LiveCommentKind) -> LiveCommentItem {
        LiveCommentItem(
            nickname: "测试用户",
            content: "测试消息",
            kind: kind
        )
    }
}
