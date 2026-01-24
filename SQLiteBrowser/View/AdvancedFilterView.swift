import SwiftUI

/// 高级筛选器视图
public struct AdvancedFilterView: View {
    /// 数据库视图模型
    @ObservedObject var viewModel: DatabaseViewModel

    /// 关闭视图的回调
    @Environment(\.dismiss) private var dismiss

    // MARK: - 本地暂存状态

    /// 筛选条件列表
    @State private var conditions: [FilterCondition] = []

    /// 是否显示高级模式（直接编辑 SQL）
    @State private var showAdvancedMode = false

    /// 高级模式下的 SQL 文本
    @State private var manualSQL: String = ""

    public init(viewModel: DatabaseViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
//        NavigationView {
        ZStack {
            Color.gray.opacity(0.05).ignoresSafeArea() // 背景色

            VStack(spacing: 0) {
                // 模式切换
                modeSwitchView
                    .padding()
                    .background(Color.white)

                ScrollView {
                    VStack(spacing: 24) {
                        if showAdvancedMode {
                            // 高级 SQL 编辑模式
                            advancedModeView
                        } else {
                            // 可视化条件构建器
                            visualBuilderView
                        }

                        // SQL 预览
                        sqlPreviewView
                    }
                    .padding()
                }

                // 底部操作栏
                bottomActionBar
            }
        }
        .navigationTitle("高级筛选器")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentFilter()
            }
//        }
    }

    // MARK: - 子视图组件

    private var modeSwitchView: some View {
        HStack {
            Text("模式")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Picker("模式", selection: $showAdvancedMode) {
                Text("可视化构建").tag(false)
                Text("SQL 编辑").tag(true)
            }
            .pickerStyle(.segmented)
            // .frame(width: 200)
        }
    }

    private var advancedModeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SQL WHERE 子句")
                .font(.headline)

            TextEditor(text: $manualSQL)
                .frame(minHeight: 200)
                .font(.system(.body, design: .monospaced))
                .disableAutocorrection(true)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(4)

            Text("直接编辑 SQL WHERE 子句（不需要包含 WHERE 关键字）")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var visualBuilderView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("筛选条件")
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation {
                        conditions.append(FilterCondition())
                    }
                } label: {
                    Label("添加", systemImage: "plus")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.bordered)
                .tint(.blue)
            }

            if conditions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("暂无筛选条件")
                        .foregroundColor(.secondary)
                    Button("添加第一个条件") {
                        withAnimation {
                            conditions.append(FilterCondition())
                        }
                    }
                    .font(.subheadline)
                }
                .border(Color.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            } else {
                ForEach($conditions) { $condition in
                    let conditionID = $condition.wrappedValue.id
                    FilterConditionRow(
                        condition: $condition,
                        isFirst: conditions.first?.id == conditionID,
                        availableColumns: availableColumns,
                        onDelete: {
                            withAnimation {
                                conditions.removeAll { $0.id == conditionID }
                            }
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var sqlPreviewView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SQL 预览")
                .font(.headline)

            HStack {
                Text(previewSQL.isEmpty ? "（无筛选条件）" : previewSQL)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(previewSQL.isEmpty ? .secondary : .primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !previewSQL.isEmpty {
                    Button {
                        #if os(iOS)
                            UIPasteboard.general.string = previewSQL
                        #else
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(previewSQL, forType: .string)
                        #endif
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var bottomActionBar: some View {
        HStack(spacing: 16) {
            Button(role: .destructive) {
                clearFilter()
            } label: {
                Text("清除筛选")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Button {
                applyFilter()
            } label: {
                Text("应用筛选")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading || (!showAdvancedMode && !hasValidConditions && !conditions.isEmpty))
        }
        .padding()
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: -2)
    }

    // MARK: - 辅助组件

    struct FilterConditionRow: View {
        @Binding var condition: FilterCondition
        let isFirst: Bool
        let availableColumns: [String]
        let onDelete: () -> Void

        var body: some View {
            VStack(alignment: .center, spacing: 12) {
                // 逻辑连接符 (非第一项)
                if !isFirst {
                    HStack {
                        Picker("逻辑关系", selection: $condition.logicalOperator) {
                            ForEach(LogicalOperator.allCases) { op in
                                Text(op.displayName).tag(op)
                            }
                        }
                        .pickerStyle(.segmented)
//                        .frame(width: 120)
                        .padding(.bottom, 4)
                    }
                }

                HStack(alignment: .center, spacing: 12) {
                    // 左侧：列名和操作符
                    // 列选择
                    Menu {
                        ForEach(availableColumns, id: \.self) { column in
                            Button(column) {
                                condition.column = column
                            }
                        }
                    } label: {
                        HStack {
                            Text(condition.column.isEmpty ? "选择列" : condition.column)
                                .foregroundColor(condition.column.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }

                    // 操作符选择
                    Menu {
                        ForEach(FilterOperator.allCases) { op in
                            Button(op.displayName) {
                                condition.filterOperator = op
                            }
                        }
                    } label: {
                        HStack {
                            Text(condition.filterOperator.displayName)
                                .lineLimit(1)
                            Spacer()

                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }

                    // 右侧：值输入

                    if condition.filterOperator.needsValue {
                        TextField("输入值", text: $condition.value)
                            .textFieldStyle(.roundedBorder)
                            .frame(height: 36) // 匹配 Menu 高度
                    } else {
                        Text("无需输入值")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(height: 36)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(6)
                    }

                    if !isFirst {
                        Button(role: .destructive, action: onDelete) {
                            Label("删除", systemImage: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .padding(.top, 4)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
    }

    // MARK: - 计算属性

    /// 获取可用的列名
    private var availableColumns: [String] {
        viewModel.currentSchema?.columns.map(\.name) ?? []
    }

    /// 是否有有效的条件
    private var hasValidConditions: Bool {
        conditions.contains { $0.isValid }
    }

    /// 预览 SQL
    private var previewSQL: String {
        if showAdvancedMode {
            return manualSQL
        } else {
            let validConditions = conditions.filter { $0.isValid }
            guard !validConditions.isEmpty else { return "" }

            var sql = ""
            for (index, condition) in validConditions.enumerated() {
                if index > 0 {
                    sql += " \(condition.logicalOperator.rawValue) "
                }
                // 仅用于预览，不处理参数绑定
                if let result = condition.toParameterizedSQL() {
                    // 简单的将 ? 替换为值进行展示（注意：这只是为了预览，不应直接用于执行）
                    var tempSql = result.sql
                    for arg in result.args {
                        tempSql = tempSql.replacingOccurrences(of: "?", with: "'\(arg)'", range: tempSql.range(of: "?"))
                    }
                    sql += tempSql
                }
            }
            return sql
        }
    }

    // MARK: - 方法

    /// 加载当前筛选条件
    private func loadCurrentFilter() {
        // 从 ViewModel 恢复状态
        showAdvancedMode = viewModel.isManualSQLMode
        manualSQL = viewModel.manualFilterSQL

        if !viewModel.advancedFilterConditions.isEmpty {
            conditions = viewModel.advancedFilterConditions
        } else if let currentFilter = viewModel.queryParameters.filterClause, !currentFilter.isEmpty {
            // 如果 ViewModel 中没有保存的高级条件，但有筛选 SQL (可能是之前版本或其他方式设置的)
            // 尝试将其放入手动 SQL 模式
            if manualSQL.isEmpty {
                manualSQL = currentFilter
                showAdvancedMode = true
            }
        } else {
            // 如果都为空，初始化一个空条件
            if conditions.isEmpty {
                conditions = [FilterCondition()]
            }
        }
    }

    /// 应用筛选
    private func applyFilter() {
        viewModel.applyAdvancedFilter(
            conditions: conditions,
            isManualMode: showAdvancedMode,
            manualSQL: manualSQL
        )
        dismiss()
    }

    /// 清除筛选
    private func clearFilter() {
        viewModel.clearAllFilters()
        dismiss()
    }
}
