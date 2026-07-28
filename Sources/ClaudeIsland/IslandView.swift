import AppKit
import ClaudeIslandCore
import SwiftUI

enum IslandPreviewPresentation {
    case compact
    case expanded

    var isExpanded: Bool { self == .expanded }
}

struct IslandRootView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @ObservedObject var store: IslandStore
    @ObservedObject var settings: AppSettings
    @ObservedObject private var updates: UpdateController
    @ObservedObject var displayState: IslandDisplayState
    let previewPresentation: IslandPreviewPresentation?

    private var notchWidth: CGFloat { displayState.notchWidth }
    private var notchHeight: CGFloat { displayState.notchHeight }
    private var hasHardwareNotch: Bool { displayState.hasHardwareNotch }

    init(
        store: IslandStore,
        settings: AppSettings,
        displayState: IslandDisplayState,
        previewPresentation: IslandPreviewPresentation? = nil,
        updates: UpdateController = .shared
    ) {
        self.store = store
        self.settings = settings
        self.updates = updates
        self.displayState = displayState
        self.previewPresentation = previewPresentation
    }

    private var renderedExpanded: Bool {
        previewPresentation?.isExpanded ?? (!store.isManuallyHidden && store.isExpanded)
    }

    private var renderedDormant: Bool {
        previewPresentation == nil && store.isDormant
    }

    private var renderedManuallyHidden: Bool {
        previewPresentation == nil && store.isManuallyHidden
    }

    private var shouldReduceMotion: Bool {
        settings.reduceAnimations || systemReduceMotion
    }

    private var effectiveBodyOpacity: Double {
        systemReduceTransparency ? 1 : settings.bodyOpacity
    }

    var body: some View {
        let silhouette = IslandSilhouette(
            notchWidth: notchWidth,
            notchHeight: notchHeight,
            hasHardwareNotch: hasHardwareNotch,
            expansionProgress: renderedExpanded ? 1 : 0
        )

        ZStack(alignment: .top) {
            if renderedManuallyHidden {
                Color.clear
            } else if renderedDormant {
                dormant
            } else {
                ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Color(white: 0.018).opacity(effectiveBodyOpacity), location: 0),
                        .init(color: Color(white: 0.025 + settings.gradientIntensity * 0.02).opacity(effectiveBodyOpacity), location: 0.48),
                        .init(color: Color(white: 0.035 + settings.gradientIntensity * 0.055).opacity(effectiveBodyOpacity), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.38),
                        .init(color: .black.opacity(0.72), location: 0.60),
                        .init(color: .clear, location: 1),
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: max(260, notchWidth * 1.2)
                )

                Color.black
                    .frame(
                        width: hasHardwareNotch ? notchWidth : 200,
                        height: hasHardwareNotch ? notchHeight + 1 : 6
                    )
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .ignoresSafeArea()

                if renderedExpanded {
                    expanded
                        .transition(.opacity)
                } else {
                    compact
                        .transition(.opacity)
                }
            }

            if previewPresentation == nil {
                notchInteractionTarget
            }
        }
        .clipShape(silhouette)
        .contentShape(silhouette)
        .shadow(color: renderedDormant || renderedManuallyHidden ? .clear : .black.opacity(0.42), radius: 24, y: 12)
        .animation(shouldReduceMotion ? nil : .easeInOut(duration: 0.18), value: renderedExpanded)
        .animation(shouldReduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.72), value: store.isPeeking)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var notchInteractionTarget: some View {
        let target = Color.clear
            .frame(
                width: hasHardwareNotch ? max(notchWidth + 48, 208) : 180,
                height: hasHardwareNotch ? max(notchHeight + 10, 40) : 18
            )
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilitySortPriority(100)
            .zIndex(10)

        if renderedManuallyHidden {
            target
                .onTapGesture(perform: store.showManuallyHiddenIsland)
                .accessibilityAction {
                    store.showManuallyHiddenIsland()
                }
                .accessibilityAction(named: "Show Claude Island") {
                    store.showManuallyHiddenIsland()
                }
                .accessibilityLabel("Show Claude Island")
                .accessibilityHint("Click the camera notch or top-center edge")
        } else {
            target
                .gesture(visibleIslandGesture)
                .accessibilityAction {
                    store.handlePrimaryIslandClick()
                }
                .accessibilityAction(named: renderedExpanded ? "Collapse Claude Island" : "Expand Claude Island") {
                    store.handlePrimaryIslandClick()
                }
                .accessibilityLabel(renderedExpanded ? "Collapse Claude Island" : "Expand Claude Island")
                .accessibilityHint("Click to resize, or double-click to hide")
        }
    }

    private var visibleIslandGesture: some Gesture {
        TapGesture(count: 2)
            .exclusively(before: TapGesture(count: 1))
            .onEnded { result in
                guard previewPresentation == nil else { return }
                switch result {
                case .first:
                    if settings.doubleClickNotchToHide {
                        store.hideIslandManually()
                    } else {
                        store.handlePrimaryIslandClick()
                    }
                case .second:
                    store.handlePrimaryIslandClick()
                }
            }
    }

    private var dormant: some View {
        ZStack {
            Color.clear
            if store.isPeeking, settings.showMascot {
                ClawdStateView(status: .idle, set: settings.mascotSet, reduceMotion: shouldReduceMotion)
                    .frame(width: 38, height: 34)
                    .offset(
                        x: hasHardwareNotch
                            ? (store.peekSide == .left ? -(notchWidth / 2 + 14) : notchWidth / 2 + 14)
                            : 0,
                        y: hasHardwareNotch ? 5 : -8
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: peekInsertionEdge).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .contentShape(Rectangle())
        .allowsHitTesting(store.isPeeking)
        .onTapGesture {
            if store.isPeeking { store.wakeFromPeek() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(store.isPeeking ? "Clawd is here. Open Claude Island." : "Claude Island hidden")
        .accessibilityHint(store.displayAttachment)
        .accessibilityAddTraits(store.isPeeking ? .isButton : [])
    }

    private var compact: some View {
        HStack(spacing: 0) {
            HStack(spacing: settings.compactStyle == .minimal ? 4 : 10) {
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
                    .frame(width: updates.phase.hasUpdate ? 48 : 34, height: updates.phase.hasUpdate ? 38 : 30)
                }
                if settings.compactStyle == .informative {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Claude")
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Text(compactSubtitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(IslandPalette.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if hasHardwareNotch {
                Color.clear
                    .frame(width: notchWidth)
                    .accessibilityHidden(true)
            }

            HStack(spacing: 7) {
                if settings.showUsage,
                   let usage = store.usageSnapshot,
                   usage.fiveHour != nil || usage.sevenDay != nil {
                    CompactUsageView(snapshot: usage)
                }
                statusDot
                if store.displayAttentionCount > 0 {
                    Text("\(store.displayAttentionCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .foregroundStyle(Color.black)
                        .background(IslandPalette.amber, in: Capsule())
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(IslandPalette.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.top, 8)
        .padding(.horizontal, 15)
        .padding(.bottom, 8)
        .contentShape(Rectangle())
        .gesture(visibleIslandGesture)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Claude Island, \(store.activeSession?.status.label ?? "ready")")
        .accessibilityHint(store.displayAttachment)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Toggle Claude Island") {
            store.handlePrimaryIslandClick()
        }
    }

    private var peekInsertionEdge: Edge {
        guard hasHardwareNotch else { return .top }
        return store.peekSide == .left ? .trailing : .leading
    }

    private var compactSubtitle: String {
        if case let .available(version) = updates.phase {
            return "Update \(version) available"
        }
        return switch settings.compactContent {
        case .status:
            store.sessions.count > 1 ? store.multiSessionSummary : (store.activeSession?.status.label ?? "Ready")
        case .project:
            store.activeSession?.projectName ?? "No session"
        case .activity:
            store.activeSession?.activities.first?.text ?? "Waiting for Claude"
        }
    }

    private var expanded: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: hasHardwareNotch ? max(72, notchHeight + 46) : 44)
            ExpandedIslandContent(store: store, settings: settings, updates: updates)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard previewPresentation == nil else { return }
                    store.handlePrimaryIslandClick()
                }
        }
    }

    @ViewBuilder
    private var statusDot: some View {
        let status = store.activeSession?.status ?? .idle
        Circle()
            .fill(IslandPalette.statusColor(status))
            .frame(width: 7, height: 7)
            .shadow(color: status == .running ? IslandPalette.amber.opacity(0.7) : .clear, radius: 5)
    }

}

private struct IslandSilhouette: Shape {
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let hasHardwareNotch: Bool
    var expansionProgress: CGFloat

    var animatableData: CGFloat {
        get { expansionProgress }
        set { expansionProgress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let progress = min(max(expansionProgress, 0), 1)
        let bottomRadius = min(24, rect.height / 2)
        let targetNeckWidth = min(hasHardwareNotch ? max(notchWidth, 180) : 200, rect.width - 120)
        let neckWidth = rect.width - ((rect.width - targetNeckWidth) * progress)
        let neckLeft = rect.midX - neckWidth / 2
        let neckRight = rect.midX + neckWidth / 2
        let neckBottom = hasHardwareNotch ? notchHeight * progress : 0
        let shoulderY = (hasHardwareNotch ? notchHeight + 46 : 38) * progress
        let outerRadius = 24 * progress
        let verticalTangent = 28 * progress

        var path = Path()
        path.move(to: CGPoint(x: neckLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: neckRight, y: rect.minY))
        path.addLine(to: CGPoint(x: neckRight, y: neckBottom))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: shoulderY + outerRadius),
            control1: CGPoint(x: neckRight, y: neckBottom + verticalTangent),
            control2: CGPoint(x: rect.maxX, y: shoulderY - 8 * progress)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottomRadius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: shoulderY + outerRadius))
        path.addCurve(
            to: CGPoint(x: neckLeft, y: neckBottom),
            control1: CGPoint(x: rect.minX, y: shoulderY - 8 * progress),
            control2: CGPoint(x: neckLeft, y: neckBottom + verticalTangent)
        )
        path.closeSubpath()
        return path
    }
}

private struct ExpandedIslandContent: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @ObservedObject var store: IslandStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var updates: UpdateController

    private var shouldReduceMotion: Bool {
        settings.reduceAnimations || systemReduceMotion
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if settings.showUsage {
                UsageOverviewView(store: store)
            }
            Divider().overlay(IslandPalette.separator)
            workspaceContent
            actionArea
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Claude Island expanded controls")
    }

    private var header: some View {
        HStack(spacing: 10) {
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
                .frame(width: updates.phase.hasUpdate ? 48 : 36, height: updates.phase.hasUpdate ? 40 : 32)
            }
            Text("Claude Code")
                .font(.system(size: 13, weight: .semibold))
            Circle()
                .fill(IslandPalette.statusColor(store.activeSession?.status ?? .idle))
                .frame(width: 7, height: 7)
            Text(store.activeSession?.projectName ?? "Waiting for a session")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Text(store.activeSession?.lastUpdated.formatted(date: .omitted, time: .standard) ?? "")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.34))
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                Button(action: store.jumpToTerminal) {
                    TerminalButtonLabel(program: store.activeSession?.terminalProgram)
                }
                .buttonStyle(HeaderButtonStyle())
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
                .disabled(store.activeSession == nil)
                Button(action: store.dismissCompletion) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(HeaderButtonStyle(iconOnly: true))
                .accessibilityLabel("Collapse Island")
            }
            .padding(.trailing, 5)
        }
        .frame(height: 46)
    }

    @ViewBuilder
    private var workspaceContent: some View {
        if store.sessions.count > 1 {
            MultiSessionWorkspaceView(store: store)
        } else {
            SingleSessionWorkspaceView(session: store.activeSession)
        }
    }

    @ViewBuilder
    private var actionArea: some View {
        if let request = store.currentRequest {
            switch request.kind {
            case .permission:
                PermissionRequestView(store: store, request: request)
            case .question:
                QuestionRequestView(store: store, request: request)
            }
        } else if updates.phase.hasUpdate {
            UpdateAvailableNotice(updates: updates)
        } else if !store.approvalsEnabled {
            PermissionModeNotice(store: store)
        } else {
            StatusStrip(store: store)
        }
    }
}

