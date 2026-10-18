import CryptoKit
import Darwin
import Foundation

// Synthetic archives and an ephemeral in-memory key keep release checks offline.
guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift Scripts/test-appcast.swift <path/to/verify-appcast.swift>\n", stderr)
    exit(1)
}
let verifier = CommandLine.arguments[1]
let directory = FileManager.default.temporaryDirectory.appendingPathComponent("brewwery-feed-test-\(UUID())")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
let artifact = Data("test update bytes".utf8)
let key = Curve25519.Signing.PrivateKey()
let signature = try key.signature(for: artifact).base64EncodedString()
let feed = """
<?xml version="1.0"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0"><channel><item>
<sparkle:version>111</sparkle:version><sparkle:shortVersionString>1.1.1</sparkle:shortVersionString>
<sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
<enclosure url="https://github.com/brewwery/brewwery/releases/download/v1.1.1/Brewwery-1.1.1.dmg" length="\(artifact.count)" sparkle:edSignature="\(signature)"/>
</item></channel></rss>
"""
let plist: [String: Any] = [
    "CFBundleIdentifier": "com.brewwery.app", "CFBundleVersion": "111",
    "CFBundleShortVersionString": "1.1.1", "LSMinimumSystemVersion": "14.0",
    "SUPublicEDKey": key.publicKey.rawRepresentation.base64EncodedString()
]
let feedURL = directory.appendingPathComponent("appcast.xml")
let artifactURL = directory.appendingPathComponent("Brewwery-1.1.1.dmg")
let plistURL = directory.appendingPathComponent("Info.plist")
var count = 0

func check(_ name: String, xml: String = feed, data: Data = artifact, metadata: [String: Any] = plist, succeeds: Bool = false) throws {
    try Data(xml.utf8).write(to: feedURL)
    try data.write(to: artifactURL)
    try PropertyListSerialization.data(fromPropertyList: metadata, format: .xml, options: 0).write(to: plistURL)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = [verifier, feedURL.path, artifactURL.path, plistURL.path]
    let output = Pipe()
    process.standardOutput = output
    process.standardError = output
    try process.run()
    let result = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard (process.terminationStatus == 0) == succeeds else {
        fputs("FAIL \(name): status \(process.terminationStatus)\n\(String(decoding: result, as: UTF8.self))", stderr)
        exit(1)
    }
    count += 1
    print("PASS \(name)")
}

try check("valid feed", succeeds: true)
try check("wrong build", xml: feed.replacingOccurrences(of: ">111<", with: ">110<"))
try check("wrong version", xml: feed.replacingOccurrences(of: ">1.1.1<", with: ">1.1.0<"))
try check("wrong minimum OS", xml: feed.replacingOccurrences(of: ">14.0<", with: ">13.0<"))
try check("stale download URL", xml: feed.replacingOccurrences(of: "/v1.1.1/", with: "/v1.1.0/"))
try check("wrong length", xml: feed.replacingOccurrences(of: "length=\"\(artifact.count)\"", with: "length=\"1\""))
try check("invalid signature", xml: feed.replacingOccurrences(of: signature, with: Data(repeating: 0, count: 64).base64EncodedString()))
try check("tampered equal-length artifact", data: Data(repeating: 0, count: artifact.count))
var wrongKey = plist
wrongKey["SUPublicEDKey"] = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation.base64EncodedString()
try check("wrong public key", metadata: wrongKey)
try check("duplicate item", xml: feed.replacingOccurrences(of: "</channel>", with: "<item/></channel>"))
try check("delta advertised", xml: feed.replacingOccurrences(of: "</item>", with: "<sparkle:deltas/></item>"))
try check("DTD rejected", xml: feed.replacingOccurrences(of: "<rss ", with: "<!DOCTYPE rss []><rss "))
try check("wrong namespace", xml: feed.replacingOccurrences(of: "xml-namespaces/sparkle", with: "xml-namespaces/other"))
try check("duplicate version", xml: feed.replacingOccurrences(of: "</item>", with: "<sparkle:version>111</sparkle:version></item>"))
try check("missing signature", xml: feed.replacingOccurrences(of: "sparkle:edSignature=\"\(signature)\"", with: ""))
var wrongBundle = plist
wrongBundle["CFBundleIdentifier"] = "com.example.app"
try check("wrong bundle", metadata: wrongBundle)
print("\(count) appcast verifier checks passed")
