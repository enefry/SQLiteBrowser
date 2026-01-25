import SwiftUI

/// 显示表格行详情的视图
struct RowDetailView: View {
    let row: TableRow
    let schema: TableSchema
    @Binding var selectedBlobData: IdentifiableData?

    @ViewBuilder
    fileprivate func valueView(column: Column) -> some View {
        HStack {
            // 第二行：字段值
            if let dataVal = row.dataValues(forColumn: column.name) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blob (\(dataVal.count) 字节)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                    Button(action: {
                        selectedBlobData = IdentifiableData(row: row, column: column, data: dataVal)
                    }) {
                        Label("预览 Blob", systemImage: "doc.text.fill")
                    }
                    .buttonStyle(.bordered)
                }
            } else if let val = row.value(forColumn: column.name) {
                Text("\(String(describing: val))")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
            } else {
                Text("NULL")
                    .font(.system(.body, design: .monospaced))
                    .italic()
                    .foregroundColor(.secondary)
            }
        }
        .padding(4)
    }

    @ViewBuilder
    func fieldInfoValue(column: Column) -> some View {
        return // 第一行：字段名称和属性图标
            HStack(spacing: 8) {
                // 字段名称
                Text("字段名: \(column.name)")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                // 图标右对齐
                HStack(alignment: .center, spacing: 2) {
                    // 主键图标
                    if column.isPrimaryKey {
                        Image(systemName: "key.circle.fill")
                            .font(.body)
                            .foregroundColor(.green)
                    }

                    // 可空标识
                    if !column.isNullable {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.body)
                            .foregroundColor(.green)
                    }
                    // 数据类型图标
                    Image(typeIcon(for: column.dataType), bundle: Bundle.module)
                        .imageScale(.medium)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
    }

    var body: some View {
        Form {
            ForEach(schema.columns, id: \.name) { column in
                VStack(alignment: .leading, spacing: 0) {
                    fieldInfoValue(column: column)
                        .padding(.bottom, 4)
                    valueView(column: column)
                }
            }
        }
        #if os(iOS)
        .navigationTitle("行详情")
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// 根据数据类型返回对应的图标
    private func typeIcon(for dataType: String) -> String {
        let type = dataType.uppercased()
        if type.contains("INT") {
            return "sqlite.int.symbols"
        } else if type.contains("TEXT") || type.contains("CHAR") || type.contains("CLOB") {
            return "sqlite.text.symbols"
        } else if type.contains("REAL") || type.contains("FLOAT") || type.contains("DOUBLE") {
            return "sqlite.float.symbols"
        } else if type.contains("BLOB") {
            return "sqlite.blob.symbols"
        } else if type.contains("DATE") || type.contains("TIME") {
            return "sqlite.date.symbols"
        } else if type.contains("NULL") {
            return "sqlite.null.symbols"
        } else {
            return "sqlite.unknown.symbols"
        }
    }
}
