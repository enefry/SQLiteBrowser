import SwiftUI

/// 主视图，负责文件选择和导航
public struct DashboardView: View {
    /// 数据库视图模型
    /// 数据库视图模型
    @ObservedObject var viewModel: DatabaseViewModel

    /// 初始化 ContentView
    /// - Parameter viewModel: 数据库视图模型
    public init(viewModel: DatabaseViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        List {
            // 数据库连接状态
            Section("数据库连接") {
                HStack {
                    Text("连接状态:")
                    Spacer()
                    Text(viewModel.isConnected ? "已连接" : "未连接")
                        .foregroundColor(viewModel.isConnected ? .green : .red)
                }
                Button(viewModel.isConnected ? "断开连接" : "连接数据库") {
                    if viewModel.isConnected {
                        viewModel.disconnectFromDatabase()
                    } else {
                        viewModel.connectToDatabase()
                    }
                }
            }

            // 表选择器
            Section("表选择") {
                Picker("选择表", selection: Binding(
                    get: { viewModel.queryParameters.tableName },
                    set: { viewModel.switchTable(to: $0) }
                )) {
                    ForEach(viewModel.tableNames, id: \.self) { tableName in
                        Text(tableName).tag(tableName)
                    }
                }
                .pickerStyle(.inline)
            }

            // 导航到不同的视图
            Section("视图") {
                if let schema = viewModel.currentSchema {
                    NavigationLink("Schema") {
                        SchemaView(schema: [schema])
                    }
                }
                NavigationLink("DDL") {
                    DDLView(ddl: viewModel.currentDDL)
                }
                NavigationLink("数据表") {
                    DataTableView(viewModel: viewModel)
                }
                NavigationLink("高级筛选器") {
                    AdvancedFilterView(viewModel: viewModel)
                }
            }
        }
        .navigationTitle("SQLite 浏览器")
        .onAppear {
            // 可以在这里尝试自动连接数据库
            viewModel.connectToDatabase()
        }
    }
}
