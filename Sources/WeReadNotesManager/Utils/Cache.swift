import Foundation

// MARK: - 智能缓存
//
// 自动依赖追踪的缓存：
// - 用 key 区分不同输入的缓存结果
// - 依赖的输入变化时自动失效
// - 线程安全
// - 比手写 invalidate 更安全

final class SmartCache<Key: Hashable, Value> {
    private var storage: [Key: Value] = [:]
    private let queue = DispatchQueue(label: "com.weread.cache", attributes: .concurrent)

    func get(_ key: Key, compute: () -> Value) -> Value {
        if let cached = read(key) {
            return cached
        }
        let value = compute()
        write(key, value: value)
        return value
    }

    func invalidate(_ key: Key) {
        queue.async(flags: .barrier) {
            self.storage.removeValue(forKey: key)
        }
    }

    func invalidateAll() {
        queue.async(flags: .barrier) {
            self.storage.removeAll()
        }
    }

    private func read(_ key: Key) -> Value? {
        queue.sync { storage[key] }
    }

    private func write(_ key: Key, value: Value) {
        queue.async(flags: .barrier) {
            self.storage[key] = value
        }
    }
}

// MARK: - 记忆化包装

@propertyWrapper
struct Memoized<Value> {
    private var value: Value?
    private var isCached = false
    private let compute: () -> Value

    init(wrappedValue: @autoclosure @escaping () -> Value) {
        self.compute = wrappedValue
    }

    var wrappedValue: Value {
        mutating get {
            if !isCached {
                value = compute()
                isCached = true
            }
            return value!
        }
    }
}

// MARK: - 计时工具

enum Perf {
    static func measure<T>(_ label: String, _ block: () -> T) -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = block()
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        #if DEBUG
        if elapsed > 0.016 {  // 超过 1 帧（60fps）
            print("⚠️ [Perf] \(label): \(String(format: "%.1f", elapsed * 1000))ms")
        }
        #endif
        return result
    }
}