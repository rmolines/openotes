import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    private var daemonStatusSource: DispatchSourceFileSystemObject?
    private var daemonStatusFd: Int32 = -1

    private var dataDirURL: URL {
        if let envPath = ProcessInfo.processInfo.environment["OPENOTES_DATA_DIR"] {
            return URL(fileURLWithPath: envPath)
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return cwd.deletingLastPathComponent().appendingPathComponent("data")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Openotes")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())

        startWatchingDaemonStatus()
        updateMenuBarIcon()
    }

    func applicationWillTerminate(_ notification: Notification) {
        daemonStatusSource?.cancel()
        if daemonStatusFd >= 0 {
            close(daemonStatusFd)
        }
    }

    private func startWatchingDaemonStatus() {
        let statusFileURL = dataDirURL.appendingPathComponent(".daemon-status.json")
        let path = statusFileURL.path

        // Create file if it doesn't exist yet
        if !FileManager.default.fileExists(atPath: path) {
            try? Data(#"{"recording":false,"session":null,"started":null}"#.utf8)
                .write(to: statusFileURL)
        }

        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        daemonStatusFd = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.updateMenuBarIcon()
        }
        source.resume()
        daemonStatusSource = source
    }

    private func updateMenuBarIcon() {
        let statusFileURL = dataDirURL.appendingPathComponent(".daemon-status.json")
        guard let data = try? Data(contentsOf: statusFileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        let recording = json["recording"] as? Bool ?? false

        if recording {
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            let image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")?
                .withSymbolConfiguration(config)
            statusItem.button?.image = image
        } else {
            statusItem.button?.image = NSImage(
                systemSymbolName: "waveform",
                accessibilityDescription: "Openotes"
            )
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
}
