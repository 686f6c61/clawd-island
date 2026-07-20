import Foundation
import Combine
import ServiceManagement

enum TerminalPreference: String, CaseIterable, Identifiable {
    case automatic
    case ghostty
    case terminal
    case iTerm
    case warp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .ghostty: "Ghostty"
        case .terminal: "Terminal"
        case .iTerm: "iTerm2"
        case .warp: "Warp"
        }
    }

    var bundleIdentifier: String? {
        switch self {
        case .automatic: nil
        case .ghostty: "com.mitchellh.ghostty"
        case .terminal: "com.apple.Terminal"
        case .iTerm: "com.googlecode.iterm2"
        case .warp: "dev.warp.Warp-Stable"
        }
    }
}

enum CompactIslandStyle: String, CaseIterable, Identifiable {
    case informative
    case minimal

    var id: String { rawValue }
    var title: String { self == .informative ? "Informative" : "Minimal" }
}

enum CompactContentMode: String, CaseIterable, Identifiable {
    case status
    case project
    case activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .status: "Status"
        case .project: "Project"
        case .activity: "Latest activity"
        }
    }
}

enum PeekSidePreference: String, CaseIterable, Identifiable {
    case alternating
    case left
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alternating: "Alternate sides"
        case .left: "Left side"
        case .right: "Right side"
        }
    }
}

