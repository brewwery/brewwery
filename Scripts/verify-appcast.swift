import CryptoKit
import Darwin
import Foundation

// Validates the release feed against the exact artifact and the bundle's public key.
// No keychain access, private keys, or network requests are needed.
struct VerificationError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw VerificationError(message) }
}

func one(_ node: XMLNode, _ path: String) throws -> XMLNode {
    let matches = try node.nodes(forXPath: path)
    guard matches.count == 1, let result = matches.first else {
        throw VerificationError("Expected exactly one \(path); found \(matches.count).")
    }
    return result
}

let sparkleNamespace = "http://www.andymatuschak.org/xml-namespaces/sparkle"

func sparkleValue(_ node: XMLNode, _ name: String) throws -> String {
    let matches = (node as? XMLElement)?.elements(forLocalName: name, uri: sparkleNamespace) ?? []
    guard matches.count == 1, let result = matches.first?.stringValue else {
        throw VerificationError("Expected exactly one Sparkle \(name) element.")
    }
    return result
}

do {
    let args = Array(CommandLine.arguments.dropFirst())
    guard (3...4).contains(args.count) else {
        throw VerificationError("Usage: swift Scripts/verify-appcast.swift <appcast.xml> <DMG> <Info.plist> [download-url-prefix]")
    }
    let plistData = try Data(contentsOf: URL(fileURLWithPath: args[2]))
    guard let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
          let version = plist["CFBundleShortVersionString"] as? String,
          let build = plist["CFBundleVersion"] as? String,
          let minOS = plist["LSMinimumSystemVersion"] as? String,
          let encodedKey = plist["SUPublicEDKey"] as? String,
          let keyData = Data(base64Encoded: encodedKey) else {
        throw VerificationError("Missing version, build, minimum OS or Sparkle public key in Info.plist.")
    }
    try require(plist["CFBundleIdentifier"] as? String == "com.brewwery.app", "Unexpected bundle identifier.")
    let prefix = args.count == 4 ? args[3] : "https://github.com/brewwery/brewwery/releases/download/v\(version)/"
    try require(URL(string: prefix)?.scheme == "https" && prefix.hasSuffix("/"), "Download prefix must be HTTPS and end in /.")

    let document = try XMLDocument(contentsOf: URL(fileURLWithPath: args[0]), options: .nodeLoadExternalEntitiesNever)
    try require(document.dtd == nil, "Appcasts must not contain a DTD.")
    let item = try one(document, "/rss/channel/item")
    try require(try sparkleValue(item, "version") == build, "Appcast build does not match the bundle.")
    try require(try sparkleValue(item, "shortVersionString") == version, "Appcast version does not match the bundle.")
    try require(try sparkleValue(item, "minimumSystemVersion") == minOS, "Appcast minimum OS does not match the bundle.")
    try require(try item.nodes(forXPath: "*[local-name()='deltas']").isEmpty, "This release feed must not advertise delta updates.")
    guard let enclosure = try one(item, "enclosure") as? XMLElement else {
        throw VerificationError("Missing update enclosure.")
    }
    let expectedURL = "\(prefix)Brewwery-\(version).dmg"
    try require(enclosure.attribute(forName: "url")?.stringValue == expectedURL, "Enclosure URL is not \(expectedURL).")
    let artifact = try Data(contentsOf: URL(fileURLWithPath: args[1]), options: .mappedIfSafe)
    try require(Int(enclosure.attribute(forName: "length")?.stringValue ?? "") == artifact.count, "Enclosure length does not match the DMG.")
    guard let signatureString = enclosure.attribute(forLocalName: "edSignature", uri: sparkleNamespace)?.stringValue,
          let signature = Data(base64Encoded: signatureString) else {
        throw VerificationError("Missing EdDSA signature.")
    }
    let key = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
    try require(key.isValidSignature(signature, for: artifact), "DMG EdDSA signature does not match the bundle's public key.")
    let hash = SHA256.hash(data: artifact).map { String(format: "%02x", $0) }.joined()
    print("Verified appcast: Brewwery \(version) (\(build)), macOS \(minOS)+, \(artifact.count) bytes")
    print("Download: \(expectedURL)")
    print("SHA-256: \(hash)")
} catch {
    fputs("Appcast verification failed: \(error)\n", stderr)
    exit(1)
}
