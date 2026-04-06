import Foundation

public final class ConfigStore {
    public init() {}

    public func load() throws -> CronlyConfig {
        let fm = FileManager.default
        let path = CronlyPaths.configFile

        guard fm.fileExists(atPath: path.path) else {
            return CronlyConfig()
        }

        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(CronlyConfig.self, from: data)
    }

    public func save(_ config: CronlyConfig) throws {
        try CronlyPaths.ensureDirectories()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: CronlyPaths.configFile, options: .atomic)
    }

    public func addTask(_ task: TaskConfig) throws {
        var config = try load()
        if config.tasks.contains(where: { $0.name == task.name }) {
            throw CronlyError.taskAlreadyExists(task.name)
        }
        config.tasks.append(task)
        try save(config)
    }

    public func removeTask(name: String) throws {
        var config = try load()
        guard config.tasks.contains(where: { $0.name == name }) else {
            throw CronlyError.taskNotFound(name)
        }
        config.tasks.removeAll { $0.name == name }
        try save(config)
    }

    public func updateTask(name: String, update: (inout TaskConfig) -> Void) throws {
        var config = try load()
        guard let index = config.tasks.firstIndex(where: { $0.name == name }) else {
            throw CronlyError.taskNotFound(name)
        }
        update(&config.tasks[index])
        try save(config)
    }

    public func getTask(name: String) throws -> TaskConfig {
        let config = try load()
        guard let task = config.tasks.first(where: { $0.name == name }) else {
            throw CronlyError.taskNotFound(name)
        }
        return task
    }
}
