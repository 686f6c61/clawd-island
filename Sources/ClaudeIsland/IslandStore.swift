import AppKit
import ClaudeIslandCore
import Combine
import Foundation

enum SessionStatus: String, Sendable {
    case idle
    case running
    case waiting
    case completed
    case failed

    var label: String {
        switch self {
        case .idle: "Session started"
        case .running: "Working"
        case .waiting: "Needs you"
        case .completed: "Done"
        case .failed: "Failed"
        }
    }
}

struct ActivityItem: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let text: String
    let kind: Kind

    enum Kind: Sendable {
        case normal
        case active
        case success
        case failure
    }
}

struct AgentRecord: Identifiable, Sendable {
    let id: String
    var type: String
    var status: SessionStatus
    var lastActivity: String
    var lastUpdated: Date
}

struct SessionRecord: Identifiable, Sendable {
    let id: String
    var projectName: String
    var cwd: String
    var terminalProgram: String?
    var terminalSessionID: String?
    var iTermSessionID: String?
    var status: SessionStatus
    var activities: [ActivityItem]
    var agents: [String: AgentRecord]
    var lastUpdated: Date

    var runningAgentCount: Int {
        agents.values.count { $0.status == .running || $0.status == .waiting }
    }
}

struct RecentClaudeSession: Identifiable, Codable, Sendable {
    let id: String
    var projectName: String
    var cwd: String
    var lastUpdated: Date
}

enum PeekSide: Sendable, Equatable {
    case left
    case right
}

final class PendingHookRequest: Identifiable, @unchecked Sendable {
    enum Kind: Sendable {
        case permission
        case question
    }

    let id = UUID()
    let kind: Kind
    let event: HookEvent
    let receivedAt = Date()
    let reply: @Sendable (Data) -> Void

    init(kind: Kind, event: HookEvent, reply: @escaping @Sendable (Data) -> Void) {
        self.kind = kind
        self.event = event
        self.reply = reply
    }
}

@MainActor
final class IslandStore: ObservableObject {
    static let shared = IslandStore()

    @Published var isExpanded = false
    @Published private(set) var sessions: [String: SessionRecord] = [:]
    @Published private(set) var activeSessionID: String?
    @Published private(set) var isSessionSelectionPinned = false
    @Published private(set) var pendingRequests: [PendingHookRequest] = []
    @Published private(set) var serverStatus = "Starting local bridge…"
    @Published private(set) var setupStatus = "Installing Claude Code hooks…"
    @Published private(set) var permissionMode = "default"
    @Published private(set) var lastError: String?
    @Published private(set) var recentSessions: [RecentClaudeSession] = []
    @Published private(set) var usageSnapshot: ClaudeUsageSnapshot?
    @Published private(set) var usageStatus = "Usage starts after the first Claude prompt."
    @Published private(set) var usageLastUpdated: Date?
    @Published private(set) var isRefreshingUsage = false
    @Published private(set) var diagnosticReport = "No diagnostic has been run yet."
    @Published private(set) var isDormant = false
    @Published private(set) var isPeeking = false
    @Published private(set) var isManuallyHidden = false
    @Published private(set) var peekSide: PeekSide = .right
    @Published private(set) var hasHardwareNotch = false
    @Published private(set) var displayAttachment = "Detecting display…"
    @Published private(set) var displayNotchWidth: CGFloat = 0
    @Published private(set) var displayNotchHeight: CGFloat = 0

    private var autoCollapseTask: Task<Void, Never>?
    private var dormancyTask: Task<Void, Never>?
    private var peekTask: Task<Void, Never>?
    private var usageMonitorTask: Task<Void, Never>?
    private var recentSessionSaveTask: Task<Void, Never>?
    private var usageNeedsKeychainAuthorization = false
    private var hasObservedClaudeActivity = false
    private let settings = AppSettings.shared
    private let recentSessionsKey = "recentClaudeSessions"
    private let recentSessionRetention: TimeInterval = 30 * 24 * 60 * 60
    private let recentSessionLimit = 12
    private let recentSessionSaveDelay: Duration = .milliseconds(350)
    private let usageSnapshotKey = "cachedClaudeUsageSnapshot"
    private let usageUpdatedKey = "cachedClaudeUsageUpdatedAt"

