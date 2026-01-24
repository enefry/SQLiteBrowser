import Foundation

/// 排序顺序枚举
public enum SortOrder: String {
    case asc = "ASC"
    case desc = "DESC"
}

/// 一个结构体，用于封装所有查询参数。
public struct QueryParameters {
    /// 表名
    public var tableName: String
    /// 分页大小
    public var limit: Int
    /// 分页偏移量
    public var offset: Int
    /// 排序的列名
    public var sortColumn: String?
    /// 排序顺序 (ASC/DESC)
    public var sortOrder: SortOrder
    /// SQL `WHERE` 子句
    public var filterClause: String?
    /// SQL `WHERE` 子句参数
    public var filterArguments: [Any]?

    /// 初始化查询参数
    /// - Parameter tableName: 表名
    /// - Parameter limit: 分页大小，默认为 50
    /// - Parameter offset: 分页偏移量，默认为 0
    /// - Parameter sortColumn: 排序的列名，默认为 nil
    /// - Parameter sortOrder: 排序顺序，默认为 .asc
    /// - Parameter filterClause: SQL `WHERE` 子句，默认为 nil
    /// - Parameter filterArguments: SQL `WHERE` 子句参数，默认为 nil
    public init(tableName: String, limit: Int = 50, offset: Int = 0, sortColumn: String? = nil, sortOrder: SortOrder = .desc, filterClause: String? = nil, filterArguments: [Any]? = nil) {
        self.tableName = tableName
        self.limit = limit
        self.offset = offset
        self.sortColumn = sortColumn
        self.sortOrder = sortOrder
        self.filterClause = filterClause
        self.filterArguments = filterArguments
    }
}
