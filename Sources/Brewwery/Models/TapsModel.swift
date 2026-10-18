import BrewweryCore
import SwiftUI

/// Backs the Taps page. The legacy page kept this state inline; it is extracted here so the
/// view stays declarative and the tap mutations can be tested independently.
@MainActor
@Observable
final class TapsModel {
    private(set) var taps: [BrewTap] = []
    private(set) var isLoading = true
    private(set) var isWorking = false
    private(set) var error: BrewweryError?

    private let client: HomebrewClient
    private let operations: OperationCoordinator

    init(client: HomebrewClient, operations: OperationCoordinator? = nil) {
        self.client = client
        self.operations = operations ?? OperationCoordinator(client: client)
    }

    var sortedTaps: [BrewTap] {
        taps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func refresh() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            taps = try await client.taps()
        } catch {
            self.error = error
        }
    }

    /// Adds or removes a tap. Returns the command output on success.
    func perform(_ action: TapAction, name: String) async -> Result<ProcessOutput, BrewweryError> {
        guard !isWorking else { return .failure(.operationInProgress) }
        isWorking = true
        error = nil
        defer { isWorking = false }

        do {
            let output = try await operations.runBuffered(action == .tap ? .addTap(name: name) : .removeTap(name: name))
            await refresh()
            return .success(output)
        } catch {
            if error.code != .operationInProgress { await refresh() }
            self.error = error
            return .failure(error)
        }
    }
}
