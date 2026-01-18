import GRDB
import SwiftUI

/// 专门显示表结构 (Schema) 的视图。
public struct SchemaView: View {
    /// 要显示的表结构
    let schema: [TableSchema]
    private class SchemaOutput: TextOutputStream {
        var text: [String] = []
        /// Appends the given string to the stream.
        func write(_ string: String) {
            text.append(string)
        }
    }

    public init(schema: [TableSchema]) {
        self.schema = schema
    }

    public var body: some View {
        Group {
            List {
                ForEach(schema) { table in
                    Section("表名") {
                        Text(table.name)
                    }
                    Section("列信息") {
                        ForEach(table.columns, id: \.name) { column in
                            VStack(alignment: .leading) {
                                Text("名称: \(column.name)")
                                Text("类型: \(column.dataType)")
                                Text("可空: \(column.isNullable ? "是" : "否")")
                                Text("主键: \(column.isPrimaryKey ? "是" : "否")")
                                if let defaultValue = column.defaultValue {
                                    Text("默认值: \(defaultValue)")
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("表结构")
    }
}
