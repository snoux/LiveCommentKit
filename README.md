# LiveCommentKit

`LiveCommentKit` 是一个适合直播画面左下角纵向滚动评论的 SwiftUI 组件。它不是横向飞行弹幕：消息从下方进入、向上滚动，用户上滑查看历史时会暂停自动跟随，并显示待查看消息数量。

## 特性

- 通过 Swift Package Manager 接入，最低支持 iOS 17。
- 固定容量的 `LiveCommentBuffer`，避免消息随直播时长无限增长。
- 支持普通、当前用户、新观众加入、主播、管理员、系统、礼物七种消息类别。
- 支持普通、较高、关键、即时四级优先级，并由消息类别自动提供合理默认值。
- 使用 `SDWebImageSwiftUI` 加载头像，并按显示尺寸进行缩略图解码。
- 提供统一的头像内存、数量、磁盘大小和保存时间上限。
- 用户上滑后，新消息暂存在独立待加载区，不会改变正在翻看的历史列表。
- 新消息按钮显示 `1…99` 或 `99+`，点击后才加载待处理消息并回到最新位置。
- 列表无额外背景，顶部使用透明度遮罩直接渐隐，旧弹幕离开时不会被生硬切断。
- 公开类型、函数及参数均提供 `///` 文档注释，可在 Xcode Quick Help 中查看。

## 安装

在 Xcode 中选择 **File → Add Package Dependencies**，填入仓库地址并将 `LiveCommentKit` 产品加入 App Target。

本地开发时，也可以把本仓库作为 Local Package 加入 Xcode 工程。

## 最小用法

```swift
import LiveCommentKit
import SwiftUI

struct LiveRoomView: View {
    @StateObject private var comments = LiveCommentBuffer(capacity: 300)

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LiveVideoView()

            LiveCommentView(buffer: comments)
                .frame(width: 320, height: 260)
                .padding()
        }
        .onAppear {
            LiveCommentImageCacheConfiguration.liveStreaming.apply()
        }
    }

    func receiveComment(_ payload: CommentPayload) {
        Task {
            await comments.enqueue(
                LiveCommentItem(
                    id: payload.id,
                    userID: payload.userID,
                    nickname: payload.nickname,
                    content: payload.content,
                    avatarURL: URL(string: payload.avatarURL)
                )
            )
        }
    }
}
```

`enqueue(_:)` 是异步接口，可从 WebSocket、网络回调或其他并发上下文调用。
批量恢复历史数据时优先使用 `await comments.enqueue(contentsOf: messages)`，
整批消息只会向 UI 提交一次最终快照。

## 异步处理模型

- 消息去重、分类、优先级排序、容量裁剪和待加载合并都在 `LiveCommentProcessor` actor 中串行处理，不占用主线程。
- `MainActor` 只负责将已处理且数量受限的快照赋给 `@Published` 属性，供 SwiftUI 刷新。
- 每份快照带有递增版本号，并发调用返回顺序不一致时，较旧结果不会覆盖较新状态。
- JSON 解码、网络协议解析等业务层工作也应在后台任务中完成，然后将构造好的 `LiveCommentItem` 交给缓冲区。

## SDK 完整调用与执行流程

业务层应在收到 WebSocket、IM 或长连接数据并完成解码后，
将单条或批量 `LiveCommentItem` 交给 SDK：

```swift
func receiveComment(_ payload: CommentPayload) async {
    // JSON 解码应在业务层的后台任务中完成。
    let item = LiveCommentItem(
        id: payload.id,
        userID: payload.userID,
        nickname: payload.nickname,
        content: payload.content,
        avatarURL: URL(string: payload.avatarURL),
        kind: payload.isCurrentUser ? .currentUser : .comment
    )

    // 从这里开始进入 SDK 数据处理链路。
    await comments.enqueue(item)
}
```

