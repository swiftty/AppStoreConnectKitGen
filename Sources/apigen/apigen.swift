import Foundation
import System
import ArgumentParser
import AppStoreConnectKitGen
import SwiftRenderer

@main
struct GenCommand: AsyncParsableCommand {
    struct Options: ParsableArguments {
        @Argument(
            help: "The path to OpenAPI spec file.",
            transform: { FilePath($0) }
        )
        var specPath: FilePath

        @Option(
            name: .shortAndLong,
            help: "The path to output directory.",
            transform: { FilePath($0) }
        )
        var outputPath: FilePath
    }

    @OptionGroup var options: Options

    func run() async throws {
        let runner = GenRunner(options: options)
        try runner.validate()
        try await runner.run()
    }
}

private struct GenRunner {
    var options: GenCommand.Options
    var fileManager = FileManager.default

    func run() async throws {
        let data = try Data(contentsOf: URL(filePath: options.specPath)!)

        let gen = try AppStoreConnectKitGen(spec: .json(data), renderer: SwiftRenderer.self)
        try await gen.generate(output: options.outputPath)
    }

    func validate() throws {
        let isExists = fileManager.fileExists(atPath: options.specPath.string)
        guard isExists else {
            throw ValidationError("missing OpenAPI spec file")
        }
    }
}
