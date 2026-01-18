import SwiftUI

/// 包含“上一页/下一页/页码”等按钮，调用 `DatabaseViewModel` 的分页方法。
struct PagingControlView: View {
    /// 数据库视图模型
    @ObservedObject var viewModel: DatabaseViewModel

    var body: some View {
        HStack {
            Button(action: {
                viewModel.goToPreviousPage()
            }) {
                Image(systemName: "arrow.left")
            }
            .disabled(viewModel.currentPage <= 1 || viewModel.isLoading)

            Text("第 \(viewModel.currentPage) 页 / 共 \(totalPages) 页")

            Button(action: {
                viewModel.goToNextPage()
            }) {
                Image(systemName: "arrow.right")
            }
            .disabled(viewModel.currentPage >= totalPages || viewModel.isLoading)
        }
        .padding()
    }

    /// 计算总页数
    private var totalPages: Int {
        guard viewModel.queryParameters.limit > 0 else { return 1 }
        return (viewModel.totalRowCount + viewModel.queryParameters.limit - 1) / viewModel.queryParameters.limit
    }
}

//// 预览
//struct PagingControlView_Previews: PreviewProvider {
//    static var previews: some View {
//        // 创建一个模拟的 ViewModel
//        let mockViewModel = DatabaseViewModel(dbPath: "test.db")
//        mockViewModel.totalRowCount = 100
//        mockViewModel.currentPage = 5
//        mockViewModel.queryParameters.limit = 10
//
//        return PagingControlView(viewModel: mockViewModel)
//    }
//}