private struct SingleSessionWorkspaceView: View {
    let session: SessionRecord?

    var body: some View {
        VStack(spacing: 0) {
            ActivityListView(activities: Array((session?.activities ?? []).prefix(3)))
            if let session, !session.agents.isEmpty {
                AgentStripView(session: session)
                    .padding(.bottom, 7)
            }
        }
        .padding(.vertical, 7)
    }
}

private struct MultiSessionWorkspaceView: View {
    @ObservedObject var store: IslandStore

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 5) {
                HStack(spacing: 7) {
                    Text("SESSIONS")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.38))
                    Text("\(store.sessions.count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.78))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.62), in: Capsule())
                    Spacer()
                    if store.isSessionSelectionPinned {
                        Button("Follow") { store.followSessionActivity() }
                            .buttonStyle(.plain)
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(IslandPalette.amber)
                            .help("Follow the session that needs attention automatically")
                    }
                }
                .frame(height: 20)

                ScrollView(.vertical) {
                    LazyVStack(spacing: 3) {
                        ForEach(store.orderedSessions) { session in
                            SessionListRow(
                                session: session,
                                isSelected: session.id == store.activeSessionID,
                                action: { store.selectSession(session.id) }
                            )
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            .frame(width: 218)

            Rectangle()
                .fill(IslandPalette.separator)
                .frame(width: 1)

            VStack(spacing: 0) {
                if let session = store.activeSession {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(IslandPalette.statusColor(session.status))
                            .frame(width: 7, height: 7)
                        Text(session.projectName)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        if session.runningAgentCount > 0 {
                            Label("\(session.runningAgentCount)", systemImage: "person.2.fill")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(IslandPalette.amber)
                        }
                    }
                    .frame(height: 25)

                    ActivityListView(activities: Array(session.activities.prefix(3)))

                    if !session.agents.isEmpty {
                        AgentStripView(session: session)
                            .padding(.top, 3)
                    }
                } else {
                    ActivityListView(activities: [])
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .frame(height: 158)
    }
}

@MainActor
private struct SessionListRow: View {
    let session: SessionRecord
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Circle()
                    .fill(IslandPalette.statusColor(session.status))
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.projectName)
                        .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(Color.white.opacity(isSelected ? 0.92 : 0.68))
                        .lineLimit(1)
                    Text(TerminalActivator.identity(program: session.terminalProgram).title)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.32))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if session.runningAgentCount > 0 {
                    Label("\(session.runningAgentCount)", systemImage: "person.2.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(IslandPalette.amber.opacity(0.86))
                }
                if session.status == .waiting || session.status == .failed {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(IslandPalette.statusColor(session.status))
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(
                isSelected ? Color.white.opacity(0.09) : Color.white.opacity(0.025),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .help("\(session.status.label) · \(session.cwd)")
    }
}

private struct ActivityListView: View {
    let activities: [ActivityItem]

    var body: some View {
        VStack(spacing: 0) {
            if activities.isEmpty {
                ActivityRow(time: "—", text: "Waiting for Claude Code", kind: .normal)
            } else {
                ForEach(activities) { activity in
                    ActivityRow(
                        time: activity.date.formatted(date: .omitted, time: .standard),
                        text: activity.text,
                        kind: activity.kind
                    )
                }
            }
        }
    }
}

private struct AgentStripView: View {
    let session: SessionRecord

    private var agents: [AgentRecord] {
        session.agents.values.sorted {
            let left = priority($0.status)
            let right = priority($1.status)
            return left == right ? $0.lastUpdated > $1.lastUpdated : left < right
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 9))
                .foregroundStyle(Color.white.opacity(0.34))
            ForEach(Array(agents.prefix(4))) { agent in
                HStack(spacing: 4) {
                    Circle()
                        .fill(IslandPalette.statusColor(agent.status))
                        .frame(width: 5, height: 5)
                    Text(agent.type)
                        .lineLimit(1)
                }
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.58))
                .padding(.horizontal, 6)
                .frame(height: 20)
                .background(Color.white.opacity(0.045), in: Capsule())
                .help("\(agent.status.label) · \(agent.lastActivity)")
            }
            if agents.count > 4 {
                Text("+\(agents.count - 4)")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            Spacer(minLength: 0)
        }
        .frame(height: 23)
    }

    private func priority(_ status: SessionStatus) -> Int {
        switch status {
        case .waiting: 0
        case .failed: 1
        case .running: 2
        case .completed: 3
        case .idle: 4
        }
    }
}

