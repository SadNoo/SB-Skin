import Foundation
import Testing
@testable import SkywaveShared

@Test func bytesFormatting() {
    #expect(SkinFormat.bytes(0) == "0 B")
    #expect(SkinFormat.bytes(1536) == "1.5 KB")
    #expect(SkinFormat.rate(19_503_513) == "18.6 MB/s")
    #expect(SkinFormat.bytes(5_153_960_755) == "4.8 GB")
}

@Test func durationFormatting() {
    #expect(SkinFormat.duration(6137) == "1:42:17")
    #expect(SkinFormat.duration(252) == "4:12")
}

@Test func latencyGrades() {
    #expect(LatencyGrade(delay: 0) == .untested)
    #expect(LatencyGrade(delay: 186) == .excellent)
    #expect(LatencyGrade(delay: 612) == .good)
    #expect(LatencyGrade(delay: 905) == .fair)
    #expect(LatencyGrade(delay: 2000) == .poor)
    #expect(LatencyGrade(delay: .max) == .unreachable)
}

@Test func deepLinks() {
    let url = SkinDeepLink.nodes.url(scheme: "demo")
    #expect(url?.absoluteString == "demo://skywave/nodes")
    #expect(SkinDeepLink(url: url!) == .nodes)
    #expect(SkinDeepLink(url: URL(string: "demo://import-remote-profile?url=x")!) == nil)
}

@testable import Skywave

@Test func regionInference() {
    #expect(SkinRegion.infer(from: "🇭🇰 Hong Kong 01")?.code == "HK")
    #expect(SkinRegion.infer(from: "香港 IPLC 02")?.code == "HK")
    #expect(SkinRegion.infer(from: "US-LosAngeles 01")?.code == "US")
    #expect(SkinRegion.infer(from: "Russia 01")?.code == "RU")
    #expect(SkinRegion.infer(from: "日本 东京 03")?.code == "JP")
    #expect(SkinRegion.infer(from: "Auto")?.code == nil)
    #expect(SkinRegion.stripFlag("🇯🇵 Japan 01") == "Japan 01")
    #expect(!WorldMask.landCells.isEmpty)
}
