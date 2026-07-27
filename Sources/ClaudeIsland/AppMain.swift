import AppKit
import ClaudeIslandCore
import Combine
import SwiftUI

@main
struct ClaudeIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = IslandStore.shared
    @StateObject private var settings = AppSettings.shared
    @StateObject private var updates = UpdateController.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(
                store: store,
                settings: settings,
                updates: updates,
                showIsland: { appDelegate.showIsland() },
                showSettings: { appDelegate.showSettings() }
            )
        } label: {
            Image(nsImage: ClawdAssets.menuBarIcon(for: settings.mascotSet))
                .renderingMode(.original)
                .resizable()
                .interpolation(.none)
                .frame(width: 18, height: 18)
                .accessibilityLabel("Claude Island")
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { appDelegate.showSettings() }
                    .keyboardShortcut(",")
            }
        }
    }
}

@MainActor
private enum ClawdAssets {
    static let classicMenuBarIcon = loadMenuBarIcon(resourceName: "Clawd-menu")
    static let clawdiaMenuBarIcon = loadMenuBarIcon(resourceName: "Clawdia-menu")

    static func menuBarIcon(for set: MascotSet) -> NSImage {
        set == .clawdia ? clawdiaMenuBarIcon : classicMenuBarIcon
    }

    private static func loadMenuBarIcon(resourceName: String) -> NSImage {
        guard
            let url = Bundle.main.url(forResource: resourceName, withExtension: "svg"),
            let image = NSImage(contentsOf: url)
        else { return NSImage(systemSymbolName: "asterisk", accessibilityDescription: "Claude Island") ?? NSImage() }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = false
        return image
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = IslandStore.shared
    private var panelController: PanelController?
    private var settingsWindowController: SettingsWindowController?
    private var hookServer: HookServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let panelController = PanelController(store: store, settings: AppSettings.shared)
        self.panelController = panelController

        let server = HookServer(store: store)
        hookServer = server
        server.start()

        if AppSettings.shared.hooksEnabled {
            installHooks()
        } else {
            store.setHooksDisabled()
        }

        UpdateController.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hookServer?.stop()
    }

    func showIsland() {
        store.expand()
        panelController?.show()
    }

    func showSettings() {
        let controller: SettingsWindowController
        if let settingsWindowController {
            controller = settingsWindowController
        } else {
            controller = SettingsWindowController(settings: AppSettings.shared, store: store)
            settingsWindowController = controller
        }
        controller.showWindow()
    }

    private func installHooks() {
        guard let helperSource = HookBridgeCredential.helperExecutableURL() else {
            store.setSetupError(SetupError.helperMissing)
            return
        }
        do {
            let result = try HookSettingsInstaller.install(helperSourceURL: helperSource)
            store.setSetup(result: result)
        } catch {
            store.setSetupError(error)
        }
    }
}

private enum SetupError: LocalizedError {
    case helperMissing
    var errorDescription: String? { "ClaudeIslandHook is missing from the app bundle" }
}

@MainActor
private final class SettingsWindowController: NSWindowController {
    private let selection: SettingsSelection
    private let settingsToolbar: NSToolbar