private struct CompactUsageView: View {
    let snapshot: ClaudeUsageSnapshot

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if let window = snapshot.fiveHour {
                usageLine(label: "5h", window: window)
            }
            if let window = snapshot.sevenDay {
                usageLine(label: "7d", window: window)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(UsageFormat.accessibilitySummary(snapshot))
    }

    private func usageLine(label: String, window: ClaudeUsageWindow) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .foregroundStyle(Color.white.opacity(0.38))
            Text(UsageFormat.percentage(window.utilization))
                .foregroundStyle(UsageFormat.color(window.utilization))
        }
        .font(.system(size: 9, weight: .semibold, design: .monospaced))
        .lineLimit(1)
    }
}

private struct UsageOverviewView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var store: IslandStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gauge.with.dots.needle.50percent")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(IslandPalette.amber)
                .frame(width: 18)

            if let snapshot = store.usageSnapshot,
               snapshot.fiveHour != nil || snapshot.sevenDay != nil {
                if let window = snapshot.fiveHour {
                    UsageMetricView(title: "5-hour", window: window)
                        .layoutPriority(1)
                }
                if snapshot.fiveHour != nil, snapshot.sevenDay != nil {
                    Divider().overlay(IslandPalette.separator).frame(height: 24)
                }
                if let window = snapshot.sevenDay {
                    UsageMetricView(title: "Weekly", window: window)
                        .layoutPriority(1)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Claude usage")
                        .font(.system(size: 10.5, weight: .semibold))
                    Text(store.usageStatus)
                        .font(.system(size: 9.5))
                        .foregroundStyle(IslandPalette.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)
            Button(action: store.refreshUsage) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10.5, weight: .semibold))
                    .rotationEffect(store.isRefreshingUsage ? .degrees(360) : .zero)
                    .animation(
                        store.isRefreshingUsage && !reduceMotion
                            ? .linear(duration: 0.9).repeatForever(autoreverses: false)
                            : nil,
                        value: store.isRefreshingUsage
                    )
            }
            .buttonStyle(HeaderButtonStyle(iconOnly: true))
            .disabled(!store.canRefreshUsage)
            .accessibilityLabel("Refresh Claude usage")
        }
        .frame(height: 45)
    }
}

