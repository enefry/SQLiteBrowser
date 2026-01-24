import Combine
import Foundation
import LoggerProxy
import SwiftUI // 引入 SwiftUI 以使用 @Published

/// 作为所有视图的数据源和业务逻辑中心。
public class DatabaseViewModel: ObservableObject {
    /// 数据库实例
    private var database: SQLiteDatabase
    /// 查询参数
    @Published public var queryParameters: QueryParameters

    /// 是否已连接到数据库
    @Published public var isConnected: Bool = false
    /// 当前表的 Schema (表结构)
    @Published public var currentSchema: TableSchema?
    /// 当前表的 DDL (数据定义语言)
    @Published public var currentDDL: String?
    /// 当前页的数据
    @Published public var tableData: [TableRow] = []
    /// 总行数
    @Published public var totalRowCount: Int = 0
    /// 当前页码
    @Published public var currentPage: Int = 1
    /// 是否正在加载数据
    @Published public var isLoading: Bool = false

    // MARK: - 高级筛选器状态

    /// 当前筛选条件列表
    @Published public var advancedFilterConditions: [FilterCondition] = []
    /// 是否处于手动 SQL 编辑模式
    @Published public var isManualSQLMode: Bool = false
    /// 手动输入的 SQL
    @Published public var manualFilterSQL: String = ""

    /// 所有表名列表
    @Published public var tableNames: [String] = []

    /// 用于管理 Combine 订阅
    private var cancellables = Set<AnyCancellable>()

