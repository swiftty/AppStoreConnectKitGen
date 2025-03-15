import OpenAPIKit30
import SwiftSyntax
import SwiftSyntaxBuilder

struct NumberRenderer: ComponentRenderer {
    var schema: JSONSchema
    var coreContext: JSONSchema.CoreContext<JSONTypeFormat.NumberFormat>
    var numberContext: JSONSchema.NumericContext

    init?(schema: JSONSchema) {
        guard case .number(let coreContext, let numberContext) = schema.value else {
            return nil
        }
        self.schema = schema
        self.coreContext = coreContext
        self.numberContext = numberContext
    }

    func render(key: OpenAPI.ComponentKey, context: inout Context) throws -> RenderResult? {
        return (TypeIdentifierName(reserved: "Float"), "")
    }
}
