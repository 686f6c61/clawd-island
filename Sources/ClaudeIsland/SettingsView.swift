import AppKit
import ClaudeIslandCore
import SwiftUI

enum SettingsPaneID: String, CaseIterable {
    case general
    case claude
    case appearance
    case sessions
    case advanced
    case about

    var title: String {
        switch self {
        case .general: "General"
        case .claude: "Claude"
        case .appearance: "Appearance"
        case .sessions: "Sessions"
        case .advanced: "Advanced"
        case .about: "About"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .claude: "checkmark.shield"
        case .appearance: "paintbrush"
        case .sessions: "terminal"
        case .advanced: "wrench.and.screwdriver"
        case .about: "info.circle"
        }
    }
}

@MainActor
final class SettingsSelection: ObservableObject {
    private static let defaultsKey = "selectedSettingsPane"

    @Published var pane: SettingsPaneID {
        didSet { UserDefaults.standard.set(pane.rawValue, forKey: Self.defaultsKey) }
    }

    init() {
        pane = SettingsPaneID(
            rawValue: UserDefaults.standard.string(forKey: Self.defaultsKey) ?? ""
        ) ?? .general
    }
}

struct ClaudeIslandSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: IslandStore
    @ObservedObject var updates: UpdateController
    @ObservedObject var selection: SettingsSelection

    var body: some View {
        ZStack {
            GeneralSettingsView(settings: settings, store: store)
                .settingsPaneVisibility(selection.pane == .general)
            ClaudeSettingsView(store: store)
                .settingsPaneVisibility(selection.pane == .claude)
            AppearanceSettingsView(settings: settings, store: store)
                .settingsPaneVisibility(selection.pane == .appearance)
            SessionsSettingsView(settings: settings, store: store)
                .settingsPaneVisibility(selection.pane == .sessions)
            AdvancedSettingsView(settings: settings, store: store)
                .settingsPaneVisibility(selection.pane == .advanced)
            AboutSettingsView(settings: settings, updates: updates)
                .settingsPaneVisibility(selection.pane == .about)
        }
        .frame(width: 700, height: 560)
        .padding(14)
        .onReceive(settings.objectWillChange) { _ in
            Task { @MainActor in
                await Task.yield()
                store.settingsDidChange()
            }
        }
    }
}

private extension View {
    func settingsPaneVisibility(_ isVisible: Bool) -> some View {
        opacity(isVisible ? 1 : 0)
            .allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible)
            .zIndex(isVisible ? 1 : 0)
    }
}

