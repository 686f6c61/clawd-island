import CoreGraphics

enum IslandPanelLayout {
    static func manuallyHiddenSize(
        hasHardwareNotch: Bool,
        notchWidth: CGFloat,
        notchHeight: CGFloat
    ) -> CGSize {
        CGSize(
            width: hasHardwareNotch ? max(notchWidth + 48, 208) : 180,
            height: hasHardwareNotch ? max(notchHeight + 10, 40) : 18
        )
    }

    static func dormantSize(
        hasHardwareNotch: Bool,
        notchWidth: CGFloat,
        notchHeight: CGFloat
    ) -> CGSize {
        CGSize(
            width: hasHardwareNotch ? notchWidth + 84 : 84,
            height: hasHardwareNotch ? max(52, notchHeight + 16) : 44
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
                width: max(notchWidth + wingWidth, style == .minimal ? 340 : 440),
                height: max(58, notchHeight + 20)
            )
        }
        return CGSize(width: style == .minimal ? 176 : 320, height: 58)
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
        let topInset = hasHardwareNotch ? max(72, notchHeight + 46) : 44
        let headerHeight: CGFloat = 47
        let usageHeight: CGFloat = showsUsage ? 46 : 0
        let rows = max(1, min(3, activityCount))
        let activityHeight = CGFloat(rows * 28 + 14)
        let workspaceHeight = sessionCount > 1 ? 158 : activityHeight + (agentCount > 0 ? 23 : 0)
        let actionHeight: CGFloat = hasQuestion ? 92 : 56
        let bottomInset: CGFloat = 14
        return CGSize(
            width: min(preferredWidth, maximumWidth),
            height: topInset + headerHeight + usageHeight + workspaceHeight + actionHeight + bottomInset
        )
    }
}
