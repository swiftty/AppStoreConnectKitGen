import OpenAPIKit30
import SwiftSyntax
import SwiftSyntaxBuilder

struct RefRenderer: ComponentRenderer {
    var accessLevel: AccessLevel = .public
    var schema: JSONSchema
    var ref: JSONReference<JSONSchema>

    init?(schema: JSONSchema) {
        guard case .reference(let ref, _) = schema.value else { return nil }
        self.schema = schema
        self.ref = ref
    }

    func render(key: OpenAPI.ComponentKey, context: inout Context) throws -> RenderResult? {
        guard let name = ref.name.map(TypeIdentifierName.init) else { return nil }
        return (name.description, "")
    }
}
