//
//  AppModel.swift
//  SQLiteBrowserDemo
//
//  Created by 陈任伟 on 2025/9/27.
//
import Combine
import LoggerProxy
import SQLiteBrowser
import SwiftUI

fileprivate let kLastUsedFileKey = "demo.url.last_used"
class AppModel: ObservableObject {
    var navigationPath: NavigationPath = NavigationPath()
    @Published var databaseModel: DatabaseViewModel?
    @Published var path: URL?

    func pickInner() {
        if let path = UserDefaults.standard.string(forKey: kLastUsedFileKey),
           FileManager.default.fileExists(atPath: path) {
            pickFile(URL(fileURLWithPath: path))
        }
    }

    func pickFile(_ url: URL) {
        let appDir = URL(filePath: NSTemporaryDirectory()).deletingLastPathComponent()
        if url.absoluteURL.path.starts(with: appDir.path) {
            path = url
            UserDefaults.standard.set(url.absoluteURL.path, forKey: kLastUsedFileKey)
            databaseModel = DatabaseViewModel(dbPath: url.path)
        } else {
            let isAccessing = url.startAccessingSecurityScopedResource()
            if !isAccessing {
                LoggerProxy.WLog(tag: LogTag.app, msg: "Warning: Failed to access security scoped resource for \(path)")
            }

            // Copy to temp directory to avoid Sandbox/WAL issues
            if let tempURL = copyToTemp(source: url) {
                path = tempURL
                UserDefaults.standard.set(tempURL.absoluteURL.path, forKey: kLastUsedFileKey)
                databaseModel = DatabaseViewModel(dbPath: tempURL.path)
            }
            url.stopAccessingSecurityScopedResource()
        }
    }

    private func copyToTemp(source: URL) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        // Use a unique subdirectory to avoid conflicts and ensure clean state

        let dst = tempDir.appendingPathComponent(source.lastPathComponent)

        do {
            if FileManager.default.fileExists(atPath: dst.path) {
                try FileManager.default.removeItem(atPath: dst.path)
            }

            try FileManager.default.copyItem(at: source, to: dst)
            FileManager.default.createFile(atPath: "\(dst.path)-wal", contents: nil)
            try FileManager.default.removeItem(atPath: "\(dst.path)-wal")
            return dst
        } catch {
            LoggerProxy.ELog(tag: LogTag.app, msg: "Error copying database to temp: \(error)")
            return nil
        }
    }
}