    private init() {
        if let data = UserDefaults.standard.data(forKey: recentSessionsKey),
           let decoded = try? JSONDecoder().decode([RecentClaudeSession].self, from: data) {
            let cutoff = Date().addingTimeInterval(-recentSessionRetention)
            recentSessions = Array(decoded.filter { $0.lastUpdated >= cutoff }.prefix(12))
            if recentSessions.count != decoded.count,
               let pruned = try? JSONEncoder().encode(recentSessions) {
                UserDefaults.standard.set(pruned, forKey: recentSessionsKey)
            }
        }
        if let data = UserDefaults.standard.data(forKey: usageSnapshotKey) {
            usageSnapshot = try? JSONDecoder().decode(ClaudeUsageSnapshot.self, from: data)
            usageLastUpdated = UserDefaults.standard.object(forKey: usageUpdatedKey) as? Date
        }
        Task { @MainActor [weak self] in
            self?.scheduleDormancy()
        }
    }

    var activeSession: SessionRecord? {
        guard let activeSessionID else { return nil }
        return sessions[activeSessionID]
    }

    var currentRequest: PendingHookRequest? { pendingRequests.first }
    var attentionCount: Int { pendingRequests.count }
    var canRefreshUsage: Bool {
        settings.showUsage && hasObservedClaudeActivity && !isRefreshingUsage
    }
    var orderedSessions: [SessionRecord] {
        sessions.values.sorted {
            let leftPriority = sessionPriority($0.status)
            let rightPriority = sessionPriority($1.status)
            return leftPriority == rightPriority ? $0.lastUpdated > $1.lastUpdated : leftPriority < rightPriority
        }
    }
    var workingSessionCount: Int { sessions.values.count { $0.status == .running } }
    var completedSessionCount: Int { sessions.values.count { $0.status == .completed } }
    var attentionSessionCount: Int {
        var identifiers = Set(sessions.values.filter { $0.status == .waiting || $0.status == .failed }.map(\.id))
        identifiers.formUnion(pendingRequests.map { $0.event.sessionID })
        return identifiers.count
    }
    var displayAttentionCount: Int { max(attentionSessionCount, pendingRequests.count) }
    var activeAgentCount: Int { sessions.values.reduce(0) { $0 + $1.runningAgentCount } }
    var multiSessionSummary: String {
        var parts: [String] = []
        if workingSessionCount > 0 { parts.append("\(workingSessionCount) working") }
        if attentionSessionCount > 0 { parts.append("\(attentionSessionCount) need you") }
        if completedSessionCount > 0 { parts.append("\(completedSessionCount) done") }
        return parts.isEmpty ? "\(sessions.count) sessions" : parts.joined(separator: " · ")
    }
    var approvalsEnabled: Bool { permissionMode != "bypassPermissions" }

    func setServerStatus(_ value: String) {
        serverStatus = value
    }

    func setSetup(result: HookInstallationResult) {
        permissionMode = result.permissionMode
        setupStatus = result.configurationChanged ? "Claude Code hooks installed" : "Claude Code hooks ready"
    }

    func setSetupError(_ error: Error) {
        lastError = error.localizedDescription
        setupStatus = "Hook installation needs attention"
    }

    func setHooksDisabled() {
        setupStatus = "Claude Code hooks disabled"
    }

    func setDisplayGeometry(
        displayName: String,
        attachment: IslandDisplayAttachment,
        notchWidth: CGFloat,
        notchHeight: CGFloat
    ) {
        hasHardwareNotch = attachment == .hardwareNotch
        displayNotchWidth = notchWidth
        displayNotchHeight = notchHeight
        if hasHardwareNotch {
            displayAttachment = "\(displayName) · notch \(Int(notchWidth.rounded())) × \(Int(notchHeight.rounded())) pt"
        } else {
            displayAttachment = "\(displayName) · top edge"
        }
    }

