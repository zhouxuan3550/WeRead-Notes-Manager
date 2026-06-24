import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - 性能优化工具
struct PerformanceUtils {
    
    /// 简单的性能计时器
    static func measureTime<T>(label: String = #function, operation: () throws -> T) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        AppLog.info("⏱️ \(label) took \(String(format: "%.2f", elapsed))ms", category: .general)
        return result
    }
    
    /// 防抖工具 - 用于搜索等场景
    final class Debouncer {
        private let delay: TimeInterval
        private var workItem: DispatchWorkItem?
        private let queue: DispatchQueue
        
        init(delay: TimeInterval = 0.3, queue: DispatchQueue = .main) {
            self.delay = delay
            self.queue = queue
        }
        
        func debounce(_ action: @escaping () -> Void) {
            workItem?.cancel()
            workItem = DispatchWorkItem(block: action)
            queue.asyncAfter(deadline: .now() + delay, execute: workItem!)
        }
        
        func cancel() {
            workItem?.cancel()
        }
    }
    
    /// 简单的节流工具
    final class Throttler {
        private let delay: TimeInterval
        private var lastExecuted = Date.distantPast
        private var pendingWorkItem: DispatchWorkItem?
        private let queue: DispatchQueue
        
        init(delay: TimeInterval = 0.3, queue: DispatchQueue = .main) {
            self.delay = delay
            self.queue = queue
        }
        
        func throttle(_ action: @escaping () -> Void) {
            let now = Date()
            if now.timeIntervalSince(lastExecuted) >= delay {
                action()
                lastExecuted = now
            } else {
                pendingWorkItem?.cancel()
                let workItem = DispatchWorkItem(block: { [weak self] in
                    action()
                    self?.lastExecuted = Date()
                })
                pendingWorkItem = workItem
                queue.asyncAfter(deadline: .now() + delay, execute: workItem)
            }
        }
    }
}

// MARK: - SwiftUI 性能优化扩展
extension View {
    
    /// 使用 `.id()` 强制视图重绘（只在需要时使用）
    func forceRefreshOnChange<Value: Hashable>(of value: Value) -> some View {
        self.id(value)
    }
    
    /// 添加可见性检查（用于大列表）
    func onViewVisibilityChange(isVisible: Binding<Bool>) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        let screenFrame = NSScreen.main?.frame ?? .zero
                        let isInView = geo.frame(in: .global).intersects(screenFrame)
                        if isVisible.wrappedValue != isInView {
                            isVisible.wrappedValue = isInView
                        }
                    }
            }
        )
    }
}

// MARK: - 数组性能优化
extension Array {
    
    /// 安全的批量操作
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
    
    /// 快速去重
    func uniqued<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}

// MARK: - 字符串性能优化
extension String {
    
    /// 预计算的小写缓存（用于搜索）
    private static var lowercaseCache = NSCache<NSString, NSString>()
    
    /// 高性能的小写转换（带缓存）
    var lowercasedCached: String {
        let key = self as NSString
        if let cached = Self.lowercaseCache.object(forKey: key) as? String {
            return cached
        }
        let result = self.lowercased()
        Self.lowercaseCache.setObject(result as NSString, forKey: key)
        return result
    }
    
    /// 清空缓存
    static func clearLowercasedCache() {
        lowercaseCache.removeAllObjects()
    }
}
