import SwiftUI
import CronlyKit

// MARK: - Sidebar Row

struct TaskSidebarRow: View {
    let task: TaskConfig
    let running: Bool
    let selected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Text(CronParser.describe(task.cronExpression))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(selected ? Color.accentColor.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }

    private var dotColor: Color {
        if running { return .blue }
        if !task.enabled { return .gray.opacity(0.4) }
        return .green
    }
}

// MARK: - Detail View

struct TaskDetailView: View {
    let task: TaskConfig
    let lastRun: String?
    let running: Bool
    let onRun: () -> Void
    let onOpenPrompt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text(task.name)
                .font(.system(size: 20, weight: .semibold))
                .padding(.bottom, 16)

            // Info rows
            DetailRow(label: "Schedule", value: CronParser.describe(task.cronExpression))
            DetailRow(label: "Cron", value: task.cronExpression)
            DetailRow(label: "Status", value: task.enabled ? "Enabled" : "Disabled")

            if running {
                DetailRow(label: "State", value: "Running...", valueColor: .blue)
            } else if let lastRun {
                DetailRow(label: "Last Run", value: formatDate(lastRun))
            } else {
                DetailRow(label: "Last Run", value: "Never", valueColor: .secondary)
            }

            Spacer()

            // Actions
            HStack(spacing: 10) {
                Button(action: onOpenPrompt) {
                    Label("Open Prompt", systemImage: "doc.text")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button(action: onRun) {
                    Label(running ? "Running..." : "Run Now", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(running)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)

            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Main View

struct CronlyContentView: View {
    @State private var tasks: [TaskConfig] = []
    @State private var selectedTaskName: String?
    @State private var runningTasks: Set<String> = []
    @State private var lastRuns: [String: String] = [:]

    private let store = ConfigStore()
    private let logReader = LogReader()
    private let promptManager = PromptManager()

    private var selectedTask: TaskConfig? {
        tasks.first { $0.name == selectedTaskName }
    }

    var body: some View {
        HSplitView {
            // Sidebar
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(tasks) { task in
                        TaskSidebarRow(
                            task: task,
                            running: runningTasks.contains(task.name),
                            selected: selectedTaskName == task.name
                        )
                        .onTapGesture { selectedTaskName = task.name }
                    }
                }
                .padding(8)
            }
            .frame(width: 200)
            .background(Color(nsColor: .controlBackgroundColor))

            // Detail
            if let task = selectedTask {
                TaskDetailView(
                    task: task,
                    lastRun: lastRuns[task.name],
                    running: runningTasks.contains(task.name),
                    onRun: { runTask(task) },
                    onOpenPrompt: { openPrompt(task) }
                )
            } else {
                VStack {
                    Text("Select a task")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .cronlyJobCompleted)) { _ in
            refresh()
        }
    }

    private func refresh() {
        do {
            let config = try store.load()
            tasks = config.tasks
            var currentlyRunning: Set<String> = []
            for task in config.tasks {
                if logReader.isRunning(taskName: task.name) {
                    currentlyRunning.insert(task.name)
                }
                lastRuns[task.name] = logReader.lastRunTime(taskName: task.name)
            }
            runningTasks = currentlyRunning
            if selectedTaskName == nil {
                selectedTaskName = tasks.first?.name
            }
        } catch {}
    }

    private func runTask(_ task: TaskConfig) {
        let scriptPath = CronlyPaths.taskLogsDir(name: task.name)
            .appendingPathComponent("run.sh").path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath]
        process.terminationHandler = { _ in
            DispatchQueue.main.async {
                runningTasks.remove(task.name)
                lastRuns[task.name] = logReader.lastRunTime(taskName: task.name)
            }
        }

        do {
            runningTasks.insert(task.name)
            try process.run()
        } catch {
            runningTasks.remove(task.name)
        }
    }

    private func openPrompt(_ task: TaskConfig) {
        do {
            let url = try promptManager.promptFileURL(for: task)
            NSWorkspace.shared.open(url)
        } catch {}
    }
}

// MARK: - Date Formatting

func formatDate(_ iso: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: iso) {
        let display = DateFormatter()
        display.dateFormat = "MMM d, h:mm a"
        return display.string(from: date)
    }
    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: iso) {
        let display = DateFormatter()
        display.dateFormat = "MMM d, h:mm a"
        return display.string(from: date)
    }
    return iso
}

// MARK: - Window Controller

final class CronlyWindowController {
    private var window: NSWindow?

    func showWindow() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = CronlyContentView()
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 520, height: 320)

        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Cronly"
        window.contentView = hostingView
        window.minSize = NSSize(width: 440, height: 260)
        window.center()
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
