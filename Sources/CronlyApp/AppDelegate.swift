import AppKit
import CronlyKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var configWatcher: DispatchSourceFileSystemObject?
    private var completionWatcher: DispatchSourceFileSystemObject?
    private let store = ConfigStore()
    private let launchd = LaunchdManager()
    private let logReader = LogReader()
    private let windowController = CronlyWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clock.badge.checkmark", accessibilityDescription: "Cronly")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
        }

        rebuildMenu()
        watchConfigFile()
        watchCompletionFile()
        reinstallTasksIfNeeded()
    }

    // Rebuild menu every time it opens so running state is fresh
    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Header
        let headerItem = NSMenuItem(title: "Cronly", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 13)
        ]
        headerItem.attributedTitle = NSAttributedString(string: "Cronly", attributes: headerAttributes)
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())

        // Tasks
        do {
            let config = try store.load()

            if config.tasks.isEmpty {
                let emptyItem = NSMenuItem(title: "No tasks configured", action: nil, keyEquivalent: "")
                emptyItem.isEnabled = false
                menu.addItem(emptyItem)

                let hintItem = NSMenuItem(title: "Use 'cronly add' to create one", action: nil, keyEquivalent: "")
                hintItem.isEnabled = false
                let hintAttributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
                hintItem.attributedTitle = NSAttributedString(string: "Use 'cronly add' to create one", attributes: hintAttributes)
                menu.addItem(hintItem)
            } else {
                for task in config.tasks {
                    addTaskItem(menu: menu, task: task)
                }
            }
        } catch {
            let errorItem = NSMenuItem(title: "Error loading config", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Manage
        let manageItem = NSMenuItem(title: "Manage...", action: #selector(openManageWindow), keyEquivalent: ",")
        manageItem.target = self
        menu.addItem(manageItem)

        // Quit
        let quitItem = NSMenuItem(title: "Quit Cronly", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.delegate = self
        statusItem.menu = menu
    }

    private func addTaskItem(menu: NSMenu, task: TaskConfig) {
        let running = logReader.isRunning(taskName: task.name)

        let titleItem = NSMenuItem(title: task.name, action: nil, keyEquivalent: "")
        titleItem.isEnabled = false

        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13)
        ]
        titleItem.attributedTitle = NSAttributedString(string: task.name, attributes: nameAttributes)
        menu.addItem(titleItem)

        // Schedule
        let schedule = CronParser.describe(task.cronExpression)
        let scheduleItem = NSMenuItem(title: "    \(schedule)", action: nil, keyEquivalent: "")
        scheduleItem.isEnabled = false
        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        scheduleItem.attributedTitle = NSAttributedString(string: "     \(schedule)", attributes: detailAttributes)
        menu.addItem(scheduleItem)

        // Running indicator
        if running {
            let runningItem = NSMenuItem(title: "    Running...", action: nil, keyEquivalent: "")
            runningItem.isEnabled = false
            let runningAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.systemBlue
            ]
            runningItem.attributedTitle = NSAttributedString(string: "     Running...", attributes: runningAttributes)
            menu.addItem(runningItem)
        }

        // Last run
        if let lastRun = logReader.lastRunTime(taskName: task.name) {
            let lastRunItem = NSMenuItem(title: "    Last: \(lastRun)", action: nil, keyEquivalent: "")
            lastRunItem.isEnabled = false
            lastRunItem.attributedTitle = NSAttributedString(string: "     Last: \(formatDate(lastRun))", attributes: detailAttributes)
            menu.addItem(lastRunItem)
        }

        // Run Now (disabled while already running)
        let runItem = NSMenuItem(title: "     Run Now", action: running ? nil : #selector(runTask(_:)), keyEquivalent: "")
        runItem.target = self
        runItem.representedObject = task.name
        let actionAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: running ? NSColor.tertiaryLabelColor : NSColor.controlAccentColor
        ]
        runItem.attributedTitle = NSAttributedString(string: "     Run Now", attributes: actionAttributes)
        runItem.isEnabled = !running
        menu.addItem(runItem)

        // Enable/disable toggle
        let toggleTitle = task.enabled ? "Disable" : "Enable"
        let toggleItem = NSMenuItem(title: "     \(toggleTitle)", action: #selector(toggleTask(_:)), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.representedObject = task.name
        let toggleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.controlAccentColor
        ]
        toggleItem.attributedTitle = NSAttributedString(string: "     \(toggleTitle)", attributes: toggleAttributes)
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())
    }

    @objc private func runTask(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        let scriptPath = CronlyPaths.logsDir.appendingPathComponent(name).appendingPathComponent("run.sh").path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath]
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.rebuildMenu() }
        }

        do {
            try process.run()
        } catch {
            // Script missing or not executable
        }
    }

    @objc private func toggleTask(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }

        do {
            let task = try store.getTask(name: name)
            if task.enabled {
                try store.updateTask(name: name) { $0.enabled = false }
                try launchd.unload(name: name)
            } else {
                try store.updateTask(name: name) { $0.enabled = true }
                let updated = try store.getTask(name: name)
                try launchd.install(task: updated)
            }
            rebuildMenu()
        } catch {
            // Silently fail — menu will show stale state until next refresh
        }
    }

    @objc private func openManageWindow() {
        windowController.showWindow()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            let display = DateFormatter()
            display.dateFormat = "MMM d, h:mm a"
            return display.string(from: date)
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            let display = DateFormatter()
            display.dateFormat = "MMM d, h:mm a"
            return display.string(from: date)
        }

        return isoString
    }

    // MARK: - Task Migration

    private func reinstallTasksIfNeeded() {
        guard let config = try? store.load() else { return }
        // Only reinstall if run.sh scripts don't have the completion sentinel yet
        guard let firstEnabled = config.tasks.first(where: { $0.enabled }) else { return }
        let runScript = CronlyPaths.taskLogsDir(name: firstEnabled.name).appendingPathComponent("run.sh")
        guard let contents = try? String(contentsOf: runScript, encoding: .utf8),
              !contents.contains("last_completed") else { return }
        for task in config.tasks where task.enabled {
            try? launchd.install(task: task)
        }
    }

    // MARK: - Completion File Watching

    private func watchCompletionFile() {
        let path = CronlyPaths.lastCompletedFile.path
        let fm = FileManager.default

        if !fm.fileExists(atPath: path) {
            fm.createFile(atPath: path, contents: nil)
        }

        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            NotificationCenter.default.post(name: .cronlyJobCompleted, object: nil)
            self.rebuildMenu()

            let flags = source.data
            if flags.contains(.delete) || flags.contains(.rename) {
                source.cancel()
                self.completionWatcher = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.watchCompletionFile()
                }
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        completionWatcher = source
    }

    // MARK: - Config File Watching

    private func watchConfigFile() {
        let path = CronlyPaths.configFile.path
        let fm = FileManager.default

        // Ensure config dir exists
        try? CronlyPaths.ensureDirectories()

        // Create the file if it doesn't exist so we can watch it
        if !fm.fileExists(atPath: path) {
            fm.createFile(atPath: path, contents: "{}".data(using: .utf8))
        }

        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            self.rebuildMenu()

            // If config was deleted or renamed, re-establish the watcher
            let flags = source.data
            if flags.contains(.delete) || flags.contains(.rename) {
                source.cancel()
                self.configWatcher = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.watchConfigFile()
                }
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        configWatcher = source
    }
}
