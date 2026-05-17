import Foundation
import UIKit

/// Routes URL-scheme deep links + home-screen quick-action shortcuts into
/// app state. Called from `TimebaseApp.onOpenURL` and the
/// `UIWindowScene.shortcutItem` handler.
@MainActor
enum DeepLinkRouter {
    static func handle(url: URL, store: TimebaseStore) {
        guard url.scheme == "timebase" else { return }
        let host = url.host ?? ""
        switch host {
        case "scheduler":
            store.goTo(tab: .upNextAbout)
            store.pendingShowScheduler = true
        case "upnext":
            store.goTo(tab: .upNextAbout)
        case "settings":
            store.goTo(tab: .settings)
        case "city":
            // Future: deep link to a specific city's detail sheet
            store.goTo(tab: .clock)
        case "greeting":
            store.greeting = Greeting.currentGreeting()
        default:
            break
        }
    }

    /// Called when iOS hands us a `UIApplicationShortcutItem` (long-press
    /// the icon → pick an action).
    static func handle(shortcut: UIApplicationShortcutItem, store: TimebaseStore) {
        switch shortcut.type {
        case "cc.timebase.shortcut.scheduler":
            store.goTo(tab: .upNextAbout)
            store.pendingShowScheduler = true
        case "cc.timebase.shortcut.upnext":
            store.goTo(tab: .upNextAbout)
        case "cc.timebase.shortcut.settings":
            store.goTo(tab: .settings)
        case "cc.timebase.shortcut.easter":
            store.greeting = Greeting.currentGreeting()
        default:
            break
        }
    }
}

/// Dynamic easter-egg quick action — different greeting at different times
/// of day. Updated on app foreground.
@MainActor
enum Greeting {
    static func currentGreeting() -> String {
        let h = Calendar.current.component(.hour, from: .now)
        switch h {
        case 5..<11:  return "Good morning ☕"
        case 11..<14: return "What time is it in your favourite city?"
        case 14..<18: return "Golden hour, somewhere 🌇"
        case 18..<22: return "Don't schedule late, plan early"
        default:      return "Asleep somewhere, working somewhere 🌙"
        }
    }

    static func updateDynamicShortcut() {
        let item = UIApplicationShortcutItem(
            type: "cc.timebase.shortcut.easter",
            localizedTitle: currentGreeting(),
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(type: .time),
            userInfo: nil
        )
        UIApplication.shared.shortcutItems = (UIApplication.shared.shortcutItems ?? [])
            .filter { $0.type != "cc.timebase.shortcut.easter" } + [item]
    }
}
