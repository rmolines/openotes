import Foundation
import AppKit
import CoreGraphics

// MARK: - Meeting Detector

/// Polls every 3 seconds for active meetings via NSWorkspace (native apps)
/// and osascript (Google Meet in browsers).
class MeetingDetector {
    private let meetingBundleIDs: [String: String] = [
        "us.zoom.xos": "Zoom",
        "com.microsoft.teams2": "MicrosoftTeams",
        "com.apple.FaceTime": "FaceTime",
        "com.cisco.webexmeetingsapp": "Webex"
    ]

    /// Apps where process running ≠ in meeting. Need window title heuristics.
    private let windowTitleApps: [String: (bundleID: String, keyword: String)] = [
        "Slack": (bundleID: "com.tinyspeck.slackmacgap", keyword: "Huddle")
    ]

    private let browserBundleIDs: [String] = [
        "com.google.Chrome",
        "com.apple.Safari",
        "company.thebrowser.Browser",
        "com.microsoft.edgemac"
    ]

    // Returns (detected, sourceName). sourceName is empty when detected=false.
    func detect() -> (detected: Bool, source: String) {
        let running = NSWorkspace.shared.runningApplications

        // Primary: check native video-conference apps
        for app in running {
            guard let bid = app.bundleIdentifier else { continue }
            if let name = meetingBundleIDs[bid] {
                return (true, name)
            }
        }

        // Secondary: check window titles for apps that need heuristics (e.g. Slack huddle)
        let runningBundleIDs = Set(running.compactMap { $0.bundleIdentifier })
        for (name, config) in windowTitleApps {
            guard runningBundleIDs.contains(config.bundleID) else { continue }
            if checkWindowTitle(bundleID: config.bundleID, keyword: config.keyword) {
                return (true, name)
            }
        }

        // Tertiary: check browser tabs for meet.google.com
        for browserID in browserBundleIDs {
            guard runningBundleIDs.contains(browserID) else { continue }
            if checkBrowserForMeet(bundleID: browserID) {
                return (true, "GoogleMeet")
            }
        }

        return (false, "")
    }

    /// Checks if an app has a window whose title contains the given keyword.
    /// Uses CGWindowList (no Accessibility permission needed).
    private func checkWindowTitle(bundleID: String, keyword: String) -> Bool {
        // Find PID for the bundle ID
        let apps = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == bundleID }
        guard let app = apps.first else { return false }

        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID == app.processIdentifier,
                  let windowName = window[kCGWindowName as String] as? String else {
                continue
            }
            if windowName.contains(keyword) {
                return true
            }
        }
        return false
    }

    /// Runs osascript to check if the given browser has a meet.google.com tab open.
    /// Returns true if found. Errors are suppressed (not finding a tab is not an error).
    private func checkBrowserForMeet(bundleID: String) -> Bool {
        let script: String
        if bundleID == "com.apple.Safari" {
            script = """
            tell application id "\(bundleID)"
                repeat with w in windows
                    try
                        if URL of current tab of w contains "meet.google.com" then return "FOUND"
                    end try
                end repeat
            end tell
            """
        } else {
            // Chrome, Arc, Edge — all share the same AppleScript interface
            script = """
            tell application id "\(bundleID)"
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "meet.google.com" then return "FOUND"
                    end repeat
                end repeat
            end tell
            """
        }

        return runOsascript(script)
    }

    /// Executes an osascript and returns true if output contains "FOUND".
    private func runOsascript(_ script: String) -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()

        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.contains("FOUND")
        } catch {
            return false
        }
    }
}

// MARK: - State Machine

enum MeetingState {
    case idle
    case active
}

// MARK: - Main

let detector = MeetingDetector()
var state: MeetingState = .idle

// Polling timer — fires every 3 seconds on the main RunLoop
let timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
    let result = detector.detect()

    switch state {
    case .idle:
        if result.detected {
            state = .active
            print("MEETING_DETECTED:\(result.source)")
            fflush(stdout)
        }
    case .active:
        if !result.detected {
            state = .idle
            print("MEETING_ENDED")
            fflush(stdout)
        }
        // If still active (possibly different source), stay in active — no duplicate event
    }
}

// Add timer to RunLoop so it fires
RunLoop.main.add(timer, forMode: .common)

print("READY")
fflush(stdout)

// Install SIGTERM handler for graceful shutdown
let sigSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
signal(SIGTERM, SIG_IGN)  // tell the OS we're handling it ourselves
sigSource.setEventHandler {
    timer.invalidate()
    print("DONE")
    fflush(stdout)
    exit(0)
}
sigSource.resume()

// Run indefinitely — terminated by SIGTERM handler above.
RunLoop.main.run()
