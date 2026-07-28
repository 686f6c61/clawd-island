import CoreGraphics

enum IslandPanelLayout {
    private enum Metric {
        static let hiddenWidth: CGFloat = 180
        static let hiddenNotchExtraWidth: CGFloat = 48
        static let hiddenNotchExtraHeight: CGFloat = 10
        static let hiddenNotchMinimumWidth: CGFloat = 208
        static let hiddenNotchMinimumHeight: CGFloat = 40
        static let hiddenTopEdgeHeight: CGFloat = 18

        static let dormantWidth: CGFloat = 84
        static let dormantNotchExtraWidth: CGFloat = 84
        static let dormantNotchExtraHeight: CGFloat = 16
        static let dormantNotchMinimumHeight: CGFloat = 52
        static let dormantTopEdgeHeight: CGFloat = 44

        static let compactHeight: CGFloat = 58
        static let compactNotchExtraHeight: CGFloat = 20
        static let compactMinimalWidth: CGFloat = 176
        static let compactInformativeWidth: CGFloat = 320
        static let compactMinimalNotchWidth: CGFloat = 340
        static let compactInformativeNotchWidth: CGFloat = 440
        static let compactMinimalWingWidth: CGFloat = 122
        static let compactInformativeWingWidth: CGFloat = 250

        static let expandedTopEdgeInset: CGFloat = 44
        static let expandedNotchInset: CGFloat = 72
        static let expandedNotchBodyOffset: CGFloat = 46
        static let expandedHeaderHeight: CGFloat = 47
        static let expandedUsageHeight: CGFloat = 46
        static let activityRowHeight: CGFloat = 28
        static let activityVerticalPadding: CGFloat = 14
        static let agentStripHeight: CGFloat = 23
        static let agentStripBottomSpacing: CGFloat = 7
        static let multiSessionHeight: CGFloat = 158
        static let permissionActionHeight: CGFloat = 92
        static let standardActionHeight: CGFloat = 56
        static let expandedBottomInset: CGFloat = 14
        static let maximumActivityRows = 3
    }

    static func manuallyHiddenSize(
        hasHardwareNotch: Bool,
        notchWidth: CGFloat,
        notchHeight: CGFloat
    ) -> CGSize {
        CGSize(
            width: hasHardwareNotch
                ? max(notchWidth + Metric.hiddenNotchExtraWidth, Metric.hiddenNotchMinimumWidth)
                : Metric.hiddenWidth,
            height: hasHardwareNotch
                ? max(notchHeight + Metric.hiddenNotchExtraHeight, Metric.hiddenNotchMinimumHeight)
                : Metric.hiddenTopEdgeHeight
        )
    }

    static func dormantSize(
        hasHardwareNotch: Bool,
        notchWidth: CGFloat,
        notchHeight: CGFloat
    ) -> CGSize {
        CGSize(
            width: hasHardwareNotch ? notchWidth + Metric.dormantNotchExtraWidth : Metric.dormantWidth,
            height: hasHardwareNotch
                ? max(Metric.dormantNotchMinimumHeight, notchHeight + Metric.dormantNotchExtraHeight)
                : Metric.dormantTopEdgeHeight
        )
    }

    static func compactSize(
        hasHardwareNotch: Bool,
        notchWidth: CGFloat,
        notchHeight: CGFloat,
        style: CompactIslandStyle
    ) -> CGSize {
        if hasHardwareNotch {
            let wingWidth = style == .minimal
                ? Metric.compactMinimalWingWidth
                : Metric.compactInformativeWingWidth
            let minimumWidth = style == .minimal
                ? Metric.compactMinimalNotchWidth
                : Metric.compactInformativeNotchWidth
            return CGSize(
                width: max(notchWidth + wingWidth, minimumWidth),
                height: max(Metric.compactHeight, notchHeight + Metric.compactNotchExtraHeight)
            )
        }
        return CGSize(
            width: style == .minimal ? Metric.compactMinimalWidth : Metric.compactInformativeWidth,
            height: Metric.compactHeight
        )
    }

    static func expandedSize(
        preferredWidth: CGFloat,
        maximumWidth: CGFloat,
        hasHardwareNotch: Bool,
        notchHeight: CGFloat,
        activityCount: Int,
        sessionCount: Int,
        agentCount: Int,
        hasQuestion: Bool,
        showsUsage: Bool
    ) -> CGSize {
        let topInset = hasHardwareNotch
            ? max(Metric.expandedNotchInset, notchHeight + Metric.expandedNotchBodyOffset)
            : Metric.expandedTopEdgeInset
        let usageHeight = showsUsage ? Metric.expandedUsageHeight : 0
        let activityRows = max(1, min(Metric.maximumActivityRows, activityCount))
        let activityHeight =
            CGFloat(activityRows) * Metric.activityRowHeight
            + Metric.activityVerticalPadding
        let agentHeight = agentCount > 0
            ? Metric.agentStripHeight + Metric.agentStripBottomSpacing
            : 0
        let workspaceHeight = sessionCount > 1
            ? Metric.multiSessionHeight
            : activityHeight + agentHeight
        let actionHeight = hasQuestion
            ? Metric.permissionActionHeight
            : Metric.standardActionHeight
        return CGSize(
            width: min(preferredWidth, maximumWidth),
            height:
                topInset
                + Metric.expandedHeaderHeight
                + usageHeight
                + workspaceHeight
                + actionHeight
                + Metric.expandedBottomInset
        )
    }
}