    func setDisplayUnavailable() {
        hasHardwareNotch = false
        displayAttachment = "Waiting for a display…"
        displayNotchWidth = 0
        displayNotchHeight = 0
    }

    func handle(event: HookEvent, reply: @escaping @Sendable (Data) -> Void) -> Bool {
        wakeForActivity()
        noteClaudeActivityIfNeeded(event.eventName)
        var session = sessions[event.sessionID] ?? SessionRecord(
            id: event.sessionID,
            projectName: event.projectName,
            cwd: event.cwd,
            terminalProgram: event.terminalProgram,
            terminalSessionID: event.terminalSessionID,
            iTermSessionID: event.iTermSessionID,
            status: .idle,
            activities: [],
            agents: [:],
            lastUpdated: Date()
        )

        session.projectName = event.projectName
        if !event.cwd.isEmpty { session.cwd = event.cwd }
        if let terminalProgram = event.terminalProgram { session.terminalProgram = terminalProgram }
        if let terminalSessionID = event.terminalSessionID { session.terminalSessionID = terminalSessionID }
        if let iTermSessionID = event.iTermSessionID { session.iTermSessionID = iTermSessionID }
        session.lastUpdated = Date()
        if event.eventName == "UserPromptSubmit" {
            session.agents = session.agents.filter { $0.value.status == .running || $0.value.status == .waiting }
        }

        let kind: ActivityItem.Kind
        switch event.eventName {
        case "SessionStart":
            session.status = .idle
            kind = .normal
        case "UserPromptSubmit", "PreToolUse", "SubagentStart":
            session.status = .running
            kind = .active
        case "PostToolUse", "SubagentStop":
            session.status = .running
            kind = event.eventName == "SubagentStop" ? .success : .normal
        case "PostToolUseFailure":
            session.status = .failed
            kind = .failure
            if settings.expandFailure { isExpanded = true }
        case "Stop":
            session.status = .completed
            kind = .success
            if settings.expandCompletion { isExpanded = true }
            scheduleAutoCollapse()
        case "SessionEnd":
            session.status = .idle
            kind = .normal
            if !isExpanded { scheduleDormancy() }
        case "Notification":
            session.status = .waiting
            kind = .active
            if event.notificationType != nil, settings.expandNotifications { isExpanded = true }
        default:
            kind = .normal
        }

        if let agentID = event.agentID {
            var agent = session.agents[agentID] ?? AgentRecord(
                id: agentID,
                type: event.agentType ?? "Subagent",
                status: .running,
                lastActivity: event.activitySummary,
                lastUpdated: Date()
            )
            if let agentType = event.agentType, !agentType.isEmpty { agent.type = agentType }
            switch event.eventName {
            case "SubagentStop": agent.status = .completed
            case "PostToolUseFailure": agent.status = .failed
            case "Notification", "PermissionRequest": agent.status = .waiting
            default: agent.status = .running
            }
            agent.lastActivity = event.lastAssistantMessage.map { String($0.prefix(120)) } ?? event.activitySummary
            agent.lastUpdated = Date()
            session.agents[agentID] = agent
            session.agents = AgentRetentionPolicy.retained(from: session.agents)
        }

        let activity = ActivityItem(date: Date(), text: event.activitySummary, kind: kind)
        session.activities.insert(activity, at: 0)
        session.activities = Array(session.activities.prefix(20))
        sessions[event.sessionID] = session
        updateRecentSession(from: session)

        if event.eventName == "SessionEnd" {
            let abandonedRequests = pendingRequests.filter { $0.event.sessionID == event.sessionID }
            abandonedRequests.forEach { $0.reply(HookDecision.empty) }
            pendingRequests.removeAll { $0.event.sessionID == event.sessionID }
            sessions.removeValue(forKey: event.sessionID)
            if activeSessionID == event.sessionID {
                isSessionSelectionPinned = false
                activeSessionID = preferredSessionID()
            }
            if sessions.isEmpty { scheduleDormancy() }
            return false
        }

        if event.eventName == "PermissionRequest" {
            sessions[event.sessionID]?.status = .waiting
            pendingRequests.append(PendingHookRequest(kind: .permission, event: event, reply: reply))
            updateAutomaticSelection(for: event.sessionID, requiresAttention: true)
            requestAttention(
                expand: settings.expandPermissions,
                announcement: "Claude needs permission for \(event.toolName ?? "a tool")."
            )
            return true
        }

        if event.eventName == "PreToolUse", event.toolName == "AskUserQuestion" {
            sessions[event.sessionID]?.status = .waiting
            pendingRequests.append(PendingHookRequest(kind: .question, event: event, reply: reply))
            updateAutomaticSelection(for: event.sessionID, requiresAttention: true)
            requestAttention(
                expand: settings.expandQuestions,
                announcement: event.firstQuestionText ?? "Claude needs your input."
            )
            return true
        }

        updateAutomaticSelection(
            for: event.sessionID,
            requiresAttention: session.status == .waiting || session.status == .failed
        )
        return false
    }

