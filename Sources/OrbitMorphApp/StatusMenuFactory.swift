import AppKit

@MainActor
enum StatusMenuFactory {
    static func makeMenu(state: AppState, target: NSObject) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: state.L("OrbitMorph · Drop. Spin. Convert."), action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        for (title, action, key) in [("Reveal Last Outputs", "revealOutputs", ""), ("Settings…", "showSettings", ","), ("About OrbitMorph", "showAbout", "")] {
            let item = NSMenuItem(title: state.L(title), action: NSSelectorFromString(action), keyEquivalent: key)
            item.target = target; menu.addItem(item)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: state.L("Quit OrbitMorph"), action: NSSelectorFromString("quit"), keyEquivalent: "q")
        quit.target = target; menu.addItem(quit)
        return menu
    }
}
