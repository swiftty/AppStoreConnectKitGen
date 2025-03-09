public import Foundation
public import System
import OpenAPIKit30

public struct AppStoreConnectKitGen {
    public protocol Writer {
        func mkdir(_ directory: FilePath, force: Bool) throws
        func write(_ content: String, to path: FilePath) throws
    }

    public enum Spec {
        case json(Data)
    }

    private var render: (_ output: FilePath) async throws -> Void

    public init(
        spec: Spec,
        renderer: (some Renderer).Type,
        writer: some Writer = DefaultWriter()
    ) throws {
        let document = try {
            switch spec {
            case .json(let data):
                let decoder = JSONDecoder()
                return try decoder.decode(OpenAPI.Document.self, from: data)
            }
        }()
        self.render = { output in
            try writer.mkdir(output, force: true)

            let renderer = renderer.init(document: document)
            let files = try await renderer.render()
            for (file, content) in files {
                let file = output.appending(file.components)
                try writer.mkdir(file.removingLastComponent())
                try writer.write(content, to: file)
            }
        }
    }

    public func generate(output: FilePath) async throws {
        try await render(output)
    }
}

extension AppStoreConnectKitGen.Writer {
    func mkdir(_ directory: FilePath) throws {
         try mkdir(directory, force: false)
    }
}
