import Foundation

// A headless packaging probe: never initialise the app, updater, stores or Homebrew.
if CommandLine.arguments.dropFirst() == ["--build-info"] {
    let info = [
        "version": AppInfo.fallbackVersion,
        "build": AppInfo.compiledBuild,
        "bundleIdentifier": AppInfo.bundleIdentifier,
        "channel": AppInfo.channel
    ]
    let data = try JSONSerialization.data(withJSONObject: info, options: [.sortedKeys])
    print(String(decoding: data, as: UTF8.self))
} else {
    do { _ = try QALaunch.parse(CommandLine.arguments) }
    catch {
        FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
        exit(64)
    }
    BrewweryApp.main()
}
