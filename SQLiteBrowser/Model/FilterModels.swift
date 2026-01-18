import Foundation

/// 筛选操作符枚举
public enum FilterOperator: String, CaseIterable, Identifiable {
    case equals = "="
    case notEquals = "!="
    case greaterThan = ">"
    case lessThan = "<"
    case greaterOrEqual = ">="
    case lessOrEqual = "<="
    case like = "LIKE"
    case notLike = "NOT LIKE"
    case isNull = "IS NULL"
    case isNotNull = "IS NOT NULL"
    case contains = "CONTAINS"
    case startsWith = "STARTS WITH"
    case endsWith = "ENDS WITH"
    
    public var id: String { rawValue }
    
    /// 获取操作符的显示名称
    public var displayName: String {
        switch self {
        case .equals: return "等于"
        case .notEquals: return "不等于"
        case .greaterThan: return "大于"
        case .lessThan: return "小于"
        case .greaterOrEqual: return "大于等于"
        case .lessOrEqual: return "小于等于"
        case .like: return "匹配模式"
        case .notLike: return "不匹配模式"
        case .isNull: return "为空"
        case .isNotNull: return "不为空"
        case .contains: return "包含"
        case .startsWith: return "以...开头"
        case .endsWith: return "以...结尾"
        }
    }
    
    /// 是否需要值输入
    public var needsValue: Bool {
        switch self {
        case .isNull, .isNotNull:
            return false
        default:
            return true
        }
    }
    
    /// 转换为 SQL 表达式模板（使用 ? 占位符）
    /// - Parameter column: 列名
    /// - Returns: 包含 ? 的 SQL 模板
    public func sqlTemplate(column: String) -> String {
        switch self {
        case .equals:
            return "\(column) = ?"
        case .notEquals:
            return "\(column) != ?"
        case .greaterThan:
            return "\(column) > ?"
        case .lessThan:
            return "\(column) < ?"
        case .greaterOrEqual:
            return "\(column) >= ?"
        case .lessOrEqual:
            return "\(column) <= ?"
        case .like:
            return "\(column) LIKE ?"
        case .notLike:
            return "\(column) NOT LIKE ?"
        case .isNull:
            return "\(column) IS NULL"
        case .isNotNull:
            return "\(column) IS NOT NULL"
        case .contains:
            return "\(column) LIKE ?"
        case .startsWith:
            return "\(column) LIKE ?"
        case .endsWith:
            return "\(column) LIKE ?"
        }
    }
}

/// 逻辑操作符（用于连接多个条件）
public enum LogicalOperator: String, CaseIterable, Identifiable {
    case and = "AND"
    case or = "OR"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .and: return "并且"
        case .or: return "或者"
        }
    }
}

/// 单个筛选条件
public struct FilterCondition: Identifiable, Equatable {
    public let id = UUID()
    public var column: String = ""
    public var filterOperator: FilterOperator = .equals
    public var value: String = ""
    public var logicalOperator: LogicalOperator = .and
    
    public init() {}

    /// 验证条件是否有效
    public var isValid: Bool {
        if column.isEmpty {
            return false
        }
        if filterOperator.needsValue && value.isEmpty {
            return false
        }
        return true
    }
    
    /// 生成 SQL 片段和参数
    public func toParameterizedSQL() -> (sql: String, args: [Any])? {
        guard isValid else { return nil }
        
        let sql = filterOperator.sqlTemplate(column: column)
        var args: [Any] = []
        
        if filterOperator.needsValue {
            // 处理特殊的操作符值
            switch filterOperator {
            case .contains:
                args.append("%\(value)%")
            case .startsWith:
                args.append("\(value)%")
            case .endsWith:
                args.append("%\(value)")
            default:
                args.append(value)
            }
        }
        
        return (sql, args)
    }
}
