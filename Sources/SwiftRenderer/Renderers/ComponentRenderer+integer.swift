import OpenAPIKit30
import SwiftSyntax
import SwiftSyntaxBuilder

struct IntegerRenderer: ComponentRenderer {
    var schema: JSONSchema
    var coreContext: JSONSchema.CoreContext<JSONTypeFormat.IntegerFormat>
    var integerContext: JSONSchema.IntegerContext

    init?(schema: JSONSchema) {
        guard case .integer(let coreContext, let integerContext) = schema.value else {
            return nil
        }
        self.schema = schema
        self.coreContext = coreContext
        self.integerContext = integerContext
    }

    func render(key: String, context: inout Context) throws -> RenderResult? {
        return (schema.identifier(reserved: "Int"), "")
    }
}
