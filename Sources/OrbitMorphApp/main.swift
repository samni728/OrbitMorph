import AppKit

let instanceController = SingleInstanceController()
if !LaunchInstancePolicy.isExempt(arguments: CommandLine.arguments) {
    switch instanceController.claim() {
    case .launch:
        break
    case .activateExisting(let pid):
        _ = NSRunningApplication(processIdentifier: pid)?.activate(options: [.activateAllWindows])
        exit(0)
    case .alreadyLaunching:
        exit(0)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
