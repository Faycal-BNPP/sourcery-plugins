import Foundation
import PackagePlugin

@main
struct Main: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        var commands = [Command]()
        try commands.append(contentsOf: self.commands(mockTarget: target, in: context))
        try commands.append(contentsOf: self.commands(testTarget: target, in: context))
        return commands
    }

    private func filePaths(in urlPath: String, suffix: String) throws -> String? {
        FileManager.default
            .enumerator(atPath: urlPath)?
            .allObjects
            .compactMap { $0 as? String }
            .first { $0.hasSuffix(suffix) }
    }

    private func commands(mockTarget: Target, in context: PluginContext) throws -> [Command] {
        guard mockTarget.name.contains("Mocks") else { return [] }
        let toolPath = try context.tool(named: "sourcery")
        let interfaceModule = mockTarget.name.replacingOccurrences(of: "Mocks", with: "Interface")
        let targets = mockTarget.recursiveTargetDependencies.map(\.name)
        let sourceryCommand = Command.prebuildCommand(
            displayName: "Sourcery mocks \(mockTarget.name)",
            executable: toolPath.path,
            arguments: [
                "--templates",
                toolPath.path.removingLastComponent().removingLastComponent().appending("Templates"),
                "--args",
                "imports=[\"UIKit\", \"Combine\", \(targets.map { "\"\($0)\"" }.joined(separator: ","))]",
                "--sources",
                context.package.directory.appending("Sources", interfaceModule),
                "--output",
                context.pluginWorkDirectory,
                "--disableCache",
                "--verbose"
            ],
            environment: [:],
            outputFilesDirectory: context.pluginWorkDirectory
        )
        return [sourceryCommand]
    }

    private func commands(testTarget: Target, in context: PluginContext) throws -> [Command] {
        guard testTarget.name.contains("Tests") else { return [] }
        let toolPath = try context.tool(named: "sourcery")
        let implementationModule = context.package.targets.first { $0.name == context.package.displayName }!
        let targets = implementationModule.recursiveTargetDependencies.map(\.name)
        let sourceryCommand = Command.prebuildCommand(
            displayName: "Sourcery mocks \(testTarget.name)",
            executable: toolPath.path,
            arguments: [
                "--templates",
                toolPath.path.removingLastComponent().removingLastComponent().appending("Templates"),
                "--args",
                "imports=[\"UIKit\", \"Combine\", \(targets.map { "\"\($0)\"" }.joined(separator: ","))],testableImports=[\"\(implementationModule.name)\"]",
                "--sources",
                context.package.directory.appending("Sources", implementationModule.name),
                "--output",
                context.pluginWorkDirectory,
                "--disableCache",
                "--verbose"
            ],
            environment: [:],
            outputFilesDirectory: context.pluginWorkDirectory
        )
        return [sourceryCommand]
    }
}
