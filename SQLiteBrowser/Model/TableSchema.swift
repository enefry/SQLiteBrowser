import Foundation

/// 存储表的结构信息，包括列名、数据类型、是否主键等。
public struct TableSchema: Identifiable {
    public var id: String { "table-\(name)" }
    /// 表名
    public let name: String
    /// 表中的列信息
    public let columns: [Column]
}

/// 存储单个列的详细信息。
public struct Column {
    /// 列名
    public let name: String
    /// 数据类型 (例如: "TEXT", "INTEGER", "REAL", "BLOB")
    public let dataType: String
    /// 是否允许为空
    public let isNullable: Bool
    /// 是否是主键
    public let isPrimaryKey: Bool
    /// 默认值
    public let defaultValue: String?
}
