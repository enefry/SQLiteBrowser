import SwiftUI

/// 专门显示表 DDL (数据定义语言) 的视图。
public struct DDLView: View {
    /// 要显示的 DDL 字符串
    public let ddl: String?

    public init(ddl: String?) {
        self.ddl = ddl
    }

    public var body: some View {
        Group {
            if let ddl = ddl, !ddl.isEmpty {
                ScrollView {
                    Text(ddl)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle("DDL")
            } else {
                Text("未加载 DDL 或 DDL 不存在。")
                    .foregroundColor(.gray)
                    .navigationTitle("DDL")
            }
        }
    }
}
