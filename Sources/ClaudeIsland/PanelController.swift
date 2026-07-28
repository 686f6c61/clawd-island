import AppKit
import ClaudeIslandCore
import Combine
import SwiftUI

@MainActor
final class PanelController {
    private let store: IslandStore
    private let settings: AppSettings
    private let panel: IslandPanel
    private let hostingController: NSHostingController<IslandRootView>
    private var cancellables = Set<AnyCancellable>()
    private var metrics: ScreenMetrics
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?

    init(store: IslandStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
        metrics = ScreenMetrics.current()
        hostingController = NSHostingController(
            rootView: IslandRootView(
                store: store,
                settings: settings,
                notchWidth: metrics.notchWidth,
                notchHeight: metrics.notchHeight,
                hasHardwareNotch: metrics.hasHardwareNotch
            )
        )
        panel = IslandPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        configurePanel()
        installHiddenIslandClickRecovery()
        publishMetrics()
        observeStore()
        updateFrame(animated: false)
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.screenConfigurationChanged() }
        }
    }

    func show() {
        screenConfigurationChanged(animated: true)
        panel.orderFrontRegardless()
    }

    private func configurePanel() {
        panel.contentViewController = hostingController
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
    }

    private func installHiddenIslandClickRecovery() {
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.restoreHiddenIslandIfNeeded(at: NSEvent.mouseLocation)
            return event
        }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            Task { @MainActor in
                self?.restoreHiddenIslandIfNeeded(at: NSEvent.mouseLocation)
            }
        }
    }

    private func restoreHiddenIslandIfNeeded(at screenPoint: NSPoint) {
        guard store.isManuallyHidden, panel.frame.contains(screenPoint) else { return }
        store.showManuallyHiddenIsland()
        panel.orderFrontRegardless()
    }

    private func observeStore() {
        Publishers.CombineLatest3(
            store.$isExpanded,
            store.$pendingRequests,
            store.$sessions
        )
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in self?.updateFrame(animated: true) }
            .store(in: &cancellables)

        Publishers.CombineLatest(store.$isDormant, store.$isPeeking)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in self?.updateFrame(animated: true) }
            .store(in: &cancellables)

        store.$isManuallyHidden
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateFrame(animated: true) }
            .store(in: &cancellables)

        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.refreshSettings() }
            }
            .store(in: &cancellables)
    }

    private func screenConfigurationChanged(animated: Bool = false) {
        metrics = ScreenMetrics.current()
        publishMetrics()
        hostingController.rootView = IslandRootView(
            store: store,
            settings: settings,
            notchWidth: metrics.notchWidth,
            notchHeight: metrics.notchHeight,
            hasHardwareNotch: metrics.hasHardwareNotch
        )
        updateFrame(animated: animated)
    }

    private func updateFrame(animated: Bool) {
        let size: CGSize
        if store.isManuallyHidden {
            size = IslandPanelLayout.manuallyHiddenSize(
                hasHardwareNotch: metrics.hasHardwareNotch,
                notchWidth: metrics.notchWidth,
                notchHeight: metrics.notchHeight
            )
        } else if store.isDormant {
            size = IslandPanelLayout.dormantSize(
                hasHardwareNotch: metrics.hasHardwareNotch,
                notchWidth: metrics.notchWidth,
                notchHeight: metrics.notchHeight
            )
        } else if store.isExpanded {
            size = IslandPanelLayout.expandedSize(
                preferredWidth: CGFloat(settings.expandedWidth),
                maximumWidth: metrics.screen.frame.width - 32,
                hasHardwareNotch: metrics.hasHardwareNotch,
                notchHeight: metrics.notchHeight,
                activityCount: store.activeSession?.activities.count ?? 0,
                sessionCount: store.sessions.count,
                agentCount: store.activeSession?.agents.count ?? 0,
                hasQuestion: store.currentRequest?.kind == .question,
                showsUsage: settings.showUsage
            )
        } else {
            size = IslandPanelLayout.compactSize(
                hasHardwareNotch: metrics.hasHardwareNotch,
                notchWidth: metrics.notchWidth,
                notchHeight: metrics.notchHeight,
                style: settings.compactStyle
            )
        }
        let screenFrame = metrics.screen.frame
        let frame = NSRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )

        if animated, panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = settings.reduceAnimations || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                    ? 0
                    : 0.24
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    private func refreshSettings() {
        hostingController.rootView = IslandRootView(
            store: store,
            settings: settings,
            notchWidth: metrics.notchWidth,
            notchHeight: metrics.notchHeight,
            hasHardwareNotch: metrics.hasHardwareNotch
        )
        updateFrame(animated: true)
    }

    private func publishMetrics() {
        store.setDisplayGeometry(
            displayName: metrics.screen.localizedName,
            attachment: metrics.attachment,
            notchWidth: metrics.notchWidth,
            notchHeight: metrics.notchHeight
        )
    }
}

private final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct ScreenMetrics {
    let screen: NSScreen
    let attachment: IslandDisplayAttachment
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    var hasHardwareNotch: Bool { attachment == .hardwareNotch }

    @MainActor
    static func current() -> ScreenMetrics {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        let geometry = IslandDisplayGeometryResolver.resolve(
            safeAreaTop: Double(screen.safeAreaInsets.top),
            auxiliaryLeftMaxX: screen.auxiliaryTopLeftArea.map { Double($0.maxX) },
            auxiliaryRightMinX: screen.auxiliaryTopRightArea.map { Double($0.minX) },
            screenWidth: Double(screen.frame.width),
            screenHeight: Double(screen.frame.height),
            scaleFactor: Double(screen.backingScaleFactor)
        )
        return ScreenMetrics(
            screen: screen,
            attachment: geometry.attachment,
            notchWidth: CGFloat(geometry.notchWidth),
            notchHeight: CGFloat(geometry.notchHeight)
        )
    }
}
