import ArgumentParser
import CronlyKit

@main
struct Cronly: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cronly",
        abstract: "Manage scheduled tasks via launchd",
        subcommands: [
            Add.self,
            List.self,
            Remove.self,
            EditCommand.self,
            Enable.self,
            Disable.self,
            Logs.self,
            Status.self,
        ]
    )
}