    func approve(always: Bool) {
        guard let request = currentRequest, request.kind == .permission else { return }
        do {
            request.reply(try HookDecision.allowPermission(for: request.event, always: always))
            finish(request: request, activity: always ? "Always allowed \(request.event.toolName ?? "tool")" : "Approved \(request.event.toolName ?? "tool")", kind: .success)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deny() {
        guard let request = currentRequest, request.kind == .permission else { return }
        do {
            request.reply(try HookDecision.denyPermission())
            finish(request: request, activity: "Denied \(request.event.toolName ?? "tool")", kind: .failure)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func answer(_ answer: String) {
        guard let request = currentRequest, request.kind == .question else { return }
        do {
            request.reply(try HookDecision.answerQuestion(event: request.event, answer: answer))
            finish(request: request, activity: "You answered: \(answer)", kind: .success)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func dismissCompletion() {
        collapse()
    }

    func collapse() {
        autoCollapseTask?.cancel()
        isExpanded = false
        scheduleDormancy()
    }

    func expand() {
        autoCollapseTask?.cancel()
        isManuallyHidden = false
        wakeForActivity()
        isExpanded = true
    }

    func handlePrimaryIslandClick() {
        if isManuallyHidden {
            showManuallyHiddenIsland()
        } else if isExpanded {
            collapse()
        } else {
            expand()
        }
    }

    func wakeFromPeek() {
        wakeForActivity()
        isExpanded = true
    }

    func previewPeek() {
        guard pendingRequests.isEmpty else {
            lastError = "Finish the current Claude request before previewing Clawd."
            return
        }
        dormancyTask?.cancel()
        peekTask?.cancel()
        isManuallyHidden = false
        isExpanded = false
        isDormant = true
        chooseNextPeekSide()
        isPeeking = true
        peekTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(max(1, self.settings.peekDuration)))
            guard !Task.isCancelled, self.isDormant else { return }
            self.isPeeking = false
            self.startPeekCycle()
        }
    }

    func enablePermissionPrompts() {
        do {
            try HookSettingsInstaller.enablePermissionPrompts()
            permissionMode = HookSettingsInstaller.effectivePermissionMode()
            setupStatus = "Permission prompts enabled — restart Claude Code"
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshPermissionMode() {
        permissionMode = HookSettingsInstaller.effectivePermissionMode()
        setupStatus = "Claude Code settings applied — restart active sessions"
    }

    func jumpToTerminal() {
        TerminalActivator.activate(program: activeSession?.terminalProgram, preference: settings.preferredTerminal)
    }

    func selectSession(_ id: String) {
        guard sessions[id] != nil else { return }
        activeSessionID = id
        isSessionSelectionPinned = true
        expand()
    }

    func followSessionActivity() {
        isSessionSelectionPinned = false
        activeSessionID = preferredSessionID()
    }

    func startNewSession() {
        guard let folder = ProjectFolderPicker.choose(
            title: "New Claude Session",
            message: "Choose any accessible folder on this Mac or a connected volume."
        ) else { return }
        launchSession(in: folder, resumeID: nil)
    }

    func startSession(in folder: String) {
        launchSession(in: folder, resumeID: nil)
    }

    func resumeSession(_ session: RecentClaudeSession) {
        launchSession(in: session.cwd, resumeID: session.id)
    }

    func addFavoriteFolder() {
        guard let folder = ProjectFolderPicker.choose(
            title: "Add Favorite Folder",
            message: "Choose any accessible folder on this Mac or a connected volume."
        ) else { return }
        settings.addFavorite(folder)
    }

    func openActiveInFinder() {
        guard let cwd = activeSession?.cwd, !cwd.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: cwd)])
    }

    func clearRecentSessions() {
        recentSessionSaveTask?.cancel()
        recentSessionSaveTask = nil
        recentSessions = []
        UserDefaults.standard.removeObject(forKey: recentSessionsKey)
    }

    func flushRecentSessions() {
        recentSessionSaveTask?.cancel()
        recentSessionSaveTask = nil
        persistRecentSessions()
    }

    func settingsDidChange() {
        if !settings.doubleClickNotchToHide, isManuallyHidden {
            isManuallyHidden = false
            isDormant = false
            isPeeking = false
        }
        if settings.autoHideWhenIdle {
            if !isExpanded, pendingRequests.isEmpty { scheduleDormancy() }
        } else {
            wakeForActivity(scheduleAfterWake: false)
        }
        if settings.showUsage, hasObservedClaudeActivity {
            ensureUsageMonitoring()
        } else if settings.showUsage {
            usageStatus = "Usage starts after the first Claude prompt."
        } else {
            usageMonitorTask?.cancel()
            usageMonitorTask = nil
            isRefreshingUsage = false
        }
    }

    func reinstallHooks() {
        guard let helper = HookBridgeCredential.helperExecutableURL() else {
            lastError = "ClaudeIslandHook is missing from the app bundle."
            return
        }
        do {
            settings.hooksEnabled = true
            setSetup(result: try HookSettingsInstaller.install(helperSourceURL: helper))
            diagnosticReport = "Hooks reinstalled successfully."
        } catch {
            setSetupError(error)
        }
    }

    func uninstallHooks() {
        do {
            let result = try HookSettingsInstaller.uninstall()
            settings.hooksEnabled = false
            setupStatus = "Claude Code hooks disabled"
            diagnosticReport = "Removed \(result.removedHandlers) hook handlers. Existing Claude sessions may need to be restarted."
        } catch {
            setSetupError(error)
        }
    }

    func runDiagnostics() {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        let helperPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ClaudeIsland/ClaudeIslandHook").path
        let helperReady = FileManager.default.isExecutableFile(atPath: helperPath)
        let hookReady = HookSettingsInstaller.isInstalled()
        let active = activeSession.map { "\($0.projectName) [\($0.status.label)]" } ?? "none"
        diagnosticReport = """
        Claude Island \(appVersion)
        Bridge: \(serverStatus)
        Hook configuration: \(hookReady ? "installed" : "not installed")
        Hook helper: \(helperReady ? "executable" : "missing")
        Permission mode: \(permissionMode)
        Active session: \(active)
        Sessions seen: \(sessions.count)
        Auto-hide: \(settings.autoHideWhenIdle ? "enabled" : "disabled")
        Preferred terminal: \(settings.preferredTerminal.title)
        Display attachment: \(displayAttachment)
        Manual notch hide: \(isManuallyHidden ? "hidden" : "visible")
        Usage: \(usageSnapshot == nil ? usageStatus : "available")
        """
    }

    func refreshUsage() {
        guard canRefreshUsage else { return }
        Task { @MainActor [weak self] in
            await self?.refreshUsageNow(allowsKeychainPrompt: true)
        }
    }

    func hideIslandManually() {
        guard settings.doubleClickNotchToHide, !isManuallyHidden else { return }
        autoCollapseTask?.cancel()
        dormancyTask?.cancel()
        peekTask?.cancel()
        isManuallyHidden = true
        isExpanded = false
        isDormant = false
        isPeeking = false
    }

    func showManuallyHiddenIsland() {
        guard isManuallyHidden else { return }
        isManuallyHidden = false
        isDormant = false
        isPeeking = false
        if !pendingRequests.isEmpty { isExpanded = true }
        if !isExpanded, pendingRequests.isEmpty { scheduleDormancy() }
    }

    func testConnection() {
        diagnosticReport = "Testing the local bridge…"
        Task { @MainActor [weak self] in
            let reachable = await HookServer.probe()
            self?.runDiagnostics()
            self?.diagnosticReport += "\nLive TCP probe: \(reachable ? "passed" : "failed")"
        }
    }

    func copyDiagnostics() {
        runDiagnostics()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnosticReport, forType: .string)
    }

    private func finish(request: PendingHookRequest, activity: String, kind: ActivityItem.Kind) {
        pendingRequests.removeAll { $0.id == request.id }
        if var session = sessions[request.event.sessionID] {
            let hasAnotherRequest = pendingRequests.contains { $0.event.sessionID == request.event.sessionID }
            session.status = hasAnotherRequest ? .waiting : .running
            session.activities.insert(ActivityItem(date: Date(), text: activity, kind: kind), at: 0)
            session.activities = Array(session.activities.prefix(20))
            sessions[request.event.sessionID] = session
        }
        if !isSessionSelectionPinned {
            activeSessionID = pendingRequests.first?.event.sessionID ?? preferredSessionID()
        }
        if pendingRequests.isEmpty {
            if settings.soundEnabled { NSSound(named: "Glass")?.play() }
            scheduleAutoCollapse()
        }
    }

    private func sessionPriority(_ status: SessionStatus) -> Int {
        switch status {
        case .waiting: 0
        case .failed: 1
        case .running: 2
        case .completed: 3
        case .idle: 4
        }
    }

    private func preferredSessionID() -> String? {
        orderedSessions.first?.id
    }

    private func updateAutomaticSelection(for sessionID: String, requiresAttention: Bool) {
        guard let candidate = sessions[sessionID] else { return }
        guard let currentID = activeSessionID, let current = sessions[currentID] else {
            activeSessionID = sessionID
            return
        }
        guard !isSessionSelectionPinned else { return }

        if requiresAttention, current.status != .waiting {
            activeSessionID = sessionID
            return
        }

        if sessionPriority(candidate.status) < sessionPriority(current.status) {
            activeSessionID = sessionID
        }
    }

    private func ensureUsageMonitoring() {
        guard settings.showUsage, hasObservedClaudeActivity, usageMonitorTask == nil else { return }
        usageMonitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if !self.usageNeedsKeychainAuthorization {
                    await self.refreshUsageNow(allowsKeychainPrompt: false)
                }
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    return
                }
            }
        }
    }

    private func refreshUsageNow(allowsKeychainPrompt: Bool) async {
        guard settings.showUsage, hasObservedClaudeActivity, !isRefreshingUsage else { return }
        isRefreshingUsage = true
        usageStatus = "Checking Claude usage…"
        defer { isRefreshingUsage = false }

        do {
            let snapshot = try await ClaudeUsageClient.fetch(allowsKeychainPrompt: allowsKeychainPrompt)
            guard !Task.isCancelled else { return }
            usageNeedsKeychainAuthorization = false
            let updatedAt = Date()
            usageSnapshot = snapshot
            usageLastUpdated = updatedAt
            usageStatus = "Updated just now"
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: usageSnapshotKey)
                UserDefaults.standard.set(updatedAt, forKey: usageUpdatedKey)
            }
        } catch {
            guard !Task.isCancelled else { return }
            if let usageError = error as? ClaudeUsageClientError,
               case .keychainAuthorizationRequired = usageError {
                usageNeedsKeychainAuthorization = true
            }
            usageStatus = error.localizedDescription
        }
    }

    private func noteClaudeActivityIfNeeded(_ eventName: String) {
        guard !hasObservedClaudeActivity else { return }
        let workEvents: Set<String> = [
            "UserPromptSubmit",
            "PreToolUse",
            "PostToolUse",
            "PostToolUseFailure",
            "PermissionRequest",
            "Notification",
            "Stop",
            "SubagentStart",
            "SubagentStop",
        ]
        guard workEvents.contains(eventName) else { return }
        hasObservedClaudeActivity = true
        usageStatus = "Claude activity detected. Checking usage…"
        ensureUsageMonitoring()
    }

    private func requestAttention(expand: Bool, announcement: String) {
        autoCollapseTask?.cancel()
        if expand { isExpanded = true }
        NSApplication.shared.requestUserAttention(.informationalRequest)
        if settings.soundEnabled { NSSound(named: "Tink")?.play() }
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [
                .announcement: announcement,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }

    private func scheduleAutoCollapse() {
        autoCollapseTask?.cancel()
        autoCollapseTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(max(0.5, self.settings.autoCollapseDelay)))
            guard !Task.isCancelled, self.pendingRequests.isEmpty else { return }
            self.isExpanded = false
            self.scheduleDormancy()
        }
    }

    private func scheduleDormancy() {
        dormancyTask?.cancel()
        guard settings.autoHideWhenIdle, pendingRequests.isEmpty, !isManuallyHidden else { return }
        dormancyTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(max(5, self.settings.idleHideDelay)))
            guard !Task.isCancelled, !self.isExpanded, self.pendingRequests.isEmpty else { return }
            self.isDormant = true
            self.isPeeking = false
            self.startPeekCycle()
        }
    }

    private func startPeekCycle() {
        peekTask?.cancel()
        guard settings.peekEnabled, isDormant, !isManuallyHidden else { return }
        peekTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.isDormant, self.settings.peekEnabled {
                try? await Task.sleep(for: .seconds(max(10, self.settings.peekInterval)))
                guard !Task.isCancelled, self.isDormant else { return }
                self.chooseNextPeekSide()
                self.isPeeking = true
                try? await Task.sleep(for: .seconds(max(1, self.settings.peekDuration)))
                guard !Task.isCancelled else { return }
                self.isPeeking = false
            }
        }
    }

    private func chooseNextPeekSide() {
        switch settings.peekSide {
        case .alternating:
            peekSide = peekSide == .right ? .left : .right
        case .left:
            peekSide = .left
        case .right:
            peekSide = .right
        }
    }

    private func wakeForActivity(scheduleAfterWake: Bool = true) {
        dormancyTask?.cancel()
        peekTask?.cancel()
        guard !isManuallyHidden else { return }
        isDormant = false
        isPeeking = false
        if scheduleAfterWake, activeSession?.status == .idle, !isExpanded {
            scheduleDormancy()
        }
    }

    private func updateRecentSession(from session: SessionRecord) {
        guard session.id != "unknown", !session.cwd.isEmpty else { return }
        let now = Date()
        let snapshot = RecentClaudeSession(
            id: session.id,
            projectName: session.projectName,
            cwd: session.cwd,
            lastUpdated: session.lastUpdated
        )
        recentSessions = RecentSessionHistory.updating(
            recentSessions,
            with: snapshot,
            now: now,
            retention: recentSessionRetention,
            limit: recentSessionLimit
        )
        scheduleRecentSessionSave()
    }

    private func scheduleRecentSessionSave() {
        recentSessionSaveTask?.cancel()
        recentSessionSaveTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: self.recentSessionSaveDelay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self.persistRecentSessions()
            self.recentSessionSaveTask = nil
        }
    }

    private func persistRecentSessions() {
        guard !recentSessions.isEmpty else {
            UserDefaults.standard.removeObject(forKey: recentSessionsKey)
            return
        }
        if let data = try? JSONEncoder().encode(recentSessions) {
            UserDefaults.standard.set(data, forKey: recentSessionsKey)
        }
    }

    private func launchSession(in folder: String, resumeID: String?) {
        let preference = settings.preferredTerminal
        lastError = nil
        setupStatus = resumeID == nil ? "Opening a new Claude session" : "Resuming Claude session"

        Task { @MainActor [weak self] in
            do {
                try await TerminalActivator.launchClaude(
                    at: folder,
                    resumeSessionID: resumeID,
                    preference: preference
                )
            } catch {
                self?.lastError = error.localizedDescription
            }
        }
    }
}
