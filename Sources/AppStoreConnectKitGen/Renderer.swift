import Foundation
@_exported public import System
@_exported public import OpenAPIKit30

public protocol Renderer {
    init(document: OpenAPI.Document)

    func render() async throws -> [FilePath: String]
}
