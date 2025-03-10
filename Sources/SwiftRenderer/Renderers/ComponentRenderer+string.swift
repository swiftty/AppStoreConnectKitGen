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
            return ("Data", "")

        case .date, .dateTime:
            return ("Date", "")

        case .other("uri"):
            return ("URL", "")

        case .generic, .password:
            return ("String", "")

        case .other("email"):
            return ("String", "")

        case .other:
            return ("String", "")
        }
    }
}
