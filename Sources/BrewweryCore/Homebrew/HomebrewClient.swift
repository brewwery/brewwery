import Foundation

/// The application-facing Homebrew API.
///
/// Feature models call these methods directly — there is no IPC layer to cross, because
/// `HomebrewClient`, `HomebrewRunner` and `HomebrewDetector` all live in the same process.
/// Every method is `async` and isolated to this actor, so no Homebrew work touches the main
/// actor and no two calls race over the detector's custom-path state.
public actor HomebrewClient {
    public let detector: HomebrewDetector
    private let runner: HomebrewRunner

    public init(
        detector: HomebrewDetector = HomebrewDetector(),
        environment: [String: String] = HomebrewEnvironment.values()
    ) {
        self.detector = detector
        self.runner = HomebrewRunner(detector: detector, environment: environment)
    }

    // MARK: - System

    public func detect() async -> BrewDetectionResult {
        await detector.detect()
    }

    /// Throws `HOMEBREW_NOT_FOUND` when Homebrew is unavailable, so every feature can fail
    /// the same way and render the same recovery panel.
    public func requireHomebrew() async throws(BrewweryError) {
        guard await detector.detect().found else { throw .homebrewNotFound }
    }

    public func brewInfo() async throws(BrewweryError) -> BrewInfo {
        let detection = await detector.detect()
        guard detection.found, let path = detection.path else { throw .homebrewNotFound }

        // `brew config` and `brew --version` are best-effort: a partial answer is better
        // than an error page, matching `get_brew_info`'s `.ok()` handling.
        let config = try? await runner.run(.config).stdout
        let version = try? await runner.run(.version).stdout

        return BrewConfigParser.makeInfo(path: path, configOutput: config, versionOutput: version)
    }

    public func validate(path: String) -> BrewPathValidationResult {
        HomebrewDetector.validate(path: path)
    }

    @discardableResult
    public func setCustomPath(_ path: String) async -> BrewPathValidationResult {
        await detector.setCustomPath(path)
    }

    public func clearCustomPath() async {
        await detector.clearCustomPath()
    }

    // MARK: - Packages

    public func installedFormulae() async throws(BrewweryError) -> [Formula] {
        try await requireHomebrew()
        let output = try await runner.run(.listFormulae, fallback: .listFormulaeFallback)
        return try PackageParser.parseFormulae(json: output.stdout)
    }

    public func installedCasks() async throws(BrewweryError) -> [Cask] {
        try await requireHomebrew()
        let output = try await runner.run(.listCasks, fallback: .listCasksFallback)
        return try PackageParser.parseCasks(json: output.stdout)
    }

    public func leaves() async throws(BrewweryError) -> [String] {
        try await requireHomebrew()
        return PackageParser.parseNameLines(try await runner.run(.leaves).stdout)
    }

    public func dependents(of formula: String) async throws(BrewweryError) -> [String] {
        try await requireHomebrew()
        do {
            return PackageParser.parseNameLines(try await runner.run(.dependents(formula: formula)).stdout)
        } catch {
            throw error.mapped(to: .packageInfoFailed, phase: "info")
        }
    }

    /// `search_packages` — formulae first, then casks, concatenated in that order.
    public func search(_ query: String) async throws(BrewweryError) -> [PackageSearchResult] {
        try await requireHomebrew()
        do {
            let formulae = PackageParser.parseSearchLines(
                try await runner.run(.searchFormulae(query: query)).stdout,
                kind: .formula
            )
            let casks = PackageParser.parseSearchLines(
                try await runner.run(.searchCasks(query: query)).stdout,
                kind: .cask
            )
            return formulae + casks
        } catch {
            throw error.mapped(to: .packageSearchFailed, phase: "search")
        }
    }

    public func packageInfo(for reference: PackageReference) async throws(BrewweryError) -> PackageInfo {
        try await requireHomebrew()
        do {
            switch reference.kind {
            case .formula:
                let output = try await runner.run(.formulaInfo(name: reference.name))
                return try PackageParser.parseFormulaInfo(json: output.stdout)
            case .cask:
                let output = try await runner.run(.caskInfo(token: reference.name))
                return try PackageParser.parseCaskInfo(json: output.stdout)
            }
        } catch {
            throw error.mapped(to: .packageInfoFailed, phase: "info")
        }
    }

    // MARK: - Updates

    public func outdated() async throws(BrewweryError) -> [OutdatedPackage] {
        try await requireHomebrew()
        do {
            return try OutdatedParser.parse(json: try await runner.run(.outdated).stdout)
        } catch {
            throw error.code == .brewJSONParseFailed
                ? BrewweryError(code: .updatesParseFailed, message: error.message, raw: error.raw)
                : error
        }
    }

    /// `brew update` refreshes Homebrew's own metadata. It is never run automatically — the
    /// Updates and Settings pages both confirm first.
    @discardableResult
    public func updateMetadata() async throws(BrewweryError) -> ProcessOutput {
        try await requireHomebrew()
        do {
            return try await runner.run(.update)
        } catch {
            throw error.code == .brewCommandFailed
                ? BrewweryError(code: .brewUpdateFailed, message: "Homebrew metadata update failed.", raw: error.raw ?? error.message)
                : error
        }
    }

    // MARK: - Taps

    public func taps() async throws(BrewweryError) -> [BrewTap] {
        try await requireHomebrew()
        return TapParser.parse(try await runner.run(.listTaps).stdout)
    }

    @discardableResult
    public func addTap(_ name: String) async throws(BrewweryError) -> ProcessOutput {
        try await requireHomebrew()
        do {
            return try await runner.run(.addTap(name: name))
        } catch {
            throw error.mappedTap(action: "add")
        }
    }

    @discardableResult
    public func removeTap(_ name: String) async throws(BrewweryError) -> ProcessOutput {
        try await requireHomebrew()
        do {
            return try await runner.run(.removeTap(name: name))
        } catch {
            throw error.mappedTap(action: "remove")
        }
    }

    // MARK: - Services

    public func services() async throws(BrewweryError) -> [BrewService] {
        try await requireHomebrew()
        do {
            return try ServiceParser.parse(json: try await runner.run(.listServices).stdout)
        } catch {
            throw error.mappedService()
        }
    }

    // MARK: - Cleanup

    public func cleanupPreview() async throws(BrewweryError) -> CleanupPreview {
        try await requireHomebrew()
        do {
            return CleanupParser.parsePreview(try await runner.run(.cleanupPreview).stdout)
        } catch {
            throw BrewweryError(
                code: .cleanupPreviewFailed,
                message: "Failed to preview Homebrew cleanup.",
                raw: error.raw ?? error.message
            )
        }
    }

    // MARK: - Doctor

    /// `brew doctor` exits non-zero whenever it finds anything, so its status is ignored and
    /// stdout and stderr are joined before parsing.
    public func doctor() async throws(BrewweryError) -> DoctorResult {
        try await requireHomebrew()
        do {
            let output = try await runner.runPermissive(.doctor)
            let rawOutput = [output.stdout, output.stderr]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            return DoctorParser.makeResult(rawOutput: rawOutput)
        } catch {
            throw BrewweryError(
                code: .doctorFailed,
                message: "Failed to run brew doctor.",
                raw: error.raw ?? error.message
            )
        }
    }

    // MARK: - Brewfile

    /// Dumps the current environment to a temporary Brewfile and reads it back.
    public func exportBrewfile() async throws(BrewweryError) -> BrewfileDocument {
        try await requireHomebrew()
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("brewwery-Brewfile-\(ProcessInfo.processInfo.processIdentifier)")
            .path

        do {
            try await runner.run(.brewfileDump(path: path))
            let content = try String(contentsOfFile: path, encoding: .utf8)
            return BrewfileDocument(path: path, entries: BrewfileParser.parse(content), rawContent: content)
        } catch let error as BrewweryError {
            throw BrewweryError(
                code: .brewfileExportFailed,
                message: "Failed to export Brewfile.",
                raw: error.raw ?? error.message
            )
        } catch {
            throw BrewweryError(
                code: .brewfileExportFailed,
                message: "Failed to export Brewfile.",
                raw: error.localizedDescription
            )
        }
    }

    /// Reads a user-chosen Brewfile. Unlike export, this does not require Homebrew — it only
    /// reads a file — but the path is validated and the size is capped first.
    public func readBrewfile(at path: String) throws(BrewweryError) -> BrewfileDocument {
        try HomebrewIdentifier.validateBrewfilePath(path)

        let content: String
        do {
            content = try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw BrewweryError(
                code: .brewfileReadFailed,
                message: "Failed to read this Brewfile.",
                raw: error.localizedDescription
            )
        }

        guard content.utf8.count <= HomebrewIdentifier.maximumBrewfileBytes else {
            throw BrewweryError.invalidFilePath("Brewfile is too large.")
        }

        return BrewfileDocument(path: path, entries: BrewfileParser.parse(content), rawContent: content)
    }

    // MARK: - Streaming operations

    public func stream(
        _ command: HomebrewCommand,
        kind: OperationKind,
        id: UUID
    ) async throws(BrewweryError) -> AsyncStream<OperationEvent> {
        try await requireHomebrew()
        return try await runner.stream(command, kind: kind, id: id)
    }

    @discardableResult
    public func cancelOperation(_ id: UUID) async -> Bool {
        await runner.cancel(id)
    }
}