    /// 初始化 ViewModel
    /// - Parameter dbPath: 数据库文件路径
    public init(dbPath: String) {
        database = SQLiteDatabase(path: dbPath)
        queryParameters = QueryParameters(tableName: "")

        // 监听 queryParameters 和 currentPage 的变化，当变化时重新加载数据
        Publishers.CombineLatest($queryParameters, $currentPage)
            .dropFirst() // 避免初始化时触发
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main) // 防抖
            .sink { [weak self] _ in
                self?.loadTableData()
            }
            .store(in: &cancellables)
    }

    /// 连接到数据库
    func connectToDatabase() {
        if isConnected {
            return
        }
        isLoading = true
        do {
            try database.connect()
            isConnected = true
            // 首次连接成功后，加载表名列表
            loadTableNames()
        } catch {
            LoggerProxy.ELog(tag: LogTag.database, msg: "Error connecting to database: \(error.localizedDescription)")
            isConnected = false
            isLoading = false
        }
    }

    /// 加载数据库中的所有表名
    func loadTableNames() {
        guard isConnected else { return }
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            do {
                let tables = try self.database.getAllTableNames()
                DispatchQueue.main.async {
                    self.tableNames = tables
                    // 如果当前没有选定表且有表可用，默认选第一个
                    if self.queryParameters.tableName.isEmpty, let firstTable = tables.first {
                        self.switchTable(to: firstTable)
                    }
                }
            } catch {
                LoggerProxy.ELog(tag: LogTag.database, msg: "Error loading table names: \(error.localizedDescription)")
            }
        }
    }

    /// 断开数据库连接
    func disconnectFromDatabase() {
        database.disconnect()
        isConnected = false
        currentSchema = nil
        currentDDL = nil
        tableData = []
        totalRowCount = 0
        currentPage = 1
    }

    /// 加载当前表的 Schema 和 DDL
    func loadSchemaAndDDL() {
        guard isConnected else { return }
        isLoading = true
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            do {
                let schema = try self.database.getSchema(forTable: self.queryParameters.tableName)
                let ddl = try self.database.getDDL(forTable: self.queryParameters.tableName)
                DispatchQueue.main.async {
                    self.currentSchema = schema
                    self.currentDDL = ddl
                    self.isLoading = false
                }
            } catch {
                LoggerProxy.ELog(tag: LogTag.database, msg: "Error loading schema or DDL: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.currentSchema = nil
                    self.currentDDL = nil
                    self.isLoading = false
                }
            }
        }
    }

    /// 加载表数据（包含分页、排序、筛选逻辑）
    func loadTableData() {
        guard isConnected else { return }
        isLoading = true
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            do {
                // 计算偏移量 (使用局部变量，不修改 queryParameters 以避免循环调用)
                let offset = (self.currentPage - 1) * self.queryParameters.limit

                // 构建 SQL 查询
                var sql = "SELECT * FROM \(self.queryParameters.tableName)"
                var countSql = "SELECT COUNT(*) FROM \(self.queryParameters.tableName)"
                var parameters: [Any?] = []

                if let filter = self.queryParameters.filterClause, !filter.isEmpty {
                    sql += " WHERE \(filter)"
                    countSql += " WHERE \(filter)"

                    if let args = self.queryParameters.filterArguments {
                        parameters.append(contentsOf: args as [Any?])
                    }
                }

                if let sortCol = self.queryParameters.sortColumn {
                    sql += " ORDER BY \(sortCol) \(self.queryParameters.sortOrder.rawValue)"
                }

                sql += " LIMIT \(self.queryParameters.limit) OFFSET \(offset)"

                let data = try self.database.executeQuery(sql: sql, parameters: parameters)
                let totalCountRows = try self.database.executeQuery(sql: countSql, parameters: parameters)
                let totalCount = totalCountRows.first?.data.first?.value as? Int ?? 0

                DispatchQueue.main.async {
                    self.tableData = data
                    self.totalRowCount = totalCount
                    self.isLoading = false
                }
            } catch {
                LoggerProxy.ELog(tag: LogTag.database, msg: "Error loading table data: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.tableData = []
                    self.totalRowCount = 0
                    self.isLoading = false
                }
            }
        }
    }

    /// 切换到上一页
    func goToPreviousPage() {
        guard currentPage > 1 && !isLoading else { return }
        currentPage -= 1
        // loadTableData 会被 queryParameters 的 sink 触发
    }

    /// 切换到下一页
    func goToNextPage() {
        let totalPages = (totalRowCount + queryParameters.limit - 1) / queryParameters.limit
        guard currentPage < totalPages && !isLoading else { return }
        currentPage += 1
        // loadTableData 会被 queryParameters 的 sink 触发
    }

    /// 根据列名进行排序
    /// - Parameter columnName: 要排序的列名
    func sort(byColumn columnName: String) {
        if queryParameters.sortColumn == columnName {
            // 如果是同一列，切换排序顺序
            queryParameters.sortOrder = (queryParameters.sortOrder == .asc) ? .desc : .asc
        } else {
            // 如果是新列，设置为升序
            queryParameters.sortColumn = columnName
            queryParameters.sortOrder = .asc
        }
        currentPage = 1 // 排序后重置页码
        // loadTableData 会被 queryParameters 的 sink 触发
    }

    /// 应用筛选条件
    /// - Parameter filterClause: SQL `WHERE` 子句字符串
    /// - Parameter arguments: SQL 参数
    func applyFilter(filterClause: String?, arguments: [Any]? = nil) {
        queryParameters.filterClause = filterClause
        queryParameters.filterArguments = arguments
        currentPage = 1 // 筛选后重置页码
        // loadTableData 会被 queryParameters 的 sink 触发
        // 重新加载 Schema 和 DDL，因为筛选可能影响总行数
        loadSchemaAndDDL()
    }

    /// 应用高级筛选
    /// - Parameters:
    ///   - conditions: 筛选条件列表
    ///   - isManualMode: 是否为手动 SQL 模式
    ///   - manualSQL: 手动输入的 SQL
    func applyAdvancedFilter(conditions: [FilterCondition], isManualMode: Bool, manualSQL: String) {
        // 保存状态
        advancedFilterConditions = conditions
        isManualSQLMode = isManualMode
        manualFilterSQL = manualSQL

        // 生成 WHERE 子句
        let filterClause: String?
        let arguments: [Any]?

        if isManualMode {
            filterClause = manualSQL.isEmpty ? nil : manualSQL
            arguments = nil // 手动模式目前不支持参数绑定
        } else {
            let validConditions = conditions.filter { $0.isValid }
            if validConditions.isEmpty {
                filterClause = nil
                arguments = nil
            } else {
                var sql = ""
                var args: [Any] = []

                for (index, condition) in validConditions.enumerated() {
                    guard let result = condition.toParameterizedSQL() else { continue }

                    if index > 0 {
                        sql += " \(condition.logicalOperator.rawValue) "
                    }
                    sql += result.sql
                    args.append(contentsOf: result.args)
                }
                filterClause = sql
                arguments = args
            }
        }

        applyFilter(filterClause: filterClause, arguments: arguments)
    }

    /// 清除所有筛选
    func clearAllFilters() {
        advancedFilterConditions = []
        isManualSQLMode = false
        manualFilterSQL = ""
        manualFilterSQL = ""
        applyFilter(filterClause: nil, arguments: nil)
    }

    /// 切换当前显示的表
    /// - Parameter newTableName: 新的表名
    func switchTable(to newTableName: String) {
        guard newTableName != queryParameters.tableName else { return }
        queryParameters.tableName = newTableName
        currentPage = 1 // 切换表后重置页码
        queryParameters.filterClause = nil // 清除筛选条件
        queryParameters.filterArguments = nil // 清除筛选参数
        queryParameters.sortColumn = nil // 清除排序

        // 重置高级筛选器状态
        advancedFilterConditions = []
        isManualSQLMode = false
        manualFilterSQL = ""

        loadSchemaAndDDL() // 加载新表的 Schema 和 DDL
        // loadTableData 会被 queryParameters 的 sink 触发
    }
}
