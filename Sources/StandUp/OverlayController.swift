import AppKit
import SwiftUI

/// 无边框全屏覆盖窗口，用来做「醒目提醒」。
/// 多显示器时每块屏都会盖一层，避免用户在副屏工作时看不见。
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class OverlayController {
    private var windows: [OverlayWindow] = []
    private unowned let state: AppState

    init(state: AppState) {
        self.state = state
    }

    var isPresenting: Bool { !windows.isEmpty }

    func present() {
        dismiss()

        let screens = NSScreen.screens.isEmpty ? [NSScreen.main].compactMap { $0 } : NSScreen.screens
        for screen in screens {
            let isPrimary = (screen == NSScreen.main) || screens.count == 1
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.level = .screenSaver
            window.isReleasedWhenClosed = false
            window.ignoresMouseEvents = false
            window.animationBehavior = .none
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

            let root = OverlayView(isPrimary: isPrimary).environmentObject(state)
            let host = NSHostingView(rootView: root)
            host.frame = CGRect(origin: .zero, size: screen.frame.size)
            window.contentView = host
            window.setFrame(screen.frame, display: true)

            if isPrimary {
                window.makeKeyAndOrderFront(nil)
            } else {
                window.orderFrontRegardless()
            }
            windows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        for window in windows {
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }
        windows.removeAll()
    }
}
