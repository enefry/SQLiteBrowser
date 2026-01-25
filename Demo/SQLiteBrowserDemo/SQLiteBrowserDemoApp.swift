//
//  SQLiteBrowserDemoApp.swift
//  SQLiteBrowserDemo
//
//  Created by 陈任伟 on 2025/9/27.
//

import SQLiteBrowser
import SwiftUI

@main
struct SQLiteBrowserDemoApp: App {
    @StateObject var appModel: AppModel = AppModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if let viewModel = appModel.databaseModel {
                    SQLiteBrowser.DashboardView(viewModel: viewModel)
                } else {
                    ContentView(appModel: appModel)
                }
            }
        }
    }
}
