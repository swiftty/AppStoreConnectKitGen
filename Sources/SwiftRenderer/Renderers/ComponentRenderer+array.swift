import OpenAPIKit30
import SwiftSyntax
import SwiftSyntaxBuilder

struct ArrayRenderer: ComponentRenderer {
    var accessLevel: AccessLevel = .public
    var schema: JSONSchema
    var arrayContext: JSONSchema.ArrayContext

    init?(schema: JSONSchema) {
        guard let arrayContext = schema.arrayContext else { return nil }
        self.schema = schema
        self.arrayContext = arrayContext
    }

    func render(key: String, context: inout Context) throws -> RenderResult? {
        let typeName = schema.identifier(as: key)
        context.nesting.append(typeName)
        defer { context.nesting.removeLast() }

        guard let items = arrayContext.items,
              let renderer = context.schemaRenderer(for: items),
              let (itemType, itemContent) = try renderer.render(key: key, context: &context) else {
            return nil
        }

        return (TypeIdentifierName(reserved: "[\(itemType.description)]"), itemContent)
    }
}
