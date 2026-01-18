import Combine
import Foundation
import GRDB

/// 负责连接数据库、执行 SQL 查询和管理连接生命周期的核心类。
public class SQLiteDatabase {
    /// 数据库连接路径
    public let dbPath: String

    /// GRDB 数据库连接队列
    private var dbQueue: DatabaseQueue?

    /// 初始化数据库连接
    /// - Parameter path: 数据库文件的路径
    public init(path: String) {
        dbPath = path
    }

    /// 连接到数据库
    /// - Throws: 如果连接失败，则抛出错误
    public func connect() throws {
        var config = Configuration()
        config.readonly = false
        config.label = "SQLiteBrowser"
        dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
    }

    /// 断开数据库连接
    public func disconnect() {
        dbQueue = nil
    }

    /// 执行 SQL 查询并返回结果
    /// - Parameter sql: 要执行的 SQL 语句
    /// - Parameter parameters: SQL 语句中的参数，用于防止 SQL 注入
    /// - Returns: 查询结果，例如 `[TableRow]`
    /// - Throws: 如果查询失败，则抛出错误
    public func executeQuery(sql: String, parameters: [Any?]? = nil) throws -> [TableRow] {
        guard let dbQueue = dbQueue else { throw DatabaseError.notConnected }

        return try dbQueue.read { db in
            var arguments: StatementArguments?
            if let parameters = parameters {
                arguments = StatementArguments(parameters as [Any])
            }

            let cursor = try Row.fetchCursor(db, sql: sql, arguments: arguments ?? StatementArguments())
            var rows: [TableRow] = []
            while let row = try cursor.next() {
                var rowData: [String: Any?] = [:]
                // GRDB Row conforms to Sequence, yielding (column, value)
                for (column, databaseValue) in row {
                    if databaseValue.isNull {
                        rowData[column] = nil
                    } else if let intVal = Int.fromDatabaseValue(databaseValue) {
                        rowData[column] = intVal
                    } else if let doubleVal = Double.fromDatabaseValue(databaseValue) {
                        rowData[column] = doubleVal
                    } else if let stringVal = String.fromDatabaseValue(databaseValue) {
                        rowData[column] = stringVal
                    } else if let dataVal = Data.fromDatabaseValue(databaseValue) {
                        // Blob 数据
                        rowData[column] = dataVal
                    } else {
                        // Fallback
                        rowData[column] = databaseValue.description
                    }
                }
                rows.append(TableRow(data: rowData))
            }
            return rows
        }
    }

    /// 执行非查询 SQL 语句（如 INSERT, UPDATE, DELETE, CREATE TABLE）
    /// - Parameter sql: 要执行的 SQL 语句
    /// - Parameter parameters: SQL 语句中的参数
    /// - Throws: 如果执行失败，则抛出错误
    public func executeUpdate(sql: String, parameters: [Any?]? = nil) throws {
        guard let dbQueue = dbQueue else { throw DatabaseError.notConnected }

        try dbQueue.write { db in
            var arguments: StatementArguments?
            if let parameters = parameters {
                arguments = StatementArguments(parameters as [Any])
            }
            try db.execute(sql: sql, arguments: arguments ?? StatementArguments())
        }
    }

    /// 获取指定表的 Schema (表结构)
    /// - Parameter tableName: 表名
    /// - Returns: `TableSchema` 对象
    /// - Throws: 如果获取失败，则抛出错误
    public func getSchema(forTable tableName: String) throws -> TableSchema {
        guard let dbQueue = dbQueue else { throw DatabaseError.notConnected }

        return try dbQueue.read { db in
            // 使用 PRAGMA table_info 获取更原始的表结构信息，兼容性更好
            let rows = try Row.fetchAll(db, sql: "PRAGMA table_info('\(tableName)')")

            let schemaColumns = rows.compactMap { row -> Column? in
                guard let name = row["name"] as String?,
                      let type = row["type"] as String?,
                      let notNull = row["notnull"] as Int?,
                      let pk = row["pk"] as Int? else {
                    return nil
                }

                let dfltValue = row["dflt_value"] as String?

                return Column(
                    name: name,
                    dataType: type,
                    isNullable: notNull == 0,
                    isPrimaryKey: pk > 0,
                    defaultValue: dfltValue
                )
            }
            return TableSchema(name: tableName, columns: schemaColumns)
        }
    }

    /// 获取指定表的 DDL (数据定义语言，即创建表的 SQL 语句)
    /// - Parameter tableName: 表名
    /// - Returns: DDL 字符串
    /// - Throws: 如果获取失败，则抛出错误
    public func getDDL(forTable tableName: String) throws -> String {
        guard let dbQueue = dbQueue else { throw DatabaseError.notConnected }

        return try dbQueue.read { db in
            // 查询 sqlite_master 表获取 sql
            let sql = "SELECT sql FROM sqlite_master WHERE type='table' AND name=?"
            if let row = try Row.fetchOne(db, sql: sql, arguments: [tableName]),
               let ddl = String.fromDatabaseValue(row["sql"]) {
                return ddl
            }
            return ""
        }
    }

    /// 获取数据库中的所有表名
    public func getAllTableNames() throws -> [String] {
        guard let dbQueue = dbQueue else { throw DatabaseError.notConnected }

        return try dbQueue.read { db in
            let sql = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
            let rows = try Row.fetchAll(db, sql: sql)
            return rows.compactMap { String.fromDatabaseValue($0["name"]) }
        }
    }
}

/// 数据库操作可能抛出的错误类型
public enum DatabaseError: Error {
    case notConnected
    case queryFailed(String)
    case updateFailed(String)
    case schemaRetrievalFailed(String)
    case ddlRetrievalFailed(String)
    case invalidParameters
}
