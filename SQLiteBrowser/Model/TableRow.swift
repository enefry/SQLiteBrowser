import Foundation

/// 表示表中的一行数据，可以使用 `[String: Any]` 或更安全的枚举/字典结构来存储，键是列名，值是数据。
public struct TableRow: Identifiable {
    /// 用于 SwiftUI 列表的唯一标识符
    public let id = UUID()
    /// 行数据，键为列名，值为对应的数据
    public let data: [String: Any?]

    /// 根据列名获取数据
    /// - Parameter columnName: 列名
    /// - Returns: 对应的数据，可能为 nil
    public func value(forColumn columnName: String) -> Any? {
        return data[columnName] ?? nil
    }

    /// 获取 Data 类型的数据 (Blob)
    public func dataValues(forColumn columnName: String) -> Data? {
        return value(forColumn: columnName) as? Data
    }

    /// 获取 String 类型的数据
    public func stringValue(forColumn columnName: String) -> String? {
        return value(forColumn: columnName) as? String
    }
}
