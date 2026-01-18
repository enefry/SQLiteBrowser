import AVKit
import SwiftUI
import LoggerProxy

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// 用于展示 Blob 数据的视图，支持图像、视频和十六进制显示
struct MediaView: View {
    let data: Data
    @State private var showHex = false
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 0) {
            if showHex {
                ScrollView {
                    Text(data.map { String(format: "%02hhx", $0) }.joined(separator: " "))
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
            } else {
                #if os(macOS)
                    if let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VideoPlayer(player: player)
                            .onAppear {
                                if player == nil {
                                    setupVideoPlayer()
                                }
                            }
                    }
                #else
                    if let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VideoPlayer(player: player)
                            .onAppear {
                                if player == nil {
                                    setupVideoPlayer()
                                }
                            }
                    }
                #endif
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(showHex ? "Show Preview" : "Show Hex") {
                    showHex.toggle()
                }
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .border(Color.yellow, width: 4)
    }

    private func setupVideoPlayer() {
        // 尝试将 Data 写入临时文件以播放视频
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".mp4")

        do {
            try data.write(to: tempFile)
            player = AVPlayer(url: tempFile)
            player?.play()
        } catch {
            LoggerProxy.ELog(tag: LogTag.view, msg: "Error writing temp video file: \(error)")
        }
    }
}
