import AppKit
import Combine
import Sparkle

@MainActor
final class UpdateController: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateController()

    enum Phase: Equatable {
        case ready
        case checking
        case available(version: String)
        case upToDate
        case failed(message: String)

        var title: String {
            switch self {
            case .ready: "Updates ready"
            case .checking: "Checking for updates…"
            case let .available(version): "Version \(version) is available"
            case .upToDate: "Claude Island is up to date"
            case .failed: "Could not check for updates"
            }
        }

        var detail: String? {
            guard case let .failed(message) = self else { return nil }
            return message
        }

        var hasUpdate: Bool {
            if case .available = self { return true }
            return false
        }
    }

    @Published private(set) var phase: Phase = .ready
    @Published private(set) var automaticallyChecksForUpdates = true
    @Published private(set) var automaticallyDownloadsUpdates = false
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var lastCheckDate: Date?

    private var updaterController: SPUStandardUpdaterController!
    private var started = false

    private override init() {
        super.init()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }

    func start() {
        guard !started else { return }
        started = true
        updaterController.startUpdater()
        refreshPreferences()
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        phase = .checking
        updaterController.checkForUpdates(nil)
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        updaterController.updater.automaticallyChecksForUpdates = enabled
        refreshPreferences()
    }

    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        updaterController.updater.automaticallyDownloadsUpdates = enabled
        refreshPreferences()
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        phase = .available(version: item.displayVersionString)
        lastCheckDate = Date()
        refreshPreferences()
        IslandStore.shared.expand()
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        phase = .upToDate
        lastCheckDate = Date()
        refreshPreferences()
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        phase = .failed(message: friendlyMessage(for: error))
        lastCheckDate = Date()
        refreshPreferences()
    }

    private func refreshPreferences() {
        let updater = updaterController.updater
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
        canCheckForUpdates = updater.canCheckForUpdates
        lastCheckDate = updater.lastUpdateCheckDate ?? lastCheckDate
    }

    private func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorFileDoesNotExist {
            return "No release feed has been published yet."
        }
        if nsError.localizedDescription.localizedCaseInsensitiveContains("404") {
            return "No GitHub release with an appcast has been published yet."
        }
        return nsError.localizedDescription
    }
}
