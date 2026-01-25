import AVKit
import LoggerProxy
import SwiftUI

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// 用于展示 Blob 数据的视图，支持图像、视频和十六进制显示
struct MediaView: View {
    @ObservedObject var data: IdentifiableData
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 0) {
            if data.showHex {
                HexView(data: data.data)
            } else {
                #if os(macOS)
                    if let nsImage = NSImage(data: data.data) {
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
                    if let uiImage = UIImage(data: data.data) {
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
                Button(data.showHex ? "Show Preview" : "Show Hex") {
                    data.showHex.toggle()
                }
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setupVideoPlayer() {
        // 尝试将 Data 写入临时文件以播放视频
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".mp4")

        do {
            try data.data.write(to: tempFile)
            player = AVPlayer(url: tempFile)
            player?.play()
        } catch {
            LoggerProxy.ELog(tag: LogTag.view, msg: "Error writing temp video file: \(error)")
        }
    }
}

struct HexView: View {
    let data: Data
    @State private var bytesPerRow = 16
    private let groupSize = 4 // 8 hex chars per group
    let format: String
    init(data: Data, bytesPerRow: Int = 16) {
        self.data = data
        // Initial estimate, will be updated by onAppear/onChange
        self._bytesPerRow = State(initialValue: bytesPerRow)
        
        if data.count < 0xFF {
            format = "%02X"
        } else if data.count < 0xFFFF {
            format = "%04X"
        } else if data.count < 0xFFFFFF {
            format = "%06X"
        } else {
            format = "%08X"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(0 ..< rowCount, id: \.self) { rowIndex in
                        HStack(alignment: .center, spacing: 0) {
                            // Offset Column
                            Text(String(format: format, rowIndex * bytesPerRow))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(.trailing, 4)

                            Divider()
                                .frame(height: 16)

                            // Hex Column
                            Text(hexString(at: rowIndex))
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 4)
                                .foregroundColor(.primary)

                            Divider()
                                .frame(height: 16)

                            // ASCII Column
                            Text(asciiString(at: rowIndex))
                                .font(.system(.caption, design: .monospaced))
                                .padding(.leading, 4)
                                .foregroundColor(.secondary)

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 2)
                        .background(rowIndex % 2 == 0 ? Color.primary.opacity(0.03) : Color.clear)
                        .fixedSize(horizontal: true, vertical: false) // Ensure single line
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
                .frame(minWidth: geometry.size.width, alignment: .topLeading)
            }
            .onChange(of: geometry.size.width) { width in
                calculateBytesPerRow(width: width)
            }
            .onAppear {
                calculateBytesPerRow(width: geometry.size.width)
            }
        }
    }

    private var rowCount: Int {
        guard bytesPerRow > 0 else { return 0 }
        return (data.count + bytesPerRow - 1) / bytesPerRow
    }

    private func calculateBytesPerRow(width: CGFloat) {
        // Estimates for automatic sizing:
        // Font: .caption monospaced is quite narrow.
        // SF Mono Caption size is approx 7pt, but we want to be aggressive to fit more.
        let charWidth: CGFloat = 6.8
        
        let offsetChars: Int
        if data.count < 0xFF {
            offsetChars = 2
        } else if data.count < 0xFFFF {
            offsetChars = 4
        } else if data.count < 0xFFFFFF {
            offsetChars = 6
        } else {
            offsetChars = 8
        }
        
        // Fixed parts width:
        // Offset (offsetChars) + Padding(trailing 4) + Divider(~1) + 
        // Hex Padding(horizontal 8) + Divider(~1) + ASCII Padding(leading 4) + 
        // ScrollView Padding(16) + Safety Buffer (2)
        // Total fixed padding ~= 36
        let paddingOverhead: CGFloat = 36
        let offsetWidth = CGFloat(offsetChars) * charWidth
        let fixedOverhead = paddingOverhead + offsetWidth
        
        let availableWidth = width - fixedOverhead
        
        // Width per byte:
        // Hex: 2 chars
        // Space in Hex: 1 char every 8 bytes -> 0.125 char/byte
        // ASCII: 1 char
        // ASCII Space: 1 char every 8 bytes -> 0.125 char/byte
        // Total chars per byte = 2 + 0.125 + 1 + 0.125 = 3.25
        let widthPerByte = 3.25 * charWidth
        
        if widthPerByte > 0 {
            let possibleBytes = Int(availableWidth / widthPerByte)
            // Snap to multiple of 8
            let snapped = (possibleBytes / 8) * 8
            // Ensure at least 8 bytes
            bytesPerRow = max(8, snapped)
        }
    }

    private func hexString(at row: Int) -> String {
        let start = row * bytesPerRow
        let end = min(start + bytesPerRow, data.count)
        let chunk = data[start ..< end]

        var hex = ""
        for (index, byte) in chunk.enumerated() {
            if index > 0 {
                if index % groupSize == 0 {
                    hex += " " // Space between groups
                }
            }
            hex += String(format: "%02X", byte)
        }

        // Pad the hex string length to align
        // N bytes -> N*2 characters
        // Plus (N/4 - 1) spaces if N % 4 == 0
        let numGroups = (bytesPerRow + groupSize - 1) / groupSize
        let numSpaces = max(0, numGroups - 1)
        let expectedLength = bytesPerRow * 2 + numSpaces

        if hex.count < expectedLength {
            hex = hex.padding(toLength: expectedLength, withPad: " ", startingAt: 0)
        }
        return hex
    }

    private func asciiString(at row: Int) -> String {
        let start = row * bytesPerRow
        let end = min(start + bytesPerRow, data.count)
        let chunk = data[start ..< end]

        return chunk.map { byte -> String in
            (byte >= 0x20 && byte <= 0x7E) ? String(UnicodeScalar(byte)) : "."
        }.joined()
    }
}
