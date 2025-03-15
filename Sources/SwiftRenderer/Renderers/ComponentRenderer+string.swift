import OpenAPIKit30
import SwiftSyntax
import SwiftSyntaxBuilder

struct StringRenderer: ComponentRenderer {
    var schema: JSONSchema
    var coreContext: JSONSchema.CoreContext<JSONTypeFormat.StringFormat>
    var stringContext: JSONSchema.StringContext

    init?(schema: JSONSchema) {
        guard case .string(let coreContext, let stringContext) = schema.value else {
            return nil
        }
        self.schema = schema
        self.coreContext = coreContext
        self.stringContext = stringContext
    }

    func render(key: OpenAPI.ComponentKey, context: inout Context) throws -> RenderResult? {
        switch coreContext.format {
        case .byte, .binary:
            return (schema.identifier(reserved: "Data"), "")

        case .date, .dateTime:
            return (schema.identifier(reserved: "Date"), "")

        case .other("uri"):
            return (schema.identifier(reserved: "URL"), "")

        case .generic, .password:
            return (schema.identifier(reserved: "String"), "")

        case .other("email"):
            return (schema.identifier(reserved: "String"), "")

        case .other:
            return (schema.identifier(reserved: "String"), "")
        }
    }
}