private struct UsageMetricView: View {
    let title: String
    let window: ClaudeUsageWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(title)
                    .foregroundStyle(Color.white.opacity(0.48))
                    .fixedSize(horizontal: true, vertical: false)
                Text(UsageFormat.percentage(window.utilization))
                    .foregroundStyle(UsageFormat.color(window.utilization))
                    .fixedSize(horizontal: true, vertical: false)
                if let resetsAt = window.resetsAt {
                    Text("· resets in \(UsageFormat.countdown(to: resetsAt))")
                        .foregroundStyle(Color.white.opacity(0.34))
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .font(.system(size: 9.5, weight: .medium, design: .rounded))

            ProgressView(value: window.utilization, total: 100)
                .progressViewStyle(.linear)
                .tint(UsageFormat.color(window.utilization))
                .frame(maxWidth: .infinity)
                .scaleEffect(x: 1, y: 0.7, anchor: .center)
        }
        .frame(minWidth: 170, idealWidth: 180, maxWidth: 190, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var value = "\(title) usage \(UsageFormat.percentage(window.utilization))"
        if let resetsAt = window.resetsAt {
            value += ", resets in \(UsageFormat.countdown(to: resetsAt))"
        }
        return value
    }
}

private enum UsageFormat {
    static func percentage(_ utilization: Double) -> String {
        "\(Int(utilization.rounded()))%"
    }

