# LiveCommentKit

SwiftUI 纵向直播评论容器，最低 iOS 17 / macOS 14。SDK 管理消息缓冲与滚动，业务工程通过 `@ViewBuilder` 提供评论 Cell 和未读提示。

## 职责与依赖

- SDK：去重、容量裁剪、优先级、历史浏览期间的待加载区、实际未读数量、自动跟随、当前用户消息即时可见、恢复跟随及滚动定位。
- 容器：`ScrollView + LazyVStack`、稳定行 ID、行间距、顶部渐隐、贴底布局和滚动动画。
- 业务工程：Cell 的布局、字体、背景、头像加载、点击事件，以及未读提示的按钮、文案和样式。
- SDK 只依赖 Apple Swift Collections 1.1.6，不依赖 SDWebImage 或 SDWebImageSwiftUI。
- 所有公开类型、初始化器、函数与参数使用 `///` Quick Help 注释。

## 安装

通过 Swift Package Manager 将 `LiveCommentKit` 产品加入 App Target；本地可添加本仓库作为 Local Package。图片库由使用方按需引用。

## 自定义 Cell 与未读提示

```swift
import LiveCommentKit
import SwiftUI

struct LiveRoomView: View {
    @StateObject private var comments = LiveCommentBuffer(capacity: 300)

    var body: some View {
        LiveCommentView(
            buffer: comments,
            layout: LiveCommentLayout(rowSpacing: 6, topFadeHeight: 24)
        ) { item in
            Text(item.nickname + "：" + item.content)
                .padding(8)
                .background(.black.opacity(0.4), in: Capsule())
                .foregroundStyle(.white)
                .onTapGesture { print(item.userID as Any) }
        } pending: { count, showLatest in
            Button(action: showLatest) {
                Text(count > 99 ? "99+条新消息" : "\(count)条新消息")
                    .font(.caption)
                    .padding(8)
                    .background(.white, in: Capsule())
                    .foregroundStyle(.orange)
            }
        }
        .frame(width: 320, height: 260)
    }
}
```

`content` 可返回任意业务 View，也可根据 `item.kind` 使用不同布局。SDK 不设置行的字体、背景、头像或点击手势，只设置消息的稳定 ID。

`pending` 仅在实际未读数量大于 0 时构造。数量不做 99 截断；第二个参数 `showLatest` 是同步调用入口，SDK 内部异步合并消息并滚动，业务按钮无需重复处理缓存。业务可使用 Button、点击手势或其他控件触发它。

仅需评论行时，可以省略未读提示闭包：

```swift
LiveCommentView(buffer: comments) { item in
    Text(item.content)
}
```

省略后默认使用 `EmptyView`，暂停跟随与未读数据仍生效；业务需要时可调用 `await comments.resumeFollowingLatest()` 恢复跟随。

## 容器布局

`LiveCommentLayout` 只提供 `rowSpacing`、`topFadeHeight`、`scrollAnimationDuration`、`rowAlignment` 和 `pendingAlignment`。默认行左对齐、提示位于左下角，顶部渐隐高度 44，滚动动画 0.22 秒。渐隐高度或动画时长为 0 时关闭对应效果。

列表默认底部锚定，消息不足一屏时也贴底；每次收到新消息才执行一次滚动，没有按帧轮询。

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

底层使用 Apple Swift Collections 的 `DequeModule.Deque`，保留环形缓冲区与值语义，不再维护自定义双端队列。
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
- SDK 仅提供实际 `pendingCount`；是否显示 `99+`、显示什么文案，由外部提示视图决定。
- 用户点击按钮后，`resumeFollowingLatest()` 才会把仍被保留的待加载消息合并到展示队列。
- 合并顺序为普通 → 较高 → 关键 → 即时，同级消息保持接收顺序，因此高优先级消息会落在滚动后的最新可见区域。
- 待加载区同样受 `capacity` 和优先级淘汰策略约束，不会因长时间翻看历史而无限增长。


## 头像与缓存由业务管理

SDK 中的 `avatarURL` 仅是 Foundation 数据字段，不触发加载。业务 Cell 可以使用本地 Image、系统 AsyncImage 或自行引入的图片库。

独立 `LiveCommentKitDemo` 保留网络头像演示，其 `DemoCommentCell`、`DemoCommentAvatar` 和 `DemoCommentImageCacheConfiguration` 均属于 Demo 工程；Demo 直接依赖 SDWebImageSwiftUI 与 SDWebImage，并在启动时设置缓存上限。这些产品不属于 SDK 依赖图。

## 迁移说明

这次调整了视图构造 API，消息入队、缓冲区和优先级 API 保持原样：

| 旧 API | 新用法 |
| --- | --- |
| `LiveCommentView(buffer:style:)` | `LiveCommentView(buffer:layout:content:pending:)` |
| `LiveCommentStyle` | 容器参数放入 `LiveCommentLayout`，行样式放入业务 Cell |
| `showsAvatar`、`onCommentTap` | 在业务 Cell 内处理头像和点击 |
| `showsJumpToLatestButton` | 传入 `pending`，或省略闭包隐藏提示 |
| `pendingCountBadgeText` | 读取实际 `pendingCount` 后由业务格式化 |
| SDK 默认 Cell、头像与缓存配置 | 移入业务工程；Demo 提供可参考实现 |

SDK 及独立 Demo 均保留 iOS 17 最低版本。
