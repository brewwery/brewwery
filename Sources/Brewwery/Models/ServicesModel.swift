import BrewweryCore
import SwiftUI

/// `hooks/use-services.ts`.
@MainActor
@Observable
final class ServicesModel {
    private(set) var services: [BrewService] = []
    private(set) var isLoading = true
    private(set) var error: BrewweryError?

    private let client: HomebrewClient

    init(client: HomebrewClient) {
        self.client = client
    }

    func count(of status: ServiceStatus) -> Int {
        services.count { $0.status == status }
    }

    /// Running services first, then the rest — the Dashboard preview order.
    var runningFirst: [BrewService] {
        services.filter { $0.status == .started } + services.filter { $0.status != .started }
    }

    func refresh() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            services = try await client.services()
        } catch {
            self.error = error
        }
    }
}