// MARK: - Error mapping

private extension BrewweryError {
    /// `mapPackageError` — validation and parse failures keep their specific codes; anything
    /// else becomes the phase's failure code.
    func mapped(to code: BrewweryErrorCode, phase: String) -> BrewweryError {
        switch self.code {
        case .invalidPackageName, .invalidCaskToken, .brewJSONParseFailed, .homebrewNotFound, .packageInfoFailed:
            self
        default:
            BrewweryError(code: code, message: "Package \(phase) failed.", raw: raw ?? message)
        }
    }

    /// `mapTapError`.
    func mappedTap(action: String) -> BrewweryError {
        guard code != .invalidTapName, code != .homebrewNotFound else { return self }
        return BrewweryError(
            code: .tapCommandFailed,
            message: "Failed to \(action) Homebrew tap.",
            raw: raw ?? message
        )
    }

    /// `mapServiceError` — keeps the two specific recovery messages the legacy app added
    /// for a stale `brew services` and for an offline metadata host.
    func mappedService() -> BrewweryError {
        let text = (raw ?? message).lowercased()

        if code == .invalidServiceName || code == .homebrewNotFound { return self }

        if text.contains("undefined method 'stop_timeout'") {
            return BrewweryError(
                code: .serviceCommandFailed,
                message: "Homebrew services is incompatible with the current Homebrew metadata. Update Homebrew, then retry.",
                raw: raw ?? message
            )
        }
        if text.contains("could not resolve host") || text.contains("formulae.brew.sh") {
            return BrewweryError(
                code: .serviceCommandFailed,
                message: "Homebrew could not reach its package metadata service. Check your connection, then retry.",
                raw: raw ?? message
            )
        }
        if code == .brewJSONParseFailed { return self }

        return BrewweryError(
            code: .serviceCommandFailed,
            message: "Homebrew service command failed.",
            raw: raw ?? message
        )
    }
}