enum MascotSet: String, CaseIterable, Identifiable {
    case classic
    case clawdia

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: "Classic Clawd"
        case .clawdia: "Clawdia · Pink Bow"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let preferredTerminal = "preferredTerminal"
        static let showUsage = "showUsage"
        static let soundEnabled = "soundEnabled"
        static let autoCollapseDelay = "autoCollapseDelay"
        static let expandQuestions = "expandQuestions"
        static let expandPermissions = "expandPermissions"
        static let expandCompletion = "expandCompletion"
        static let expandFailure = "expandFailure"
        static let expandNotifications = "expandNotifications"
        static let compactStyle = "compactStyle"
        static let compactContent = "compactContent"
        static let showMascot = "showMascot"
        static let mascotSet = "mascotSet"
        static let reduceAnimations = "reduceAnimations"
        static let expandedWidth = "expandedWidth"
        static let gradientIntensity = "gradientIntensity"
        static let bodyOpacity = "bodyOpacity"
        static let favoriteFolders = "favoriteFolders"
        static let autoHideWhenIdle = "autoHideWhenIdle"
        static let idleHideDelay = "idleHideDelay"
        static let peekEnabled = "peekEnabled"
        static let peekInterval = "peekInterval"
        static let peekDuration = "peekDuration"
        static let peekSide = "peekSide"
        static let doubleClickNotchToHide = "doubleClickNotchToHide"
        static let hooksEnabled = "hooksEnabled"
    }

    private let defaults: UserDefaults

    @Published var preferredTerminal: TerminalPreference { didSet { save(preferredTerminal.rawValue, Key.preferredTerminal) } }
    @Published var showUsage: Bool { didSet { save(showUsage, Key.showUsage) } }
    @Published var soundEnabled: Bool { didSet { save(soundEnabled, Key.soundEnabled) } }
    @Published var autoCollapseDelay: Double { didSet { save(autoCollapseDelay, Key.autoCollapseDelay) } }
    @Published var expandQuestions: Bool { didSet { save(expandQuestions, Key.expandQuestions) } }
    @Published var expandPermissions: Bool { didSet { save(expandPermissions, Key.expandPermissions) } }
    @Published var expandCompletion: Bool { didSet { save(expandCompletion, Key.expandCompletion) } }
    @Published var expandFailure: Bool { didSet { save(expandFailure, Key.expandFailure) } }
    @Published var expandNotifications: Bool { didSet { save(expandNotifications, Key.expandNotifications) } }
    @Published var compactStyle: CompactIslandStyle { didSet { save(compactStyle.rawValue, Key.compactStyle) } }
    @Published var compactContent: CompactContentMode { didSet { save(compactContent.rawValue, Key.compactContent) } }
    @Published var showMascot: Bool { didSet { save(showMascot, Key.showMascot) } }
    @Published var mascotSet: MascotSet { didSet { save(mascotSet.rawValue, Key.mascotSet) } }
    @Published var reduceAnimations: Bool { didSet { save(reduceAnimations, Key.reduceAnimations) } }
    @Published var expandedWidth: Double { didSet { save(expandedWidth, Key.expandedWidth) } }
    @Published var gradientIntensity: Double { didSet { save(gradientIntensity, Key.gradientIntensity) } }
    @Published var bodyOpacity: Double { didSet { save(bodyOpacity, Key.bodyOpacity) } }
    @Published private(set) var favoriteFolders: [String]
    @Published var autoHideWhenIdle: Bool { didSet { save(autoHideWhenIdle, Key.autoHideWhenIdle) } }
    @Published var idleHideDelay: Double { didSet { save(idleHideDelay, Key.idleHideDelay) } }
    @Published var peekEnabled: Bool { didSet { save(peekEnabled, Key.peekEnabled) } }
    @Published var peekInterval: Double { didSet { save(peekInterval, Key.peekInterval) } }
    @Published var peekDuration: Double { didSet { save(peekDuration, Key.peekDuration) } }
    @Published var peekSide: PeekSidePreference { didSet { save(peekSide.rawValue, Key.peekSide) } }
    @Published var doubleClickNotchToHide: Bool { didSet { save(doubleClickNotchToHide, Key.doubleClickNotchToHide) } }
    @Published var hooksEnabled: Bool { didSet { save(hooksEnabled, Key.hooksEnabled) } }

    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var launchAtLoginMessage: String?

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preferredTerminal = TerminalPreference(rawValue: defaults.string(forKey: Key.preferredTerminal) ?? "") ?? .automatic
        showUsage = Self.bool(defaults, Key.showUsage, default: true)
        soundEnabled = Self.bool(defaults, Key.soundEnabled, default: true)
        autoCollapseDelay = Self.number(defaults, Key.autoCollapseDelay, default: 2.4).clamped(to: 1 ... 15)
        expandQuestions = Self.bool(defaults, Key.expandQuestions, default: true)
        expandPermissions = Self.bool(defaults, Key.expandPermissions, default: true)
        expandCompletion = Self.bool(defaults, Key.expandCompletion, default: true)
        expandFailure = Self.bool(defaults, Key.expandFailure, default: true)
        expandNotifications = Self.bool(defaults, Key.expandNotifications, default: true)
        compactStyle = CompactIslandStyle(rawValue: defaults.string(forKey: Key.compactStyle) ?? "") ?? .informative
        compactContent = CompactContentMode(rawValue: defaults.string(forKey: Key.compactContent) ?? "") ?? .status
        showMascot = Self.bool(defaults, Key.showMascot, default: true)
        mascotSet = MascotSet(rawValue: defaults.string(forKey: Key.mascotSet) ?? "") ?? .classic
        reduceAnimations = Self.bool(defaults, Key.reduceAnimations, default: false)
        expandedWidth = Self.number(defaults, Key.expandedWidth, default: 640).clamped(to: 520 ... 760)
        gradientIntensity = Self.number(defaults, Key.gradientIntensity, default: 0.65).clamped(to: 0 ... 1)
        bodyOpacity = Self.number(defaults, Key.bodyOpacity, default: 0.98).clamped(to: 0.82 ... 1)
        favoriteFolders = Array(Set(defaults.stringArray(forKey: Key.favoriteFolders) ?? []))
            .filter { FileManager.default.fileExists(atPath: $0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        autoHideWhenIdle = Self.bool(defaults, Key.autoHideWhenIdle, default: true)
        idleHideDelay = Self.number(defaults, Key.idleHideDelay, default: 45).clamped(to: 5 ... 1_800)
        peekEnabled = Self.bool(defaults, Key.peekEnabled, default: true)
        peekInterval = Self.number(defaults, Key.peekInterval, default: 90).clamped(to: 10 ... 1_800)
        peekDuration = Self.number(defaults, Key.peekDuration, default: 3).clamped(to: 1 ... 8)
        peekSide = PeekSidePreference(rawValue: defaults.string(forKey: Key.peekSide) ?? "") ?? .alternating
        doubleClickNotchToHide = Self.bool(defaults, Key.doubleClickNotchToHide, default: true)
        hooksEnabled = Self.bool(defaults, Key.hooksEnabled, default: true)
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            launchAtLoginMessage = launchAtLoginEnabled == enabled ? nil : "macOS has not applied the change yet."
        } catch {
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            launchAtLoginMessage = error.localizedDescription
        }
    }

    func addFavorite(_ path: String) {
        let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
        guard !favoriteFolders.contains(normalized) else { return }
        favoriteFolders.append(normalized)
        favoriteFolders.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        save(favoriteFolders, Key.favoriteFolders)
    }

    func removeFavorite(_ path: String) {
        favoriteFolders.removeAll { $0 == path }
        save(favoriteFolders, Key.favoriteFolders)
    }

    func resetToDefaults() {
        setLaunchAtLogin(false)
        preferredTerminal = .automatic
        showUsage = true
        soundEnabled = true
        autoCollapseDelay = 2.4
        expandQuestions = true
        expandPermissions = true
        expandCompletion = true
        expandFailure = true
        expandNotifications = true
        compactStyle = .informative
        compactContent = .status
        showMascot = true
        mascotSet = .classic
        reduceAnimations = false
        expandedWidth = 640
        gradientIntensity = 0.65
        bodyOpacity = 0.98
        favoriteFolders = []
        save(favoriteFolders, Key.favoriteFolders)
        autoHideWhenIdle = true
        idleHideDelay = 45
        peekEnabled = true
        peekInterval = 90
        peekDuration = 3
        peekSide = .alternating
        doubleClickNotchToHide = true
        hooksEnabled = true
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
    }

    private static func bool(_ defaults: UserDefaults, _ key: String, default fallback: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
    }

    private static func number(_ defaults: UserDefaults, _ key: String, default fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
