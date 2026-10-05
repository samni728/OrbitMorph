import XCTest
@testable import OrbitMorphCore

final class CommonFormatGapTests: XCTestCase {
    func testNewFormatFamiliesNormalizeAndClassify() throws {
        let families = ["spreadsheet": ["xls", "xlsx", "ods"], "presentation": ["ppt", "pptx", "odp"],
                        "ebook": ["epub", "mobi", "azw3"], "video": ["flv", "ts", "3gp"],
                        "audio": ["caf"], "image": ["ico", "jp2", "jxl", "psd"]]
        for (kind, extensions) in families {
            for ext in extensions {
                XCTAssertEqual(try XCTUnwrap(FormatID(extension: ext)).kind.rawValue, kind)
            }
        }
        XCTAssertEqual(FormatID(extension: "mts"), FormatID(extension: "ts"))
        XCTAssertEqual(FormatID(extension: "m2ts"), FormatID(extension: "ts"))
        XCTAssertEqual(FormatID(extension: "j2k"), FormatID(extension: "jp2"))
    }

    func testPDFAndImageCanExtractTextLocally() {
        let registry = ConversionRegistry(dependencies: .init(overrides: ["magick": nil, "soffice": nil, "ebook-convert": nil]))
        XCTAssertTrue(registry.targets(for: .pdf).contains(.txt))
        XCTAssertTrue(registry.targets(for: .png).contains(.txt))
        XCTAssertTrue(registry.targets(for: .pdf).contains(.docx), "PDF text extraction should support an editable text document")
    }

    func testMissingOfficeAndEbookDependenciesHideTheirRoutes() throws {
        let registry = ConversionRegistry(dependencies: .init(overrides: ["soffice": nil, "ebook-convert": nil]))
        for ext in ["xls", "xlsx", "ods", "ppt", "pptx", "odp", "epub", "mobi", "azw3"] {
            XCTAssertTrue(registry.targets(for: try XCTUnwrap(FormatID(extension: ext))).isEmpty)
        }
    }

    func testExtendedMediaUseExplicitContainerAndCodecs() throws {
        let expected = ["flv": "flv", "ts": "mpegts", "3gp": "3gp", "caf": "caf"]
        for (ext, container) in expected {
            let format = try XCTUnwrap(FormatID(extension: ext))
            let invocation = FFmpegAdapter.invocation(input: URL(fileURLWithPath: "/tmp/source.mov"),
                                                      output: URL(fileURLWithPath: "/tmp/result.\(ext)"),
                                                      target: format, ffmpegPath: "/opt/homebrew/bin/ffmpeg")
            let index = try XCTUnwrap(invocation.arguments.firstIndex(of: "-f"))
            XCTAssertEqual(invocation.arguments[index + 1], container)
            XCTAssertTrue(invocation.arguments.contains(ext == "caf" ? "pcm_s16le" : "-c:v"))
        }
    }

    func testFalseImageCapabilityDoesNotAdvertiseExtendedTargets() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fake = root.appendingPathComponent("magick")
        try "#!/bin/sh\nexit 0\n".write(to: fake, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)
        let registry = ConversionRegistry(dependencies: .init(overrides: ["magick": fake.path]))
        for ext in ["ico", "jp2", "jxl"] {
            XCTAssertFalse(registry.targets(for: .png).contains(try XCTUnwrap(FormatID(extension: ext))))
        }
        XCTAssertFalse(registry.targets(for: try XCTUnwrap(FormatID(extension: "psd"))).contains(.png))
    }
}