    init(settings: AppSettings, store: IslandStore) {
        let selection = SettingsSelection()
        self.selection = selection
        settingsToolbar = NSToolbar(identifier: "ClaudeIslandSettingsToolbar")
        let hostingController = NSHostingController(
            rootView: ClaudeIslandSettingsView(
                settings: settings,
                store: store,
                updates: UpdateController.shared,
                selection: selection
            )
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 728, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(selection.pane.title) — Claude Island"
        window.identifier = NSUserInterfaceItemIdentifier("ClaudeIslandSettingsWindow")
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.collectionBehavior = [.moveToActiveSpace]
        window.contentMinSize = NSSize(width: 728, height: 588)
        window.contentMaxSize = NSSize(width: 728, height: 588)
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        super.init(window: window)
        settingsToolbar.delegate = self
        settingsToolbar.allowsUserCustomization = false
        settingsToolbar.autosavesConfiguration = false
        settingsToolbar.displayMode = .iconAndLabel
        settingsToolbar.selectedItemIdentifier = .init(selection.pane.rawValue)
        window.toolbar = settingsToolbar
        window.toolbarStyle = .preference
        // Observe programmatic pane changes to keep the window title in sync
        selection.$pane
            .map { "\($0.title) — Claude Island" }
            .sink { [weak window] in window?.title = $0 }
            .store(in: &paneCancellables)
    }

    private var paneCancellables = Set<AnyCancellable>()

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func showWindow() {
        guard let window else { return }
        if !window.isVisible {
            positionOnActiveScreen(window)
        }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func positionOnActiveScreen(_ window: NSWindow) {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else {
            window.center()
            return
        }
        let frame = window.frame
        window.setFrameOrigin(NSPoint(
            x: visibleFrame.midX - frame.width / 2,
            y: visibleFrame.midY - frame.height / 2
        ))
    }

    @objc private func selectSettingsPane(_ sender: NSToolbarItem) {
        guard let pane = SettingsPaneID(rawValue: sender.itemIdentifier.rawValue) else { return }
        selection.pane = pane
        settingsToolbar.selectedItemIdentifier = sender.itemIdentifier
        window?.title = "\(pane.title) — Claude Island"
    }
}

extension SettingsWindowController: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsPaneID.allCases.map { .init($0.rawValue) }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let pane = SettingsPaneID(rawValue: itemIdentifier.rawValue) else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = pane.title
        item.paletteLabel = pane.title
        item.toolTip = pane.title
        item.image = NSImage(systemSymbolName: pane.symbolName, accessibilityDescription: pane.title)
        item.target = self
        item.action = #selector(selectSettingsPane(_:))
        return item
    }
}

