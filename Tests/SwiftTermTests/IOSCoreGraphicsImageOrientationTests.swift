#if os(iOS)
import Foundation
import Testing
import UIKit

@testable import SwiftTerm

@Suite(.serialized)
@MainActor
struct IOSCoreGraphicsImageOrientationTests {
    private static let width = 320
    private static let height = 120

    private func renderPixels(_ terminalView: TerminalView) throws -> (bytes: [UInt8], width: Int, height: Int, bytesPerRow: Int, isBGRA: Bool) {
        let renderer = UIGraphicsImageRenderer(size: terminalView.bounds.size)
        let uiImage = renderer.image { _ in
            terminalView.draw(terminalView.bounds)
        }
        let cgImage = try #require(uiImage.cgImage)
        let dataProvider = try #require(cgImage.dataProvider)
        let data = try #require(dataProvider.data)
        let length = CFDataGetLength(data)
        var bytes = [UInt8](repeating: 0, count: length)
        CFDataGetBytes(data, CFRange(location: 0, length: length), &bytes)
        let isBGRA = cgImage.bitmapInfo.contains(.byteOrder32Little)
        return (bytes, cgImage.width, cgImage.height, cgImage.bytesPerRow, isBGRA)
    }

    /// Average row of the pixels that match `predicate`, counted from the top.
    private func meanRow(
        _ frame: (bytes: [UInt8], width: Int, height: Int, bytesPerRow: Int, isBGRA: Bool),
        where predicate: (_ r: UInt8, _ g: UInt8, _ b: UInt8) -> Bool
    ) -> Double? {
        var total = 0
        var count = 0
        for y in 0..<frame.height {
            let rowOffset = y * frame.bytesPerRow
            for x in 0..<frame.width {
                let i = rowOffset + x * 4
                guard i + 3 < frame.bytes.count else { continue }
                let r: UInt8
                let g = frame.bytes[i + 1]
                let b: UInt8
                if frame.isBGRA {
                    b = frame.bytes[i + 0]
                    r = frame.bytes[i + 2]
                } else {
                    r = frame.bytes[i + 0]
                    b = frame.bytes[i + 2]
                }
                if predicate(r, g, b) {
                    total += y
                    count += 1
                }
            }
        }
        return count == 0 ? nil : Double(total) / Double(count)
    }

    @Test func kittyDirectPlacementDrawsTopRowsAtTheTop() throws {
        let view = TerminalView(frame: CGRect(x: 0, y: 0, width: Self.width, height: Self.height))
        let pixels: [UInt8] = [
            255, 0, 0, 255,   255, 0, 0, 255,
            0, 0, 255, 255,   0, 0, 255, 255
        ]
        let base64 = Data(pixels).base64EncodedString()
        view.feed(text: "\u{1b}[H\u{1b}_Ga=T,f=32,s=2,v=2,c=4,r=2,i=7,q=2;\(base64)\u{1b}\\")
        view.frameTick()

        let frame = try renderPixels(view)
        let red = try #require(meanRow(frame) { r, g, b in r > 200 && g < 60 && b < 60 })
        let blue = try #require(meanRow(frame) { r, g, b in b > 200 && r < 60 && g < 60 })
        #expect(red < blue, "red band drawn at row \(red), blue band at row \(blue)")
    }

    @Test func kittyUnicodePlaceholderDrawsTopRowsAtTheTop() throws {
        let view = TerminalView(frame: CGRect(x: 0, y: 0, width: Self.width, height: Self.height))
        let pixels: [UInt8] = [
            255, 0, 0, 255,   255, 0, 0, 255,
            0, 0, 255, 255,   0, 0, 255, 255
        ]
        let base64 = Data(pixels).base64EncodedString()
        view.feed(text: "\u{1b}_Ga=t,f=32,s=2,v=2,i=7,q=2;\(base64)\u{1b}\\")
        view.feed(text: "\u{1b}_Ga=p,U=1,i=7,c=4,r=2,q=2\u{1b}\\")
        let row0 = "\u{10EEEE}\u{0305}\u{0305}\u{10EEEE}\u{0305}\u{030D}\u{10EEEE}\u{0305}\u{030E}\u{10EEEE}\u{0305}\u{0310}"
        let row1 = "\u{10EEEE}\u{030D}\u{0305}\u{10EEEE}\u{030D}\u{030D}\u{10EEEE}\u{030D}\u{030E}\u{10EEEE}\u{030D}\u{0310}"
        view.feed(text: "\u{1b}[1;1H\u{1b}[38;5;7m\(row0)\u{1b}[2;1H\u{1b}[38;5;7m\(row1)")
        view.frameTick()

        let frame = try renderPixels(view)
        let red = try #require(meanRow(frame) { r, g, b in r > 200 && g < 60 && b < 60 })
        let blue = try #require(meanRow(frame) { r, g, b in b > 200 && r < 60 && g < 60 })
        #expect(red < blue, "red band drawn at row \(red), blue band at row \(blue)")
    }
}
#endif
