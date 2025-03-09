public import AppStoreConnectKitGen
import Foundation

public struct SwiftRenderer: Renderer {
    var document: OpenAPI.Document

    public init(document: OpenAPI.Document) {
        self.document = document
    }

    public func render() async throws -> [FilePath: String] {
        var files: [FilePath: String] = [:]
        let context = Context(
            schemaRenderers: [
                StructRenderer.init,
                EnumRenderer.init
            ]
        )

        let schemaPath = FilePath("schemas")
        for (key, schema) in document.components.schemas {
            var context = context
            if let (type, content) = try SchemaRenderer(schema: schema).render(key: key, context: &context) {
                let file = FilePath("\(type).swift")
                files[schemaPath.appending(file.components)] = content
            }
        }

        return files
    }
}
