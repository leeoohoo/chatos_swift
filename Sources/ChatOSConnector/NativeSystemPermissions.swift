import AppKit
import ApplicationServices
import ChatOSCore
import CoreGraphics
import Foundation

enum NativeSystemPermissions {
    static func snapshot() -> LocalConnectorSystemPermissions {
        .init(
            platform: "macos",
            platformLabel: "macOS",
            items: [
                permission(
                    id: "terminal",
                    label: "本机终端执行",
                    summary: "由 Swift 客户端直接启动受控的本机进程",
                    ready: true,
                    canRequest: false,
                    requestLabel: "无需授权",
                    note: "命令仍受工作区边界与审批策略约束。"
                ),
                permission(
                    id: "accessibility",
                    label: "辅助功能",
                    summary: "允许 Computer Use 控制本机应用",
                    ready: AXIsProcessTrusted(),
                    canRequest: true,
                    requestLabel: "请求辅助功能权限",
                    note: "由 macOS 系统设置控制。"
                ),
                permission(
                    id: "screen_recording",
                    label: "屏幕与系统音频录制",
                    summary: "允许 Computer Use 获取屏幕画面",
                    ready: CGPreflightScreenCaptureAccess(),
                    canRequest: true,
                    requestLabel: "请求屏幕录制权限",
                    note: "首次请求会显示 macOS 授权提示。"
                ),
                permission(
                    id: "full_disk_access",
                    label: "完全磁盘访问",
                    summary: "访问受 macOS 隐私保护的目录",
                    ready: false,
                    canRequest: true,
                    requestLabel: "打开系统设置",
                    note: "只有需要访问受保护目录时才应开启。"
                ),
            ]
        )
    }

    @MainActor
    static func request(_ id: String) {
        switch id {
        case "accessibility":
            let options = ["AXTrustedCheckOptionPrompt": true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
        case "screen_recording":
            CGRequestScreenCaptureAccess()
        case "full_disk_access":
            openPrivacySettings(anchor: "Privacy_AllFiles")
        default:
            break
        }
    }

    @MainActor
    private static func openPrivacySettings(anchor: String) {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private static func permission(
        id: String,
        label: String,
        summary: String,
        ready: Bool,
        canRequest: Bool,
        requestLabel: String,
        note: String
    ) -> LocalConnectorSystemPermission {
        .init(
            id: id,
            label: label,
            summary: summary,
            status: ready ? "ready" : "action_required",
            statusLabel: ready ? "已就绪" : "需要授权",
            required: false,
            canRequest: canRequest,
            requestLabel: requestLabel,
            note: note,
            lastError: nil
        )
    }
}
