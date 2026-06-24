import Foundation

extension String {
    /// 归一化字符串用于哈希：去首尾空白、Unicode NFKC、全角转半角、lowercase、合并中间空白。
    ///
    /// 用于 `HashService.generateHash` 让同样的笔记（无论空白、全/半角、大小写）生成相同 hash。
    func normalizedForHash() -> String {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        // NFKC 把全角字符归一为半角 (例如 "ＡＢＣ" -> "ABC")
        let nfkc = trimmed.precomposedStringWithCompatibilityMapping

        // 合并连续空白为单空格。手动遍历比正则更可靠，避免 raw string 里 \s 转义问题。
        var result = ""
        var lastWasSpace = false
        for scalar in nfkc.unicodeScalars {
            if scalar.properties.isWhitespace || scalar.value == 0x3000 /* 全角空格 */ {
                if !lastWasSpace && !result.isEmpty {
                    result.append(" ")
                }
                lastWasSpace = true
            } else {
                result.unicodeScalars.append(scalar)
                lastWasSpace = false
            }
        }
        // 去尾部的空格
        while result.hasSuffix(" ") {
            result.removeLast()
        }
        return result.lowercased()
    }
}