private struct MenuBarContent: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @ObservedObject var store: IslandStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var updates: UpdateController
    let showIsland: () -> Void
    let showSettings: () -> Void

    private var shouldReduceMotion: Bool {
        settings.reduceAnimations || systemReduceMotion
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.075), Color(white: 0.035)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                MenuSeparator()

                primaryActions
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)

                MenuSeparator()

                activeSessionArea
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                alerts

                MenuSeparator()

                utilityActions
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)

                MenuSeparator()

                footer
                    .padding(.horizontal, 16)
                    .frame(height: 43)
            }
        }
        .frame(width: 340)
        .foregroundStyle(Color.white.opacity(0.92))
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            if settings.showMascot {
                Group {
                    if updates.phase.hasUpdate {
                        ClawdStateView(
                            resourceName: "Clawd-update",
                            set: settings.mascotSet,
                            reduceMotion: shouldReduceMotion
                        )
                    } else {
                        ClawdStateView(
                            status: store.activeSession?.status ?? .idle,
                            set: settings.mascotSet,
                            reduceMotion: shouldReduceMotion
                        )
                    }
                }
                .frame(width: updates.phase.hasUpdate ? 66 : 58, height: 58)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Claude Island")
                    .font(.system(size: 15, weight: .semibold))
                Text(store.activeSession?.projectName ?? "Ready for Claude Code")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Circle()
                        .fill(IslandPalette.statusColor(store.activeSession?.status ?? .idle))
                        .frame(width: 7, height: 7)
                    Text(store.activeSession?.status.label ?? "Ready")
                        .foregroundStyle(IslandPalette.statusColor(store.activeSession?.status ?? .idle))
                    if let session = store.activeSession {
                        Rectangle()
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 1, height: 11)
                        MenuTerminalIdentity(program: session.terminalProgram)
                    }
                }
                .font(.system(size: 10.5, weight: .semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if settings.showUsage, let usage = store.usageSnapshot {
                MenuUsageSummary(snapshot: usage)
            }
        }
    }

    private var primaryActions: some View {
        HStack(spacing: 4) {
            MenuPrimaryAction(title: "Show Island", systemImage: "rectangle.topthird.inset", tint: IslandPalette.amber, action: showIsland)
                .keyboardShortcut("i")
            MenuPrimaryAction(title: "New Session", systemImage: "plus.app", action: store.startNewSession)
                .keyboardShortcut("n")
            MenuTerminalAction(program: store.activeSession?.terminalProgram, action: store.jumpToTerminal)
                .disabled(store.activeSession == nil)
            MenuPrimaryAction(title: "Settings", systemImage: "gearshape", action: showSettings)
                .keyboardShortcut(",")
        }
    }

    @ViewBuilder
    private var activeSessionArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.sessions.count > 1 ? "ACTIVE SESSIONS" : "ACTIVE SESSION")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.34))
                    .tracking(0.8)
                Spacer()
                if store.sessions.count > 1 {
                    Text("\(store.sessions.count)")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.52))
                }
            }

            if store.sessions.count > 1 {
                Menu {
                    if store.isSessionSelectionPinned {
                        Button("Follow Activity", action: store.followSessionActivity)
                        Divider()
                    }
                    ForEach(store.orderedSessions) { session in
                        Button {
                            store.selectSession(session.id)
                        } label: {
                            Label(
                                "\(session.projectName) · \(session.status.label)",
                                systemImage: session.id == store.activeSessionID ? "checkmark" : "circle"
                            )
                        }
                    }
                } label: {
                    MenuSessionSummary(session: store.activeSession)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            } else {
                MenuSessionSummary(session: store.activeSession)
            }
        }
    }

    @ViewBuilder
    private var alerts: some View {
        if !store.approvalsEnabled {
            MenuNotice(
                icon: "shield.slash",
                title: "Approval prompts are bypassed",
                actionTitle: "Enable",
                action: store.enablePermissionPrompts
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        if let error = store.lastError {
            MenuNotice(icon: "exclamationmark.triangle.fill", title: error)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }
    }

    private var utilityActions: some View {
        HStack(spacing: 4) {
            Menu {
                if store.recentSessions.isEmpty {
                    Button("No recent sessions") {}.disabled(true)
                } else {
                    ForEach(store.recentSessions.prefix(6)) { session in
                        Button(session.projectName) { store.resumeSession(session) }
                            .help(session.cwd)
                    }
                }
            } label: {
                MenuUtilityLabel(title: "Recents", systemImage: "clock")
            }
            .menuStyle(.borderlessButton)

            Menu {
                if settings.favoriteFolders.isEmpty {
                    Button("No favorite folders") {}.disabled(true)
                    Button("Add favorite…", action: store.addFavoriteFolder)
                } else {
                    ForEach(settings.favoriteFolders, id: \.self) { folder in
                        Button(URL(fileURLWithPath: folder).lastPathComponent) {
                            store.startSession(in: folder)
                        }
                        .help(folder)
                    }
                    Divider()
                    Button("Add favorite…", action: store.addFavoriteFolder)
                }
            } label: {
                MenuUtilityLabel(title: "Favorites", systemImage: "star")
            }
            .menuStyle(.borderlessButton)

            Button(action: store.previewPeek) {
                MenuUtilityLabel(title: "Peek", systemImage: "eye")
            }
            .buttonStyle(.plain)
            .disabled(!settings.showMascot || !settings.peekEnabled || !store.pendingRequests.isEmpty)

            Button(action: updates.checkForUpdates) {
                MenuUtilityLabel(
                    title: updates.phase.hasUpdate ? "Update" : "Updates",
                    systemImage: updates.phase.hasUpdate ? "arrow.down.circle.fill" : "arrow.down.circle",
                    tint: updates.phase.hasUpdate ? IslandPalette.amber : nil
                )
            }
            .buttonStyle(.plain)
            .disabled(!updates.canCheckForUpdates)
        }
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(bridgeReady ? IslandPalette.green : IslandPalette.amber)
                .frame(width: 7, height: 7)
            Text("Bridge")
                .foregroundStyle(Color.white.opacity(0.45))
            Text(bridgeReady ? "Connected" : "Starting")
                .foregroundStyle(bridgeReady ? IslandPalette.green : IslandPalette.amber)
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white.opacity(0.58))
                .keyboardShortcut("q")
        }
        .font(.system(size: 10.5, weight: .medium))
    }

    private var bridgeReady: Bool {
        store.serverStatus == "Local bridge ready"
    }
}

