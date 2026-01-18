# SQLiteBrowser



## 一、核心架构设计

我们将采用 **MVVM (Model-View-ViewModel)** 架构，这是 SwiftUI 应用的常见且推荐模式。

### 1. Model (数据模型)

  * **`SQLiteDatabase`**: 负责连接数据库、执行 SQL 查询和管理连接生命周期的核心类。
  * **`TableSchema`**: 存储表的结构信息，包括列名、数据类型、是否主键等。
    * **`Column`** 结构体：存储单个列的详细信息。
  * **`TableRow`**: 表示表中的一行数据，可以使用 `[String: Any]` 或更安全的枚举/字典结构来存储，键是列名，值是数据。
  * **`QueryParameters`**: 一个结构体，用于封装所有查询参数，如：
    * `tableName: String`
    * `limit: Int` (分页大小)
    * `offset: Int` (分页偏移量)
    * `sortColumn: String?`
    * `sortOrder: SortOrder` (ASC/DESC)
    * `filterClause: String?` (SQL `WHERE` 子句)

### 2. ViewModel (视图模型)

  * **`DatabaseViewModel`**: 作为所有视图的数据源和业务逻辑中心。它会持有 `SQLiteDatabase` 实例和 `QueryParameters`，并负责：
    * **初始化和连接**：接收数据库路径 (`path`) 和初始表名 (`tableName`)。
    * **自动读取 Schema/DDL**：调用 Model 方法获取表结构和创建表的 SQL (`DDL`)。
    * **管理状态**：发布 (Publish) 数据给 View：
      * `@Published var isConnected: Bool`
      * `@Published var currentSchema: TableSchema?`
      * `@Published var currentDDL: String?`
      * `@Published var tableData: [TableRow]` (当前页的数据)
      * `@Published var totalRowCount: Int`
      * `@Published var currentPage: Int`
      * `@Published var isLoading: Bool` (用于显示加载指示器)
    * **处理分页/排序/筛选**：根据用户操作修改 `QueryParameters` 并触发数据重新加载。

### 3. View (视图)

  * **`ContentView`**: 主视图，持有 `DatabaseViewModel` 实例。
  * **`SchemaView` / `DDLView`**: 专门显示表结构和 DDL 的视图。
  * **`DataTableView`**: 核心数据展示视图。
    * 使用 **`LazyVGrid`** 或自定义布局（在 macOS/iPadOS 上可能是 **`Table`**）来展示表格数据。
    * **列头**：点击列头可以触发 `DatabaseViewModel` 的排序逻辑。
    * **数据行**：展示分页加载后的数据。
  * **`PagingControlView`**: 包含“上一页/下一页/页码”等按钮，调用 `DatabaseViewModel` 的分页方法。
  * **`FilterView`**: 一个表单或模态视图，用于构建复杂的筛选条件 (`WHERE` 子句)，更新 `QueryParameters`。

-----

## 二、 关键功能实现细节

### 1. 数据库连接和初始化

  * **依赖库**：使用  **`GRDB.swift`**，它们提供了类型安全的 Swift 接口来操作 SQLite。
  * **Schema & DDL 读取**：
    * **Schema**：执行 `PRAGMA table_info('tableName')` 查询来获取列名和类型。
    * **DDL**：查询 `sqlite_master` 表：`SELECT sql FROM sqlite_master WHERE type='table' AND name='tableName'`。

### 2. 分页加载 (Pagination)

  * **核心 SQL**：利用 `LIMIT` 和 `OFFSET` 子句实现分页。

    ```sql
    SELECT * FROM [tableName]
    [WHERE filter_clause]
    [ORDER BY sort_column sort_order]
    LIMIT [limit] OFFSET [offset]
    ```

  * **`DatabaseViewModel` 逻辑**：

    1.  当 `currentPage` 或 `QueryParameters` 发生变化时，计算新的 `offset = (currentPage - 1) * limit`。
    2.  调用 Model 执行查询。
    3.  设置 `@Published tableData` 和 `@Published isLoading = false`。

  * **总行数**：首次加载或筛选条件变化时，需要单独查询总行数：`SELECT COUNT(*) FROM [tableName] [WHERE filter_clause]`，这用于计算总页数和控制分页控件的启用状态。

### 3. 排序 (Sorting)

  * **用户交互**：点击 `DataTableView` 的列头。
  * **`DatabaseViewModel` 逻辑**：
    1.  如果点击的列与当前排序列相同，则切换 `sortOrder` (ASC \<-\> DESC)。
    2.  如果点击的列不同，则设置新列为 `sortColumn`，并默认 `sortOrder` 为 `ASC`。
    3.  修改 `QueryParameters` 并触发数据重新加载（同时重置 `currentPage` 到 1）。
  * **核心 SQL**：使用 `ORDER BY [sortColumn] [sortOrder]`。

### 4. 筛选 (Filtering)

  * **用户交互**：通过 `FilterView` 收集用户输入的筛选条件（例如：“列名 = 值”，“列名 LIKE '%子串%'”）。
  * **`DatabaseViewModel` 逻辑**：
    1.  将用户友好的筛选条件转换为有效的 SQL `WHERE` 子句字符串。
    2.  更新 `QueryParameters` 中的 `filterClause`。
    3.  触发数据重新加载**并重新查询总行数**（同时重置 `currentPage` 到 1）。
  * **安全性**：**非常重要！** 任何用户输入的筛选值都必须使用 **SQL 绑定 (Binding)** 机制，而不是直接拼接字符串，以防止 **SQL 注入攻击**。

-----

## 三、SwiftUI 特点利用

  * **响应式 UI**：使用 `@Published` 属性在 `DatabaseViewModel` 中管理所有状态。当数据更新时，如 `tableData` 或 `isLoading` 变化，SwiftUI 视图会自动重绘。
  * **性能**：使用 **`LazyVStack`** 或 **`LazyVGrid`** 配合分页加载，确保只有当前可见的数据单元格被创建和渲染，优化内存和渲染性能。
  * **跨平台**：SwiftUI  natively 支持 iOS, iPadOS, macOS。设计时应考虑不同平台上的适配，例如使用 `NavigationView` 或 `NavigationSplitView` 来管理不同的视图（Schema/DDL/Data）。

这个设计提供了一个清晰的分层结构，将数据操作、业务逻辑和 UI 展示清晰地分离，使得代码易于管理、测试和扩展。