```mermaid
sequenceDiagram
    participant Network as WebSocket / IM
    participant App as 业务层
    participant Buffer as LiveCommentBuffer
    participant Actor as LiveCommentProcessor actor
    participant Deque as items / pendingItems Deque
    participant Main as MainActor
    participant View as LiveCommentView

    Network->>App: 原始数据
    App->>App: 后台解码并构造 LiveCommentItem
    App->>Buffer: await enqueue(item)
    Buffer->>Actor: await processor.enqueue(item)
    Actor->>Actor: 判断跟随状态、类别与优先级
    Actor->>Deque: ID 去重或队尾 append
    alt count > capacity
        Actor->>Deque: 只移除 count - capacity 条溢出消息
    end
    Actor->>Actor: Deque 转换为带 revision 的数组快照
    Actor-->>Buffer: LiveCommentSnapshot
    Buffer->>Main: apply(snapshot)
    Main->>Main: 拒绝过期 revision，更新 @Published
    Main-->>View: SwiftUI 观察到状态变化
    View->>View: LazyVStack 差量渲染并滚动到最新位置
```

完整执行规则：

1. 业务层先在后台任务中完成网络数据解码，然后构造 `LiveCommentItem`。
2. `LiveCommentBuffer.enqueue` 是 `nonisolated async` 入口，不会在主线程执行队列计算。
3. `LiveCommentProcessor` actor 串行处理并发调用，避免多个网络回调同时修改 Deque。
4. 正在跟随最新消息时，新消息进入 `items`；浏览历史时，普通新消息进入 `pendingItems`。
5. `.currentUser` 消息始终进入 `items`，并生成立即滚动请求，但不会顺带加载其他待处理消息。
6. Deque 先按 ID 查找：重复 ID 在原位更新，新 ID 从队尾追加。
7. 只有 `count > capacity` 才淘汰，且只淘汰 `count - capacity` 条。容量可在创建 `LiveCommentBuffer` 时配置。
8. `.oldest` 从队首 `popFirst`；`.lowestPriorityThenOldest` 优先移除最低优先级中最旧的消息。
9. actor 完成后将 Deque 转换为不可变数组快照，并附加递增 `revision`。
10. `LiveCommentBuffer` 回到 `MainActor`，先拒绝过期快照，再将新快照赋给 `@Published` 属性。
11. SwiftUI 观察到变化后重新计算 `LiveCommentView`，`LazyVStack` 只创建当前需要的行。
12. `latestItemID` 变化时才触发一次可配置的 `easeOut` 滚动；没有新消息时不会按帧刷新。

批量接口 `enqueue(contentsOf:)` 会在一次 actor 调用中处理整批消息，
最后只向主线程提交一份快照。

## 双端队列实现

`LiveCommentDeque` 是组件内部的环形双端队列，不依赖额外第三方库。
`LiveCommentProcessor` actor 内部同时维护两个 Deque：

- `items`：已进入展示区的消息。
- `pendingItems`：用户正在翻看历史时收到的待加载消息。

每条新消息通常在队尾 `append`。使用 `.oldest` 策略达到容量上限时，
直接从队首 `popFirst`，两个操作均为均摊 `O(1)`。使用
`.lowestPriorityThenOldest` 时，会扫描定位最低优先级中最旧的消息，
然后从距离该元素较近的队首或队尾移动元素。

`capacity` 是可配置的最大保留数量，不是固定批次。例如容量为 100 时：

| 入队前 | 新增 | 入队后 | 淘汰数量 |
| ---: | ---: | ---: | ---: |
| 20 | 10 | 30 | 0 |
| 95 | 10 | 100 | 5 |
| 100 | 10 | 100 | 10 |

Deque 始终留在 actor 内部，只有在生成 UI 快照时才按队首到队尾转换为
`[LiveCommentItem]`。因此 SwiftUI 仍可使用稳定的数组快照，不会接触或修改后台队列。

## 类别与优先级

只传消息类别即可获得默认优先级：

