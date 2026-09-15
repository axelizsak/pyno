import AppKit
import Foundation
import OSLog

/// Tells the user when a newer Pyno is on GitHub Releases.
///
/// It never downloads or installs anything by itself: the banner opens the disk image,
/// and the user drags the new copy over the old one. Checked once per launch, and on
/// demand from the Pyno menu.
@MainActor
final class UpdateChecker: ObservableObject {

    struct Release: Equatable {
        let version: String
        let downloadURL: URL
    }

    private static let latestReleaseAPI = URL(string: "https://api.github.com/repos/axelizsak/pyno/releases/latest")!

    /// A newer release than the running one, if the last check found one.
    @Published private(set) var available: Release?
    /// "Later" hides the banner until the next launch.
    @Published var isDismissed = false

    private let logger = Logger(subsystem: "app.pyno", category: "Updates")
    private var checkedAtLaunch = false

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func checkAtLaunch(_ loc: Localization) async {
        guard !checkedAtLaunch else { return }
        checkedAtLaunch = true
        await check(userInitiated: false, loc)
    }

    /// Silent when nothing is new or the network is down, unless the user asked.
    func check(userInitiated: Bool, _ loc: Localization) async {
        do {
            let latest = try await fetchLatest()
            if Self.isNewer(latest.version, than: currentVersion) {
                available = latest
                isDismissed = false
            } else if userInitiated {
                alert(loc[.upToDateTitle], loc.upToDate(currentVersion))
            }
        } catch {
            logger.error("Update check failed: \(error.localizedDescription)")
            if userInitiated {
                alert(loc[.updateCheckFailed], error.localizedDescription)
            }
        }
    }

    func download() {
        guard let available else { return }
        NSWorkspace.shared.open(available.downloadURL)
        isDismissed = true
    }

    // MARK: - Internal

    private struct Payload: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: URL
        }
        let tagName: String
        let htmlUrl: URL
        let assets: [Asset]
    }

    private func fetchLatest() async throws -> Release {
        var request = URLRequest(url: Self.latestReleaseAPI, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        // GitHub rejects API calls without a User-Agent.
        request.setValue("Pyno/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let payload = try decoder.decode(Payload.self, from: data)

        // The disk image itself when the release carries one, the release page otherwise.
        let image = payload.assets.first { $0.name.hasSuffix(".dmg") }?.browserDownloadUrl
        let version = payload.tagName.hasPrefix("v") ? String(payload.tagName.dropFirst()) : payload.tagName
        return Release(version: version, downloadURL: image ?? payload.htmlUrl)
    }

    /// Numeric, component by component: 1.10.0 is newer than 1.9.2.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let lhs = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(lhs.count, rhs.count) {
            let a = index < lhs.count ? lhs[index] : 0
            let b = index < rhs.count ? rhs[index] : 0
            if a != b { return a > b }
        }
        return false
    }

    private func alert(_ title: String, _ body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.runModal()
    }
}
