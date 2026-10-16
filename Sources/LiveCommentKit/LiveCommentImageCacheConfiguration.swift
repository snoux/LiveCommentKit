import Foundation
import SDWebImage

/// 直播头像使用的 SDWebImage 缓存上限。
public struct LiveCommentImageCacheConfiguration: Equatable, Sendable {
    /// 内存缓存允许使用的最大字节数。
    public var memoryCostLimit: Int

    /// 内存缓存允许保留的最大图片数量。
    public var memoryCountLimit: Int

    /// 磁盘缓存允许使用的最大字节数。
    public var diskSizeLimit: UInt

    /// 磁盘缓存文件的最长保留时间，单位为秒。
    public var diskAgeLimit: TimeInterval

    /// 适合常规直播场景的默认缓存配置。
    public static let liveStreaming = LiveCommentImageCacheConfiguration()

    /// 创建一份头像缓存配置。
    /// - Parameters:
    ///   - memoryCostLimit: 内存缓存最大字节数，默认 50 MB。
    ///   - memoryCountLimit: 内存缓存最大图片数量，默认 300 张。
    ///   - diskSizeLimit: 磁盘缓存最大字节数，默认 200 MB。
    ///   - diskAgeLimit: 磁盘缓存最长保留秒数，默认 7 天。
    public init(
        memoryCostLimit: Int = 50 * 1024 * 1024,
        memoryCountLimit: Int = 300,
        diskSizeLimit: UInt = 200 * 1024 * 1024,
        diskAgeLimit: TimeInterval = 7 * 24 * 60 * 60
    ) {
        self.memoryCostLimit = max(0, memoryCostLimit)
        self.memoryCountLimit = max(0, memoryCountLimit)
        self.diskSizeLimit = diskSizeLimit
        self.diskAgeLimit = max(0, diskAgeLimit)
    }

    /// 将配置应用到 SDWebImage 的共享缓存。
    ///
    /// 建议在 App 启动时调用一次。组件不会在单条弹幕消失时主动删除头像，
    /// 而是让 SDWebImage 按这里的统一上限自动淘汰缓存。
    public func apply() {
        let configuration = SDImageCache.shared.config
        configuration.maxMemoryCost = UInt(memoryCostLimit)
        configuration.maxMemoryCount = UInt(memoryCountLimit)
        configuration.maxDiskSize = diskSizeLimit
        configuration.maxDiskAge = diskAgeLimit
    }
}