| 消息类别 | 默认优先级 |
| --- | --- |
| `.comment` | `.normal` |
| `.viewerJoined`、`.gift` | `.elevated` |
| `.host`、`.moderator`、`.system` | `.critical` |
| `.currentUser` | `.immediate` |

```swift
let moderatorMessage = LiveCommentItem(
    nickname: "房管小助手",
    content: "请大家文明交流",
    kind: .moderator
)

// moderatorMessage.priority 自动为 .critical
Task {
    await comments.enqueue(moderatorMessage)
}
```

如有特殊业务规则，仍可通过 `priority:` 显式覆盖。缓冲区默认使用
`.lowestPriorityThenOldest` 淘汰策略：达到容量上限时先淘汰较低优先级的旧消息，
因此主播、管理员和系统消息会比普通评论保留得更久。

当前用户发送弹幕时，请使用 `.currentUser`：

```swift
let myMessage = LiveCommentItem(
    nickname: "我",
    content: "这条会立即显示",
    kind: .currentUser
)

Task {
    await comments.enqueue(myMessage)
}
```

即使用户正在翻看历史，`.currentUser` 也会绕过待加载区、立即进入展示队列并滚动到可见位置。
其他人在此期间发来的消息仍保留在“新消息”按钮中，不会被一并加载。

## 历史浏览与待加载消息

当用户在弹幕区域上滑时，组件调用 `pauseFollowingLatest()`。此后的新消息不会写入公开的
`items` 展示队列，而是进入容量受限的待加载区：

- `pendingCount` 记录暂停期间实际收到的新消息数量。
- `pendingCountBadgeText` 在超过 99 条时返回 `99+条新消息`。
- 用户点击按钮后，`resumeFollowingLatest()` 才会把仍被保留的待加载消息合并到展示队列。
- 合并顺序为普通 → 较高 → 关键 → 即时，同级消息保持接收顺序，因此高优先级消息会落在滚动后的最新可见区域。
- 待加载区同样受 `capacity` 和优先级淘汰策略约束，不会因长时间翻看历史而无限增长。

## 缓存建议

请在 App 启动时调用一次：

```swift
LiveCommentImageCacheConfiguration(
    memoryCostLimit: 50 * 1024 * 1024,
    memoryCountLimit: 300,
    diskSizeLimit: 200 * 1024 * 1024,
    diskAgeLimit: 7 * 24 * 60 * 60
).apply()
```

组件不会在某条弹幕离开屏幕时删除头像缓存。这样同一用户再次发言时可以复用图片；缓存达到上限后，由 SDWebImage 统一淘汰。

## 自定义样式

```swift
let style = LiveCommentStyle(
    avatarSize: 32,
    topFadeHeight: 48,
    scrollAnimationDuration: 0.28,
    lineLimit: 2,
    commentBackgroundColor: .black.opacity(0.52),
    hostBackgroundColor: .orange.opacity(0.82)
)

LiveCommentView(
    buffer: comments,
    style: style,
    showsAvatar: true,
    onCommentTap: { comment in
        print(comment.userID as Any)
    }
)
```

列表在新消息到达时使用 `ScrollViewReader.scrollTo` 配合
`Animation.easeOut(duration:)` 进行事件驱动滚动。`scrollAnimationDuration` 越小滚动越快，
设为 `0` 时直接跳到最新位置。组件不使用 `TimelineView`，避免在没有新弹幕时仍持续按帧刷新。

## 内存边界

消息模型与头像缓存是两套独立边界：

1. `LiveCommentBuffer.capacity` 同时控制展示队列和待加载区各自的消息上限。
2. `LiveCommentImageCacheConfiguration` 控制 SDWebImage 的内存与磁盘缓存。
3. 头像会按照视图尺寸与屏幕缩放倍数进行缩略图解码，避免为一个 30pt 头像长期解码超大原图。

不要在每个 `LiveCommentRow.onDisappear` 中删除头像，否则同一用户再次出现时会重复下载和解码。
