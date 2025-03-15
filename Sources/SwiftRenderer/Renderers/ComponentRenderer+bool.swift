import OpenAPIKit30
import SwiftSyntax
import SwiftSyntaxBuilder

struct BoolRenderer: ComponentRenderer {
    var schema: JSONSchema

    init?(schema: JSONSchema) {
        guard schema.isBoolean else {
            return nil
        }
        self.schema = schema
    }

    func render(key: OpenAPI.ComponentKey, context: inout Context) throws -> RenderResult? {
        return (schema.identifier(reserved: "Bool"), "")
    }
}