    static func countdown(to date: Date) -> String {
        let minutes = max(0, Int(ceil(date.timeIntervalSinceNow / 60)))
        if minutes == 0 { return "now" }
        if minutes >= 1_440 {
            let days = minutes / 1_440
            let hours = (minutes % 1_440) / 60
            return hours == 0 ? "\(days)d" : "\(days)d \(hours)h"
        }
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
        }
        return "\(minutes)m"
    }

    static func color(_ utilization: Double) -> Color {
        if utilization >= 85 { return IslandPalette.red }
        if utilization >= 60 { return IslandPalette.amber }
        return IslandPalette.green
    }

    static func accessibilitySummary(_ snapshot: ClaudeUsageSnapshot) -> String {
        var parts: [String] = []
        if let fiveHour = snapshot.fiveHour {
            parts.append("5-hour usage \(percentage(fiveHour.utilization))")
        }
        if let sevenDay = snapshot.sevenDay {
            parts.append("weekly usage \(percentage(sevenDay.utilization))")
        }
        return parts.joined(separator: ", ")
    }
}

private struct UpdateAvailableNotice: View {
    @ObservedObject var updates: UpdateController

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(IslandPalette.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text(updates.phase.title)
                    .font(.system(size: 11.5, weight: .semibold))
                Text("Signed update ready to review and install.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(IslandPalette.secondary)
            }
            Spacer()
            Button("View update", action: updates.checkForUpdates)
                .buttonStyle(DecisionButtonStyle(role: .primary))
        }
        .padding(10)
        .background(IslandPalette.row, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ActivityRow: View {
    let time: String
    let text: String
    let kind: ActivityItem.Kind

    var body: some View {
        HStack(spacing: 12) {
            Text(time)
                .frame(width: 68, alignment: .leading)
                .foregroundStyle(Color.white.opacity(0.33))
            Rectangle()
                .fill(IslandPalette.separator)
                .frame(width: 1, height: 14)
            Text(text)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(foreground)
            Spacer(minLength: 0)
        }
        .font(.system(size: 11.5, weight: kind == .active ? .semibold : .regular, design: .monospaced))
        .frame(height: 28)
    }

    private var foreground: Color {
        switch kind {
        case .active: IslandPalette.amber
        case .success: IslandPalette.green
        case .failure: IslandPalette.red
        case .normal: Color.white.opacity(0.56)
        }
    }
}

private struct PermissionRequestView: View {
    @ObservedObject var store: IslandStore
    let request: PendingHookRequest

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(IslandPalette.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text(request.event.toolName ?? "Permission")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(IslandPalette.secondary)
                Text(request.event.toolSummary)
                    .font(.system(size: 11.5, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 8)
            Button("Deny", action: store.deny)
                .buttonStyle(DecisionButtonStyle(role: .secondary))
                .keyboardShortcut(.escape, modifiers: [])
            if !request.event.permissionSuggestions.isEmpty {
                Menu {
                    Button("Always allow this rule") { store.approve(always: true) }
                } label: {
                    Image(systemName: "chevron.down")
                        .frame(width: 16, height: 22)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("More approval options")
            }
            Button("Approve") { store.approve(always: false) }
                .buttonStyle(DecisionButtonStyle(role: .primary))
                .keyboardShortcut(.return, modifiers: [.command])
        }
        .padding(10)
        .background(IslandPalette.row, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(IslandPalette.separator, lineWidth: 0.75)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Permission request for \(request.event.toolName ?? "tool")")
    }

    private var iconName: String {
        switch request.event.toolName {
        case "Bash": "terminal"
        case "Edit", "Write": "pencil.line"
        case "Read": "doc.text"
        default: "checkmark.shield"
        }
    }
}

private struct QuestionRequestView: View {
    @ObservedObject var store: IslandStore
    let request: PendingHookRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.bubble")
                    .foregroundStyle(IslandPalette.amber)
                Text(request.event.firstQuestionText ?? "Claude needs your input")
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(2)
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(request.event.firstQuestionOptions.prefix(4), id: \.self) { option in
                    Button(option) { store.answer(option) }
                        .buttonStyle(DecisionButtonStyle(role: .secondary))
                }
                if request.event.firstQuestionOptions.isEmpty {
                    Button("Open Terminal", action: store.jumpToTerminal)
                        .buttonStyle(DecisionButtonStyle(role: .primary))
                }
                Spacer()
            }
        }
        .padding(11)
        .background(IslandPalette.row, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(IslandPalette.separator, lineWidth: 0.75)
        }
    }
}

private struct PermissionModeNotice: View {
    @ObservedObject var store: IslandStore

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.slash")
                .foregroundStyle(IslandPalette.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text("Approvals are bypassed")
                    .font(.system(size: 11.5, weight: .semibold))
                Text("Island can monitor this session, but Claude Code will not ask for permission.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(IslandPalette.secondary)
            }
            Spacer()
            Button("Enable prompts") { store.enablePermissionPrompts() }
                .buttonStyle(DecisionButtonStyle(role: .secondary))
                .help("Changes Claude Code's default permission mode and requires a restart")
        }
        .padding(10)
        .background(IslandPalette.row, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct StatusStrip: View {
    @ObservedObject var store: IslandStore

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: presentation.icon)
                .foregroundStyle(presentation.color)
            Text(presentation.message)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.72))
            Spacer()
            Text(store.serverStatus)
                .font(.system(size: 10.5))
                .foregroundStyle(IslandPalette.secondary)
        }
        .padding(.horizontal, 11)
        .frame(height: 42)
        .background(IslandPalette.row, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var presentation: (icon: String, message: String, color: Color) {
        switch store.activeSession?.status ?? .idle {
        case .idle:
            ("circle.dotted", "Ready for Claude Code", Color.white.opacity(0.42))
        case .running:
            ("waveform.path", "Claude Code is working", IslandPalette.amber)
        case .waiting:
            ("bell.badge.fill", "Claude needs your attention", IslandPalette.amber)
        case .completed:
            ("checkmark.circle.fill", "Done — click Terminal to return", IslandPalette.green)
        case .failed:
            ("exclamationmark.triangle.fill", "The last action failed", IslandPalette.red)
        }
    }
}

