import OSLog

/// Structured logging categories. `print()` is never used for production diagnostics.
///
/// Package names and paths are logged; command output and user file contents are not, so a
/// sysdiagnose never carries the contents of a Brewfile or of an install log.
public enum Log {
    private static let subsystem = "com.brewwery.app"

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let homebrew = Logger(subsystem: subsystem, category: "homebrew")
    public static let process = Logger(subsystem: subsystem, category: "process")
    public static let packages = Logger(subsystem: subsystem, category: "packages")
    public static let services = Logger(subsystem: subsystem, category: "services")
    public static let updates = Logger(subsystem: subsystem, category: "updates")
    public static let cleanup = Logger(subsystem: subsystem, category: "cleanup")
    public static let doctor = Logger(subsystem: subsystem, category: "doctor")
    public static let persistence = Logger(subsystem: subsystem, category: "persistence")
    public static let sparkle = Logger(subsystem: subsystem, category: "sparkle")
}
