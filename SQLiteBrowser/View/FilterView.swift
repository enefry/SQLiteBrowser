import SwiftUI

/// 一个表单或模态视图，用于构建复杂的筛选条件 (`WHERE` 子句)，更新 `QueryParameters`。
public struct FilterView: View {
    /// 数据库视图模型
    @ObservedObject var viewModel: DatabaseViewModel
    /// 用于本地存储筛选条件的字符串
    @State private var filterText: String = ""

    public init(viewModel: DatabaseViewModel, filterText: String = "") {
        self.viewModel = viewModel
        self.filterText = filterText
    }

    public var body: some View {
        Form {
            Section("筛选条件 (SQL WHERE 子句)") {
                TextEditor(text: $filterText)
                    .frame(minHeight: 100)
                    .border(Color.gray.opacity(0.5), width: 1)
                    .onAppear {
                        // 初始化时加载当前的筛选条件
                        filterText = viewModel.queryParameters.filterClause ?? ""
                    }
            }

            Button("应用筛选") {
                viewModel.applyFilter(filterClause: filterText.isEmpty ? nil : filterText)
            }
            .disabled(viewModel.isLoading)

            Button("清除筛选") {
                filterText = ""
                viewModel.applyFilter(filterClause: nil, arguments: nil)
            }
            .disabled(viewModel.isLoading && filterText.isEmpty && viewModel.queryParameters.filterClause == nil)
        }
        .navigationTitle("筛选数据")
    }
}
