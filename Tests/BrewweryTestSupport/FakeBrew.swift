import Foundation
import BrewweryCore

/// A test double for the `brew` executable.
///
/// Running the real Homebrew in tests would be slow, mutate the developer's machine and make
/// results depend on what happens to be installed. This script answers the handful of
/// subcommands the runner tests exercise — including one that forks a grandchild, so
/// process-group cancellation can be verified end to end.
public struct FakeBrew: Sendable {
    public let directory: URL
    public let executable: URL
    /// Written by the long-running subcommand with the PID of the child it forked.
    public let grandchildPIDFile: URL
    /// Present only when a test asks for outdated packages. Without it `brew outdated`
    /// fails, which is what the error-path tests rely on.
    public let outdatedFile: URL

    public init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("brewwery-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        executable = directory.appendingPathComponent("brew")
        grandchildPIDFile = directory.appendingPathComponent("grandchild.pid")
        outdatedFile = directory.appendingPathComponent("outdated.json")

        let script = """
        #!/bin/sh
        case "$1" in
          --version)
            echo "Homebrew 4.5.0-test"
            echo "Homebrew/homebrew-core (git revision test)"
            exit 0
            ;;
          config)
            echo "HOMEBREW_VERSION: 4.5.0-test"
            echo "HOMEBREW_PREFIX: /opt/homebrew"
            echo "macOS: 15.3-arm64"
            exit 0
            ;;
          list)
            case "$*" in
              *--json=v2*)
                echo "Error: invalid option: --json=v2 (needless argument)" >&2
                exit 1
                ;;
              *)
                echo '{"formulae":[{"name":"wget","versions":["1.25.0"]}],"casks":[]}'
                exit 0
                ;;
            esac
            ;;
          leaves)
            printf '  redis  \\npostgresql@17\\n\\n'
            exit 0
            ;;
          doctor)
            echo "Warning: Broken symlinks were found"
            echo "Run brew cleanup."
            exit 1
            ;;
          outdated)
            if [ -f "\(outdatedFile.path)" ]; then
              cat "\(outdatedFile.path)"
              exit 0
            fi
            echo "boom: could not reach formulae.brew.sh" >&2
            exit 2
            ;;
          cleanup)
            echo "==> first"
            sleep 0.2
            echo "==> second"
            echo "a warning" >&2
            exit 0
            ;;
          services)
            case "$2" in
              list)
                echo '[{"name":"redis","status":"started","user":"umid","file":"/tmp/homebrew.mxcl.redis.plist"},{"name":"etcd","status":"none"}]'
                exit 0
                ;;
              *)
                if [ "$3" = "broken" ]; then
                  echo "Error: Failure while executing; launchctl bootstrap exited 5." >&2
                  exit 1
                fi
                echo "==> Successfully ran $2 for $3"
                exit 0
                ;;
            esac
            ;;
          tap)
            [ -z "$2" ] && printf 'homebrew/core\nmongodb/brew\n'
            exit 0
            ;;
          install|uninstall)
            echo "==> Fetching $2"
            sleep 0.3
            echo "==> Downloading https://ghcr.io/v2/homebrew/core/$2/blobs/sha256:abc"
            sleep 0.3
            echo "Warning: $2 was built for testing" >&2
            echo "==> Pouring $2--1.0.arm64_sequoia.bottle.tar.gz"
            sleep 0.2
            echo "/opt/homebrew/Cellar/$2/1.0: 12 files, 180KB"
            exit 0
            ;;
          search)
            case "$2" in
              --formula) printf 'hello\nhello-world\n' ;;
              --cask) printf 'hello-app\n' ;;
            esac
            exit 0
            ;;
          info)
            echo '{"formulae":[{"name":"hello","full_name":"hello","desc":"Program providing model for GNU coding standards","homepage":"https://www.gnu.org/software/hello/","versions":{"stable":"2.12.2"},"dependencies":[],"installed":[]}],"casks":[]}'
            exit 0
            ;;
          upgrade)
            echo "==> Upgrading 1 outdated package"
            sleep 120 &
            echo $! > "\(grandchildPIDFile.path)"
            wait
            exit 0
            ;;
        esac
        exit 0
        """

        try script.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
    }

    /// Makes `brew outdated` succeed with `formulae` outdated formulae and `casks` outdated
    /// casks, until `clearOutdated()` empties it again.
    public func setOutdated(formulae: [String] = [], casks: [String] = []) throws {
        func entries(_ names: [String]) -> String {
            names
                .map { #"{"name":"\#($0)","installed_versions":["1.0.0"],"current_version":"1.1.0","pinned":false}"# }
                .joined(separator: ",")
        }
        let json = #"{"formulae":[\#(entries(formulae))],"casks":[\#(entries(casks))]}"#
        try json.write(to: outdatedFile, atomically: true, encoding: .utf8)
    }

    public func clearOutdated() {
        try? FileManager.default.removeItem(at: outdatedFile)
    }

    public func cleanUp() {
        try? FileManager.default.removeItem(at: directory)
    }

    /// A client that can only ever reach this double.
    ///
    /// Setting the custom path is not enough on its own: clearing it — which the app does at
    /// launch when no path is stored — would fall back to `/opt/homebrew/bin/brew`. The
    /// standard locations are therefore removed and `PATH` points only at this directory, so
    /// even a detector with no custom path resolves to the double rather than the real
    /// Homebrew on the Mac running the tests.
    public func makeClient() -> HomebrewClient {
        HomebrewClient(detector: makeDetector())
    }

    public func makeDetector() -> HomebrewDetector {
        HomebrewDetector(
            customPath: executable.path,
            candidatePaths: [],
            environment: ["PATH": directory.path]
        )
    }

    /// Waits for the long-running subcommand to record its grandchild's PID.
    public func waitForGrandchildPID(timeout: TimeInterval = 5) async -> pid_t? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let text = try? String(contentsOf: grandchildPIDFile, encoding: .utf8),
               let pid = pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return pid
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return nil
    }

    /// Polls until the process is gone, so the assertion does not race the signal.
    public static func waitUntilGone(_ pid: pid_t, timeout: TimeInterval = 8) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if kill(pid, 0) != 0 { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return false
    }
}
