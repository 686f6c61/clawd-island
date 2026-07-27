import CoreGraphics

enum IslandPanelLayout {
    private static let topInsetHardware: CGFloat = 72
    private static let topInsetSoftware: CGFloat = 44
    private static let headerHeight: CGFloat = 47
    private static let usageHeight: CGFloat = 46
    private static let rowHeight: CGFloat = 28
    private static let activityPadding: CGFloat = 14
    private static let agentHeight: CGFloat = 23
    private static let agentBottomPadding: CGFloat = 7
    private static let actionHeightPermission: CGFloat = 92
    private static let actionHeightDefault: CGFloat = 56
    private static let bottomInset: CGFloat = 14
    private static let maxActivityRows = 3
    private static let multiSessionHeight: CGFloat = 158
    private static let dormantNotchExtra: CGFloat = 84
    private static let dormantMinWidth: CGFloat = 84
    private static let dormantMinHeightHardware: CGFloat = 52
    private static let dormantMinHeightSoftware: CGFloat = 44
    private static let dormantNotchVerticalExtra: CGFloat = 16
    private static let compactMinWidthMinimal: CGFloat = 340
    private static let compactMinWidthInformative: CGFloat = 440
    private static let compactWidthMinimal: CGFloat = 176
    private static let compactWidthInformative: CGFloat = 320
    private static let compactHeight: CGFloat = 58
    private static let compactNotchVerticalExtra: CGFloat = 20
    private static let hiddenMinWidth: CGFloat = 180
    private static let hiddenMinHeightHardware: CGFloat = 40
    private static let hiddenNotchHorizontalExtra: CGFloat = 48
    private static let hiddenNotchVerticalExtra: CGFloat = 10

    static func manuallyHiddenSize(
        hasHardwareNotch: Bool,
        notchWidth: CGFloat,
        notchHeight: CGFloat
    ) -> CGSize {
        CGSize(
            width: hasHardwareNotch ? max(notchWidth + hiddenNotchHorizontalExtra, 208) : hiddenMinWidth,
            height: hasHardwareNotch ? max(notchHeight + hiddenNotchVerticalExtra, hiddenMinHeightHardware) : 18
        )
    }

    static func dormantSize(
        hasHardwareNotch: Bool,
        notchWidth: CGFloat,
        notchHeight: CGFloat
    ) -> CGSize {
        CGSize(
            width: hasHardwareNotch ? notchWidth + dormantNotchExtra : dormantMinWidth,
            height: hasHardwareNotch ? max(dormantMinHeightHardware, notchHeight + dormantNotchVerticalExtra) : dormantMinHeightSoftware
        )
    }

    static func compactSize(
        hasHardwareNotch: Bool,
        notchWidth: CGFloat,
        notchHeight: CGFloat,
        style: CompactIslandStyle
    ) -> CGSize {
        if hasHardwareNotch {
            let wingWidth: CGFloat = style == .minimal ? 122 : 250
            return CGSize(
                width: max(notchWidth + wingWidth, style == .minimal ? compactMinWidthMinimal : compactMinWidthInformative),
                height: max(compactHeight, notchHeight + compactNotchVerticalExtra)
            )
        }
        return CGSize(width: style == .minimal ? compactWidthMinimal : compactWidthInformative, height: compactHeight)
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
        let topInset = hasHardwareNotch ? max(topInsetHardware, notchHeight + 46) : topInsetSoftware
        let usageH = showsUsage ? usageHeight : 0
        let rows = max(1, min(maxActivityRows, activityCount))
        let activityH = CGFloat(rows * Int(rowHeight) + Int(activityPadding))
        let agentH: CGFloat = agentCount > 0 ? agentHeight + agentBottomPadding : 0
        let workspaceH = sessionCount > 1 ? multiSessionHeight : activityH + agentH
        let actionH: CGFloat = hasQuestion ? actionHeightPermission : actionHeightDefault
        return CGSize(
            width: min(preferredWidth, maximumWidth),
            height: topInset + headerHeight + usageH + workspaceH + actionH + bottomInset
        )
    }
}