private struct MenuSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
    }
}

private struct MenuPrimaryAction: View {
    let title: String
    let systemImage: String
    var tint: Color = Color.white.opacity(0.66)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .frame(height: 20)
                Text(title)
                    .font(.system(size: 9.5, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 57)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuActionButtonStyle(emphasized: tint == IslandPalette.amber))
    }
}

@MainActor
private struct MenuTerminalAction: View {
    let program: String?
    let action: () -> Void

    var body: some View {
        let identity = TerminalActivator.identity(program: program)
        Button(action: action) {
            VStack(spacing: 7) {
                Group {
                    if let icon = identity.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                    } else {
                        Image(systemName: "terminal")
                            .font(.system(size: 17, weight: .medium))
                    }
                }
                .frame(width: 20, height: 20)
                Text("Open \(identity.title)")
                    .font(.system(size: 9.5, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .foregroundStyle(Color.white.opacity(0.66))
            .frame(maxWidth: .infinity)
            .frame(height: 57)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuActionButtonStyle())
    }
}

private struct MenuActionButtonStyle: ButtonStyle {
    var emphasized = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Color.white.opacity(configuration.isPressed ? 0.10 : (emphasized ? 0.055 : 0)),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
    }
}

@MainActor
private struct MenuTerminalIdentity: View {
    let program: String?

    var body: some View {
        let identity = TerminalActivator.identity(program: program)
        HStack(spacing: 4) {
            if let icon = identity.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 12, height: 12)
            }
            Text(identity.title)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(Color.white.opacity(0.43))
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct MenuUsageSummary: View {
    let snapshot: ClaudeUsageSnapshot

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let window = snapshot.fiveHour {
                line("5h", value: window.utilization)
            }
            if let window = snapshot.sevenDay {
                line("7d", value: window.utilization)
            }
        }
        .font(.system(size: 9, weight: .semibold, design: .monospaced))
    }

    private func line(_ label: String, value: Double) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(Color.white.opacity(0.34))
            Text("\(Int(value.rounded()))%")
                .foregroundStyle(value >= 85 ? IslandPalette.red : (value >= 60 ? IslandPalette.amber : IslandPalette.green))
        }
    }
}

private struct MenuSessionSummary: View {
    let session: SessionRecord?

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(IslandPalette.statusColor(session?.status ?? .idle))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text(session?.projectName ?? "No active session")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.86))
                    .lineLimit(1)
                Text(session?.activities.first?.text ?? "Waiting for Claude Code")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.44))
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if let session, session.runningAgentCount > 0 {
                Label("\(session.runningAgentCount)", systemImage: "person.2.fill")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(IslandPalette.amber)
            }
            if session != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.22))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 50)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct MenuUtilityLabel: View {
    let title: String
    let systemImage: String
    var tint: Color?

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(tint ?? Color.white.opacity(0.48))
        .frame(maxWidth: .infinity)
        .frame(height: 43)
        .contentShape(Rectangle())
    }
}

private struct MenuNotice: View {
    let icon: String
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
                .lineLimit(2)
            Spacer(minLength: 4)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.plain)
                    .fontWeight(.semibold)
            }
        }
        .font(.system(size: 10.5, weight: .medium))
        .foregroundStyle(IslandPalette.amber)
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
        .background(IslandPalette.amber.opacity(0.075), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