private struct AboutSettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @ObservedObject var settings: AppSettings
    @ObservedObject var updates: UpdateController

    private let websiteURL = URL(string: "https://claude-island.686f6c61.dev")!
    private let repositoryURL = URL(string: "https://github.com/686f6c61/clawd-island")!
    private let releasesURL = URL(string: "https://github.com/686f6c61/clawd-island/releases")!
    private let changelogURL = URL(string: "https://github.com/686f6c61/clawd-island/blob/main/CHANGELOG.md")!
    private let issueURL = URL(string: "https://github.com/686f6c61/clawd-island/issues/new/choose")!
    private let securityURL = URL(string: "https://github.com/686f6c61/clawd-island/security/advisories/new")!

    private var shouldReduceMotion: Bool {
        settings.reduceAnimations || systemReduceMotion
    }

    var body: some View {
        SettingsPane(title: "About", subtitle: "Project information, updates and frequently asked questions.") {
            HStack(alignment: .center, spacing: 18) {
                Group {
                    if updates.phase.hasUpdate {
                        ClawdStateView(
                            resourceName: "Clawd-update",
                            set: settings.mascotSet,
                            reduceMotion: shouldReduceMotion
                        )
                    } else {
                        ClawdStateView(
                            status: .idle,
                            set: settings.mascotSet,
                            reduceMotion: shouldReduceMotion
                        )
                    }
                }
                .frame(width: 112, height: 112)
                .accessibilityLabel(
                    updates.phase.hasUpdate
                        ? "Clawd holding an update sign"
                        : "Clawd"
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text("Claude Island").font(.title2.bold())
                    Text("Version \(appVersion) (\(buildNumber))")
                        .foregroundStyle(.secondary)
                    LabeledContent("Created by") {
                        Link("686f6c61", destination: URL(string: "https://twitter.com/686f6c61")!)
                    }
                    LabeledContent("Website") {
                        Link("claude-island.686f6c61.dev", destination: websiteURL)
                    }
                    LabeledContent("Repository") {
                        Link("686f6c61/clawd-island", destination: repositoryURL)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            SettingsGroup("Updates") {
                HStack(spacing: 10) {
                    Image(systemName: updateSymbol)
                        .foregroundStyle(updateColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(updates.phase.title).fontWeight(.medium)
                        if let detail = updates.phase.detail {
                            Text(detail).font(.caption).foregroundStyle(.secondary)
                        } else if let date = updates.lastCheckDate {
                            Text("Last checked \(date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button(updates.phase.hasUpdate ? "View update" : "Check now", action: updates.checkForUpdates)
                        .buttonStyle(.borderedProminent)
                        .disabled(!updates.canCheckForUpdates)
                }
                Toggle("Check for updates automatically", isOn: Binding(
                    get: { updates.automaticallyChecksForUpdates },
                    set: { enabled in updates.setAutomaticallyChecksForUpdates(enabled) }
                ))
                Toggle("Download updates automatically", isOn: Binding(
                    get: { updates.automaticallyDownloadsUpdates },
                    set: { enabled in updates.setAutomaticallyDownloadsUpdates(enabled) }
                ))
                .disabled(!updates.automaticallyChecksForUpdates)
                HStack {
                    Text("Updates are verified before installation.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Link("View releases", destination: releasesURL)
                        .font(.caption)
                }
            }

            SettingsGroup("Legal and support") {
                HStack(spacing: 10) {
                    Button("License") { openLegalDocument("LICENSE", extension: nil) }
                    Button("Privacy") { openLegalDocument("PRIVACY", extension: "md") }
                    Button("Security") { openLegalDocument("SECURITY", extension: "md") }
                    Button("Safety") { openLegalDocument("SAFETY", extension: "md") }
                }
                .buttonStyle(.bordered)
                HStack(spacing: 16) {
                    Link("What's new", destination: changelogURL)
                    Link("Report a problem", destination: issueURL)
                    Link("Report a vulnerability privately", destination: securityURL)
                }
                .font(.caption)
                Text("Source available under BSL 1.1. Free for personal use, qualifying freelancers and small organizations; exact terms are in the bundled license.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Claude and Claude Code are trademarks of Anthropic PBC. Claude Island is an independent third-party project and is not affiliated with, sponsored by, or endorsed by Anthropic.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SettingsGroup("Frequently asked questions") {
                FAQItem(
                    question: "What does Claude Island do?",
                    answer: "It turns Claude Code activity, questions and permission requests into a native control surface attached to the top of your Mac display."
                )
                FAQItem(
                    question: "Does it upload my Claude Code data?",
                    answer: "No. Claude Code hooks communicate with a bridge bound to this Mac only. The app does not send session content to an external Claude Island service."
                )
                FAQItem(
                    question: "What happens on a Mac without a notch?",
                    answer: "The Island attaches to the top edge of the active display and keeps the same compact and expanded behavior."
                )
                FAQItem(
                    question: "How are updates installed?",
                    answer: "Claude Island reads a signed update feed from GitHub Releases. It verifies the package before replacing the installed app and can check automatically once a day."
                )
                FAQItem(
                    question: "How can I repair the Claude Code connection?",
                    answer: "Open Advanced and choose Reinstall hooks. Existing hooks from other tools are preserved."
                )
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    }

    private func openLegalDocument(_ name: String, extension fileExtension: String?) {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: "Legal"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "local"
    }

    private var updateSymbol: String {
        switch updates.phase {
        case .checking: "arrow.triangle.2.circlepath"
        case .available: "arrow.down.circle.fill"
        case .upToDate: "checkmark.seal.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .ready: "sparkles"
        }
    }

    private var updateColor: Color {
        switch updates.phase {
        case .available: .orange
        case .upToDate: .green
        case .failed: .red
        default: .secondary
        }
    }
}

private struct FAQItem: View {
    let question: String
    let answer: String

    var body: some View {
        DisclosureGroup(question) {
            Text(answer)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: IslandStore

    var body: some View {
        SettingsPane(title: "General", subtitle: "Choose how Claude Island behaves on this Mac.") {
            SettingsGroup("Mac") {
                LabeledContent("Current display", value: store.displayAttachment)
                Toggle("Open Claude Island at login", isOn: Binding(
                    get: { settings.launchAtLoginEnabled },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                if let message = settings.launchAtLoginMessage {
                    Text(message).font(.caption).foregroundStyle(.red)
                }
                Picker("Preferred terminal", selection: $settings.preferredTerminal) {
                    ForEach(TerminalPreference.allCases) { terminal in
                        Text(terminal.title + availabilitySuffix(terminal)).tag(terminal)
                    }
                }
                Toggle("Play sounds for questions and permissions", isOn: $settings.soundEnabled)
            }

            SettingsGroup("Claude usage") {
                Toggle("Show 5-hour and weekly usage in the Island", isOn: $settings.showUsage)
                if let snapshot = store.usageSnapshot, settings.showUsage {
                    HStack(spacing: 18) {
                        if let fiveHour = snapshot.fiveHour {
                            usageSummary(title: "5-hour window", utilization: fiveHour.utilization)
                        }
                        if let sevenDay = snapshot.sevenDay {
                            usageSummary(title: "Weekly", utilization: sevenDay.utilization)
                        }
                        Spacer()
                    }
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(settings.showUsage ? store.usageStatus : "Usage display is off")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Background checks never open Keychain dialogs. Refresh may ask once; tokens are never stored by Claude Island.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button("Refresh", action: store.refreshUsage)
                        .disabled(!store.canRefreshUsage)
                }
            }

            SettingsGroup("Expansion") {
                Toggle("Questions", isOn: $settings.expandQuestions)
                Toggle("Permission requests", isOn: $settings.expandPermissions)
                Toggle("Completed tasks", isOn: $settings.expandCompletion)
                Toggle("Failures", isOn: $settings.expandFailure)
                Toggle("Claude notifications", isOn: $settings.expandNotifications)
                LabeledContent("Collapse after") {
                    HStack {
                        Slider(value: $settings.autoCollapseDelay, in: 1 ... 15, step: 0.5)
                            .frame(width: 190)
                        Text(settings.autoCollapseDelay.formatted(.number.precision(.fractionLength(1))) + " s")
                            .monospacedDigit().frame(width: 48, alignment: .trailing)
                    }
                }
            }

            SettingsGroup("Idle behavior") {
                Toggle("Double-click the Island to hide it", isOn: $settings.doubleClickNotchToHide)
                Text(store.hasHardwareNotch
                    ? "Click the camera notch once to restore Claude Island after hiding it."
                    : "Click the top-center edge once to restore Claude Island after hiding it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Hide the Island when idle", isOn: $settings.autoHideWhenIdle)
                LabeledContent("Hide after") {
                    Picker("", selection: $settings.idleHideDelay) {
                        Text("15 seconds").tag(15.0)
                        Text("45 seconds").tag(45.0)
                        Text("2 minutes").tag(120.0)
                        Text("5 minutes").tag(300.0)
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
                .disabled(!settings.autoHideWhenIdle)
                Toggle("Let Clawd peek out occasionally", isOn: $settings.peekEnabled)
                    .disabled(!settings.autoHideWhenIdle)
                LabeledContent("Clawd appears every") {
                    Picker("", selection: $settings.peekInterval) {
                        Text("30 seconds").tag(30.0)
                        Text("1 minute").tag(60.0)
                        Text("90 seconds").tag(90.0)
                        Text("3 minutes").tag(180.0)
                        Text("5 minutes").tag(300.0)
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
                .disabled(!settings.autoHideWhenIdle || !settings.peekEnabled)
                LabeledContent("Visible for") {
                    Stepper("\(Int(settings.peekDuration)) seconds", value: $settings.peekDuration, in: 1 ... 8, step: 1)
                }
                .disabled(!settings.autoHideWhenIdle || !settings.peekEnabled)
                LabeledContent("Side") {
                    Picker("", selection: $settings.peekSide) {
                        ForEach(PeekSidePreference.allCases) { side in
                            Text(side.title).tag(side)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
                .disabled(!settings.autoHideWhenIdle || !settings.peekEnabled || !store.hasHardwareNotch)
                if !store.hasHardwareNotch {
                    Text("This display has no camera notch, so Clawd appears from the top edge.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Spacer()
                    Button("Preview Clawd peek", action: store.previewPeek)
                        .disabled(!settings.showMascot || !settings.peekEnabled || !store.pendingRequests.isEmpty)
                }
            }
        }
    }

    private func availabilitySuffix(_ terminal: TerminalPreference) -> String {
        terminal == .automatic || TerminalActivator.isAvailable(terminal) ? "" : " — not installed"
    }

    private func usageSummary(title: String, utilization: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("\(Int(utilization.rounded()))% used")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .monospacedDigit()
            ProgressView(value: utilization, total: 100)
                .frame(width: 150)
        }
    }
}

@MainActor
private final class ClaudeSettingsViewModel: ObservableObject {
    @Published var mode: ClaudePermissionMode = .default
    @Published var alwaysAskTools: Set<String> = []
    @Published var allowRules: [String] = []
    @Published var removedAllowRules: Set<String> = []
    @Published var search = ""
    @Published var message: String?
    @Published var error: String?
    @Published var showBypassConfirmation = false

    init() { reload() }

    var filteredRules: [String] {
        guard !search.isEmpty else { return allowRules }
        return allowRules.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    func reload() {
        do {
            let snapshot = try ClaudeSettingsManager.snapshot()
            mode = snapshot.mode
            alwaysAskTools = Set(snapshot.askRules).intersection(ClaudeSettingsManager.configurableTools)
            allowRules = snapshot.allowRules.sorted()
            removedAllowRules = []
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func requestApply(store: IslandStore) {
        if mode.isDangerous {
            showBypassConfirmation = true
        } else {
            apply(store: store)
        }
    }

    func apply(store: IslandStore) {
        do {
            let result = try ClaudeSettingsManager.apply(
                mode: mode,
                alwaysAskTools: alwaysAskTools,
                removingAllowRules: removedAllowRules
            )
            message = result.changedFiles.isEmpty
                ? "Settings were already up to date."
                : "Applied with \(result.backupFiles.count) backup file(s). Restart active Claude sessions."
            error = nil
            reload()
            store.refreshPermissionMode()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleAsk(_ tool: String, enabled: Bool) {
        if enabled { alwaysAskTools.insert(tool) } else { alwaysAskTools.remove(tool) }
    }

    func toggleRuleRemoval(_ rule: String) {
        if removedAllowRules.contains(rule) { removedAllowRules.remove(rule) } else { removedAllowRules.insert(rule) }
    }
}

private struct ClaudeSettingsView: View {
    @ObservedObject var store: IslandStore
    @StateObject private var model = ClaudeSettingsViewModel()

    var body: some View {
        SettingsPane(title: "Claude", subtitle: "Changes are written only when you click Apply, with a backup first.") {
            SettingsGroup("Default permission mode") {
                Picker("Mode", selection: $model.mode) {
                    ForEach(ClaudePermissionMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Text(model.mode.detail)
                    .font(.caption)
                    .foregroundStyle(model.mode.isDangerous ? .red : .secondary)
            }

            SettingsGroup("Always ask before using") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], alignment: .leading, spacing: 8) {
                    ForEach(ClaudeSettingsManager.configurableTools, id: \.self) { tool in
                        Toggle(tool, isOn: Binding(
                            get: { model.alwaysAskTools.contains(tool) },
                            set: { model.toggleAsk(tool, enabled: $0) }
                        ))
                    }
                }
                Text("Ask rules take precedence over remembered allow rules, except in bypass mode.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            SettingsGroup("Remembered allow rules") {
                TextField("Filter rules", text: $model.search)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if model.filteredRules.isEmpty {
                            Text(model.allowRules.isEmpty ? "No remembered allow rules." : "No matching rules.")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        } else {
                            ForEach(model.filteredRules, id: \.self) { rule in
                                HStack {
                                    Image(systemName: model.removedAllowRules.contains(rule) ? "trash.fill" : "checkmark.circle")
                                        .foregroundStyle(model.removedAllowRules.contains(rule) ? .red : .green)
                                    Text(rule).font(.system(.caption, design: .monospaced)).lineLimit(1)
                                    Spacer()
                                    Button(model.removedAllowRules.contains(rule) ? "Keep" : "Remove") {
                                        model.toggleRuleRemoval(rule)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.horizontal, 10)
                                .frame(height: 34)
                                Divider().padding(.leading, 10)
                            }
                        }
                    }
                }
                .frame(height: 145)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.separator.opacity(0.45), lineWidth: 0.5)
                }
            }

            HStack {
                Button("Open settings.json") {
                    NSWorkspace.shared.open(ClaudeSettingsManager.settingsURL())
                }
                Button("Reload", action: model.reload)
                Spacer()
                if let message = model.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                Button("Apply") { model.requestApply(store: store) }
                    .buttonStyle(.borderedProminent)
            }
            if let error = model.error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .alert("Enable bypass permissions?", isPresented: $model.showBypassConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Enable bypass", role: .destructive) { model.apply(store: store) }
        } message: {
            Text("Claude will skip permission prompts and safety checks. Use this only in an isolated environment.")
        }
    }
}

private enum AppearancePreviewMode: String, CaseIterable, Identifiable {
    case compact = "Compact"
    case expanded = "Expanded"

    var id: String { rawValue }
    var presentation: IslandPreviewPresentation { self == .compact ? .compact : .expanded }
}

private struct AppearanceSettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: IslandStore
    @State private var previewMode: AppearancePreviewMode = .compact

    private var shouldReduceMotion: Bool {
        settings.reduceAnimations || systemReduceMotion
    }

    var body: some View {
        SettingsPane(title: "Appearance", subtitle: "Tune the Island without changing its detected display attachment.") {
            VStack(spacing: 10) {
                Picker("Preview", selection: $previewMode) {
                    ForEach(AppearancePreviewMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)

                AppearanceIslandPreview(
                    settings: settings,
                    store: store,
                    mode: previewMode,
                    toggleMode: {
                        withAnimation(shouldReduceMotion ? nil : .easeInOut(duration: 0.2)) {
                            previewMode = previewMode == .compact ? .expanded : .compact
                        }
                    }
                )

                Text("This is the real Island view. Click it to switch between Compact and Expanded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SettingsGroup("Compact Island") {
                Picker("Layout", selection: $settings.compactStyle) {
                    ForEach(CompactIslandStyle.allCases) { Text($0.title).tag($0) }
                }
                Picker("Secondary information", selection: $settings.compactContent) {
                    ForEach(CompactContentMode.allCases) { Text($0.title).tag($0) }
                }
                .disabled(settings.compactStyle == .minimal)
                Toggle("Show Clawd", isOn: $settings.showMascot)
                Picker("Mascot set", selection: $settings.mascotSet) {
                    ForEach(MascotSet.allCases) { set in
                        Text(set.title).tag(set)
                    }
                }
                .disabled(!settings.showMascot)
                Toggle("Reduce mascot and panel animations", isOn: $settings.reduceAnimations)
                    .help("Claude Island also follows macOS Reduce Motion automatically")
            }

            SettingsGroup("Expanded Island") {
                LabeledContent("Width") {
                    HStack {
                        Slider(value: $settings.expandedWidth, in: 520 ... 760, step: 20).frame(width: 230)
                        Text("\(Int(settings.expandedWidth)) pt").monospacedDigit().frame(width: 58, alignment: .trailing)
                    }
                }
                LabeledContent("Gradient") {
                    Slider(value: $settings.gradientIntensity, in: 0 ... 1).frame(width: 230)
                }
                LabeledContent("Body opacity") {
                    Slider(value: $settings.bodyOpacity, in: 0.82 ... 1).frame(width: 230)
                }
                Text("The neck remains pure black so it still merges with the real notch.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct AppearanceIslandPreview: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: IslandStore
    let mode: AppearancePreviewMode
    let toggleMode: () -> Void

    private var shouldReduceMotion: Bool {
        settings.reduceAnimations || systemReduceMotion
    }

    private var panelSize: CGSize {
        switch mode {
        case .compact:
            IslandPanelLayout.compactSize(
                hasHardwareNotch: store.hasHardwareNotch,
                notchWidth: store.displayNotchWidth,
                notchHeight: store.displayNotchHeight,
                style: settings.compactStyle
            )
        case .expanded:
            IslandPanelLayout.expandedSize(
                preferredWidth: CGFloat(settings.expandedWidth),
                maximumWidth: CGFloat(settings.expandedWidth),
                hasHardwareNotch: store.hasHardwareNotch,
                notchHeight: store.displayNotchHeight,
                activityCount: store.activeSession?.activities.count ?? 0,
                sessionCount: store.sessions.count,
                agentCount: store.activeSession?.agents.count ?? 0,
                hasQuestion: store.currentRequest?.kind == .question,
                showsUsage: settings.showUsage
            )
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let horizontalScale = (proxy.size.width - 28) / panelSize.width
            let verticalScale = (proxy.size.height - 24) / panelSize.height
            let scale = min(1, horizontalScale, verticalScale)

            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [Color(white: 0.16), Color(white: 0.095)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                ZStack(alignment: .top) {
                    IslandRootView(
                        store: store,
                        settings: settings,
                        notchWidth: store.displayNotchWidth,
                        notchHeight: store.displayNotchHeight,
                        hasHardwareNotch: store.hasHardwareNotch,
                        previewPresentation: mode.presentation
                    )
                    .frame(width: panelSize.width, height: panelSize.height)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                    if store.hasHardwareNotch {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.black)
                            .frame(
                                width: store.displayNotchWidth,
                                height: store.displayNotchHeight + 10
                            )
                            .offset(y: -10)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: panelSize.width, height: panelSize.height)
                .scaleEffect(scale, anchor: .top)
                .frame(
                    width: panelSize.width * scale,
                    height: panelSize.height * scale,
                    alignment: .top
                )
                .padding(.top, 12)
            }
        }
        .frame(height: mode == .compact ? 104 : 278)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture(perform: toggleMode)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Live \(mode.rawValue) Island preview")
        .accessibilityHint("Click to show the \(mode == .compact ? "Expanded" : "Compact") preview")
        .animation(shouldReduceMotion ? nil : .easeInOut(duration: 0.2), value: mode)
        .animation(shouldReduceMotion ? nil : .easeInOut(duration: 0.2), value: panelSize)
    }
}

private struct SessionsSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: IslandStore

    var body: some View {
        SettingsPane(title: "Sessions", subtitle: "Start, resume and switch Claude Code sessions by folder.") {
            HStack {
                Button("New Claude session…", action: store.startNewSession)
                    .buttonStyle(.borderedProminent)
                Button("Add favorite folder…", action: store.addFavoriteFolder)
                Button("Open active folder in Finder", action: store.openActiveInFinder)
                    .disabled(store.activeSession == nil)
                Spacer()
            }

            SettingsGroup("Active sessions") {
                if store.sessions.isEmpty {
                    Text("No active sessions yet.").foregroundStyle(.secondary)
                } else {
                    if store.isSessionSelectionPinned, store.sessions.count > 1 {
                        HStack {
                            Text("Following a manually selected session.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Follow activity", action: store.followSessionActivity)
                                .buttonStyle(.borderless)
                        }
                    }
                    ForEach(store.orderedSessions) { session in
                        SessionRow(
                            title: session.projectName,
                            subtitle: sessionSubtitle(session),
                            primaryTitle: session.id == store.activeSessionID ? "Selected" : "Show",
                            primaryAction: { store.selectSession(session.id) },
                            secondaryTitle: nil,
                            secondaryAction: nil
                        )
                    }
                }
            }

            SettingsGroup("Favorite folders") {
                if settings.favoriteFolders.isEmpty {
                    Text("Add folders you use often to start Claude with one click.").foregroundStyle(.secondary)
                } else {
                    ForEach(settings.favoriteFolders, id: \.self) { folder in
                        SessionRow(
                            title: URL(fileURLWithPath: folder).lastPathComponent,
                            subtitle: folder,
                            primaryTitle: "Start",
                            primaryAction: { store.startSession(in: folder) },
                            secondaryTitle: "Remove",
                            secondaryAction: { settings.removeFavorite(folder) }
                        )
                    }
                }
            }

            SettingsGroup("Recent sessions") {
                Text("Stored only on this Mac for up to 30 days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if store.recentSessions.isEmpty {
                    Text("Completed sessions will appear here.").foregroundStyle(.secondary)
                } else {
                    ForEach(store.recentSessions.prefix(6)) { session in
                        SessionRow(
                            title: session.projectName,
                            subtitle: session.lastUpdated.formatted(date: .abbreviated, time: .shortened) + " · " + session.cwd,
                            primaryTitle: "Resume",
                            primaryAction: { store.resumeSession(session) },
                            secondaryTitle: nil,
                            secondaryAction: nil
                        )
                    }
                    Button("Clear recent sessions", role: .destructive, action: store.clearRecentSessions)
                        .buttonStyle(.borderless)
                }
            }
        }
    }

    private func sessionSubtitle(_ session: SessionRecord) -> String {
        let agentSummary = session.runningAgentCount > 0 ? " · \(session.runningAgentCount) agents" : ""
        return session.status.label + agentSummary + " · " + session.cwd
    }
}

private struct SessionRow: View {
    let title: String
    let subtitle: String
    let primaryTitle: String
    let primaryAction: () -> Void
    let secondaryTitle: String?
    let secondaryAction: (() -> Void)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, action: secondaryAction).buttonStyle(.borderless)
            }
            Button(primaryTitle, action: primaryAction)
                .disabled(primaryTitle == "Selected")
        }
    }
}

private struct AdvancedSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: IslandStore
    @State private var showUninstallConfirmation = false
    @State private var showResetConfirmation = false

    var body: some View {
        SettingsPane(title: "Advanced", subtitle: "Repair the integration and inspect its local status.") {
            SettingsGroup("Integration") {
                LabeledContent("Local bridge", value: store.serverStatus)
                LabeledContent("Hooks", value: store.setupStatus)
                LabeledContent("Permission mode", value: store.permissionMode)
                HStack {
                    Button("Test connection", action: store.testConnection)
                    Button("Copy diagnostic", action: store.copyDiagnostics)
                    Button("Reinstall hooks", action: store.reinstallHooks)
                    Button("Uninstall hooks…", role: .destructive) { showUninstallConfirmation = true }
                    Spacer()
                }
            }

            SettingsGroup("Diagnostic") {
                ScrollView {
                    Text(store.diagnosticReport)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(height: 170)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            }

            SettingsGroup("Reset") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Restore application defaults")
                        Text("Claude permission rules and session files are not deleted.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Restore defaults…", role: .destructive) { showResetConfirmation = true }
                }
            }
        }
        .onAppear { store.runDiagnostics() }
        .alert("Uninstall Claude Island hooks?", isPresented: $showUninstallConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Uninstall", role: .destructive, action: store.uninstallHooks)
        } message: {
            Text("Existing hooks from other tools are preserved. Claude Island will stop receiving new events until you reinstall them.")
        }
        .alert("Restore application defaults?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Restore", role: .destructive) {
                settings.resetToDefaults()
                store.settingsDidChange()
            }
        }
    }
}

private struct SettingsPane<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.title2.bold())
                    Text(subtitle).foregroundStyle(.secondary)
                }
                content
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(5)
        } label: {
            Text(title).font(.headline)
        }
    }
}