@MainActor
private struct TerminalButtonLabel: View {
    let program: String?

    var body: some View {
        let identity = TerminalActivator.identity(program: program)
        HStack(spacing: 5) {
            if let icon = identity.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 15, height: 15)
            } else {
                Image(systemName: "terminal")
                    .frame(width: 15, height: 15)
            }
            Text(identity.title)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct HeaderButtonStyle: ButtonStyle {
    var iconOnly = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(Color.white.opacity(configuration.isPressed ? 1 : 0.66))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, iconOnly ? 8 : 9)
            .frame(height: 28)
            .background(Color.white.opacity(configuration.isPressed ? 0.11 : 0.045), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct DecisionButtonStyle: ButtonStyle {
    enum Role { case primary, secondary }
    let role: Role

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(role == .primary ? Color.black.opacity(0.88) : Color.white.opacity(0.82))
            .padding(.horizontal, 13)
            .frame(height: 32)
            .background(background(configuration.isPressed), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                if role == .secondary {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(IslandPalette.separator, lineWidth: 0.75)
                }
            }
    }

    private func background(_ pressed: Bool) -> Color {
        switch role {
        case .primary: pressed ? IslandPalette.amber.opacity(0.78) : IslandPalette.amber
        case .secondary: Color.white.opacity(pressed ? 0.10 : 0.045)
        }
    }
}
