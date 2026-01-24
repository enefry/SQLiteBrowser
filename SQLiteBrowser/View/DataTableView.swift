import SwiftUI

/// 核心数据展示视图。
public struct DataTableView: View {
    /// 数据库视图模型
    @ObservedObject var viewModel: DatabaseViewModel

    /// 控制 Blob 预览的 Sheet
    @State private var selectedBlobData: Data?
    /// 控制 Schema 视图的显示
    @State private var showSchema = false
    /// 控制 DDL 视图的显示
    @State private var showDDL = false
    /// 控制筛选视图的显示
    @State private var showFilter = false

    /// 选中的行
    @State private var selectedRow: TableRow? = nil
    /// 控制行详情视图的显示
    @State private var showRowDetail = false

    public var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("加载中...")
            } else if viewModel.tableData.isEmpty {
                Text("没有数据可显示。")
                    .foregroundColor(.gray)
            } else {
                tableContent
            }
            PagingControlView(viewModel: viewModel)
        }
        .navigationTitle("数据表 - \(viewModel.queryParameters.tableName)")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                toolbarMenu
            }
        }
        .sheet(item: Binding<IdentifiableData?>(
            get: { selectedBlobData.map { IdentifiableData(data: $0) } },
            set: { selectedBlobData = $0?.data }
        )) { identifiableData in
            VStack(spacing: 0) {
                // Custom navigation bar
                HStack {
                    Text("Blob Preview")
                        .font(.headline)
                    Spacer()
                    Button("关闭") {
                        selectedBlobData = nil
                    }
                    .keyboardShortcut(.cancelAction)
                }
                .padding()
                #if os(macOS)
                    .background(Color(nsColor: .windowBackgroundColor))
                #else
                    .background(Color(uiColor: .systemBackground))
                #endif

                Divider()

                MediaView(data: identifiableData.data)
                    .border(Color.blue)
                    .padding(4)
            }
            .border(Color.green)
            #if os(macOS)
                .frame(minWidth: 600, idealWidth: 800, maxWidth: .infinity, minHeight: 400, idealHeight: 600, maxHeight: .infinity)
            #endif
            #if os(iOS)
            .presentationDetents([.large, .medium])
            .presentationDragIndicator(.visible)
            #endif
        }
        .sheet(isPresented: $showSchema) {
            schemaSheet
        }
        .sheet(isPresented: $showDDL) {
            ddlSheet
        }
        .sheet(isPresented: $showFilter) {
            filterSheet
        }
        .sheet(isPresented: $showRowDetail) {
            rowDetailSheet
        }
    }

    /// 存储每列的宽度
    @State private var columnWidths: [String: CGFloat] = [:]

    /// 存储容器宽度，用于 header 和数据行对齐
    @State private var containerWidth: CGFloat = 0

    private let defaultColumnWidth: CGFloat = 120
    private let minColumnWidth: CGFloat = 50

    /// State for resize preview line
    @State private var previewLineX: CGFloat? = nil
    @State private var resizingColumn: String? = nil
    @State private var resizingStartWidth: CGFloat = 0

    @ViewBuilder
    private var tableContent: some View {
        fallbackGridView
    }

    private var fallbackGridView: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section(header: headerRow) {
                        ForEach(viewModel.tableData) { row in
                            HStack(spacing: 0) {
                                ForEach(viewModel.currentSchema?.columns ?? [], id: \.name) { column in
                                    CellView(row: row, column: column, selectedBlobData: $selectedBlobData)
                                        .frame(width: width(for: column.name))
                                        .border(Color.gray.opacity(0.1), width: 0.5) // 单元格边框
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(minWidth: geometry.size.width, alignment: .leading)
                            .background(selectedRow?.id == row.id ? Color.accentColor.opacity(0.15) : Color.clear)
                            #if os(macOS)
                                .highPriorityGesture(
                                    TapGesture(count: 2)
                                        .onEnded {
                                            selectedRow = row
                                            showRowDetail = true
                                        }
                                )
                                .onTapGesture {
                                    selectedRow = row
                                }
                            #else
                                    .onTapGesture {
                                        selectedRow = row
                                        showRowDetail = true
                                    }
                            #endif
                        }
                    }
                }
                .frame(minHeight: geometry.size.height, alignment: .top)
                .onAppear {
                    containerWidth = geometry.size.width
                }
                .onChange(of: geometry.size.width) { newWidth in
                    containerWidth = newWidth
                }
            }
            .overlay(alignment: .topLeading) {
                // Preview line during resize
                if let x = previewLineX {
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 2)
                        .overlay(
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: 1)
                        )
                        .offset(x: x)
                }
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.currentSchema?.columns ?? [], id: \.name) { column in
                HeaderCell(
                    name: column.name,
                    sortOrder: viewModel.queryParameters.sortColumn == column.name ? viewModel.queryParameters.sortOrder : nil,
                    width: width(for: column.name),
                    onSort: { viewModel.sort(byColumn: column.name) },
                    onResize: { translation, isEnded in
                        if isEnded {
                            // Drag ended - save the final width and hide preview
                            if let col = resizingColumn {
                                let finalWidth = max(minColumnWidth, resizingStartWidth + translation)
                                columnWidths[col] = finalWidth
                            }
                            resizingColumn = nil
                            previewLineX = nil
                        } else {
                            // Dragging - update preview line position
                            if resizingColumn != column.name {
                                // Start of a new drag
                                resizingColumn = column.name
                                resizingStartWidth = columnWidths[column.name] ?? defaultColumnWidth
                            }

                            // Calculate preview line X position
                            // Sum up all column widths before this column
                            let columns = viewModel.currentSchema?.columns ?? []
                            var xOffset: CGFloat = 0
                            for col in columns {
                                if col.name == column.name {
                                    // Add the resized width for this column
                                    let newWidth = max(minColumnWidth, resizingStartWidth + translation)
                                    xOffset += newWidth
                                    break
                                } else {
                                    xOffset += width(for: col.name)
                                }
                            }
                            previewLineX = xOffset
                        }
                    }
                )
            }
            Spacer(minLength: 0)
        }
        .frame(minWidth: containerWidth, alignment: .leading)
        .background(headerBackgroundColor) // 确保 Header 不透明
        .border(Color.gray.opacity(0.2), width: 1) // Header 底部边框效果
    }

    private var headerBackgroundColor: Color {
        #if os(macOS)
            return Color(nsColor: .windowBackgroundColor)
        #else
            return Color(uiColor: .systemBackground)
        #endif
    }

    private func width(for columnName: String) -> CGFloat {
        return columnWidths[columnName] ?? defaultColumnWidth
    }

    private func totalContentWidth(_ minWidth: CGFloat) -> CGFloat {
        let currentTotal = (viewModel.currentSchema?.columns ?? []).reduce(0) { $0 + width(for: $1.name) }
        return max(currentTotal, minWidth)
    }

    private var toolbarMenu: some View {
        Menu {
            Button(action: { showFilter = true }) {
                Label("Filter Data", systemImage: "line.3.horizontal.decrease.circle")
            }
            Divider()
            Button(action: { showSchema = true }) {
                Label("Table Schema", systemImage: "list.bullet.rectangle")
            }
            Button(action: { showDDL = true }) {
                Label("Table DDL", systemImage: "doc.text.magnifyingglass")
            }
            Divider()
            Button(action: { viewModel.loadTableData() }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            Button(action: {
                // 重置列宽
                columnWidths.removeAll()
            }) {
                Label("Reset Column Widths", systemImage: "arrow.left.and.right.circle")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private var schemaSheet: some View {
        guard let schema = viewModel.currentSchema else { return AnyView(Text("No schema available")) }
        let view = SchemaView(schema: [schema])
            .toolbar {
                Button("Done") { showSchema = false }
            }

        #if os(macOS)
            return AnyView(
                view.frame(minWidth: 600, idealWidth: 800, maxWidth: .infinity, minHeight: 400, idealHeight: 600, maxHeight: .infinity)
            )
        #else
            return AnyView(
                NavigationView {
                    view
                        .navigationTitle("Schema")
                        .navigationBarTitleDisplayMode(.inline)
                }
            )
        #endif
    }

    private var ddlSheet: some View {
        let view = DDLView(ddl: viewModel.currentDDL)
            .toolbar {
                Button("Done") { showDDL = false }
            }

        #if os(macOS)
            return AnyView(view.frame(minWidth: 600, idealWidth: 800, maxWidth: .infinity, minHeight: 400, idealHeight: 600, maxHeight: .infinity))
        #else
            return AnyView(
                NavigationView {
                    view
                        .navigationTitle("DDL")
                        .navigationBarTitleDisplayMode(.inline)
                }
            )
        #endif
    }

    private var filterSheet: some View {
        #if os(macOS)
            AdvancedFilterView(viewModel: viewModel)
                .frame(minWidth: 600, idealWidth: 800, minHeight: 500, idealHeight: 700)
        #else
            NavigationView {
                AdvancedFilterView(viewModel: viewModel)
            }
        #endif
    }

    private var rowDetailSheet: some View {
        Group {
            if let row = selectedRow, let schema = viewModel.currentSchema {
                #if os(macOS)
                    VStack(spacing: 0) {
                        // Custom navigation bar
                        HStack {
                            Text("行详情")
                                .font(.headline)
                            Spacer()
                            Button("关闭") {
                                showRowDetail = false
                            }
                            .keyboardShortcut(.cancelAction)
                        }
                        .padding()
                        .background(Color(nsColor: .windowBackgroundColor))

                        Divider()
                        ScrollView {
                            RowDetailView(row: row, schema: schema, selectedBlobData: $selectedBlobData)
                                .padding()
                        }
                    }
                    .frame(minWidth: 500, idealWidth: 600, maxWidth: .infinity,
                           minHeight: 400, idealHeight: 500, maxHeight: .infinity)
                #else
                    NavigationView {
                        RowDetailView(row: row, schema: schema, selectedBlobData: $selectedBlobData)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("关闭") {
                                        showRowDetail = false
                                    }
                                }
                            }
                    }
                #endif
            }
        }
    }
}

// Header Cell with Resizing Logic

struct HeaderCell: View {
    #if os(macOS)
        private let PLATFORM_DRAG_WIDTH: CGFloat = 10
    #else
        private let PLATFORM_DRAG_WIDTH: CGFloat = 24
    #endif
    let name: String
    let sortOrder: SortOrder?
    let width: CGFloat
    let onSort: () -> Void
    let onResize: (CGFloat, Bool) -> Void // translation, isEnded

    @State private var lastTranslation: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSort) {
                HStack {
                    Text(name)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .frame(minWidth: 44, maxWidth: .infinity)
                    if let sortOrder = sortOrder {
                        Image(systemName: sortOrder == .asc ? "chevron.up" : "chevron.down")
                    }
                }
                .padding(.leading, 8)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())

            // Resize Handle Overlay
            Rectangle()
                .fill(Color.gray.opacity(0.3)) // Almost transparent but hittable
                .frame(width: PLATFORM_DRAG_WIDTH) // Wider hit area
//                .overlay(
//                    Rectangle()
//                        .fill(Color.gray.opacity(0.3))
//                        .frame(width: 1)
//                )
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            lastTranslation = value.translation.width
                            onResize(value.translation.width, false)
                        }
                        .onEnded { _ in
                            onResize(lastTranslation, true)
                            lastTranslation = 0
                        }
                )
                // Offset to center on the right edge
                .offset(x: 7)
        }
        .frame(width: width)
        .zIndex(1) // Ensure handle is on top
    }
}

// 独立的 Cell 视图
struct CellView: View {
    let row: TableRow
    let column: Column
    @Binding var selectedBlobData: Data?

    var body: some View {
        Group {
            if let dataVal = row.dataValues(forColumn: column.name) {
                Button(action: {
                    selectedBlobData = dataVal
                }) {
                    Label("Blob", systemImage: "doc.text.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            } else if let val = row.value(forColumn: column.name) {
                Text("\(String(describing: val))")
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8) // Add padding for text
            } else {
                Text("NULL")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .italic()
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading) // Align content to leading
    }
}

// 辅助结构体用于 Sheet 的 Identifiable
struct IdentifiableData: Identifiable {
    let id = UUID()
    let data: Data
}
