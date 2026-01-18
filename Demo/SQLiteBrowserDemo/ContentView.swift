//
//  ContentView.swift
//  SQLiteBrowserDemo
//
//  Created by 陈任伟 on 2025/9/27.
//

import GRDB
import SwiftUI
import UniformTypeIdentifiers

private class SchemaOutput: TextOutputStream {
    var text: [String] = []
    /// Appends the given string to the stream.
    func write(_ string: String) {
        text.append(string)
    }
}

struct ContentView: View {
    @ObservedObject var appModel: AppModel
    @State var showImport: Bool = false
    var body: some View {
        VStack {
            Button("打开数据库", action: {
                showImport.toggle()
            })
            .fileImporter(isPresented: $showImport, allowedContentTypes: [UTType(filenameExtension: "db")!, UTType(filenameExtension: "sqlite")!]) { result in
                if let url = try? result.get() {
                    appModel.pickFile(url)
                }
            }
            Button("上次文件") {
                appModel.pickInner()
            }
        }
    }
}
