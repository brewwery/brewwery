import Foundation

public enum DoctorSeverity: String, Codable, Sendable, Hashable {
    case info
    case warning
    case error
}

public struct DoctorDiagnostic: Identifiable, Hashable, Codable, Sendable {
    public var severity: DoctorSeverity
    public var title: String
    public var message: String
    public var raw: String?

    public var id: String { "\(title)|\(message)" }

    public init(severity: DoctorSeverity, title: String, message: String, raw: String? = nil) {
        self.severity = severity
        self.title = title
        self.message = message
        self.raw = raw
    }
}

public struct DoctorResult: Hashable, Codable, Sendable {
    public var healthy: Bool
    public var diagnostics: [DoctorDiagnostic]
    public var rawOutput: String?

    public init(healthy: Bool, diagnostics: [DoctorDiagnostic], rawOutput: String? = nil) {
        self.healthy = healthy
        self.diagnostics = diagnostics
        self.rawOutput = rawOutput
    }
}
