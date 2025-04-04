import Foundation
import AppStoreConnectKitGen
import System

struct Context {
    var extensions: [String]
    var nesting: [TypeIdentifierName]
    var requiresPublicImport: Bool = false

    private var schemaRenderers: [(JSONSchema) -> (any ComponentRenderer)?]

    init(schemaRenderers: [(JSONSchema) -> (any ComponentRenderer)?]) {
        self.schemaRenderers = schemaRenderers
        self.extensions = []
        self.nesting = []
    }

    func schemaRenderer(for schema: JSONSchema) -> (any ComponentRenderer)? {
        for renderer in schemaRenderers {
            if let renderer = renderer(schema) {
                return renderer
            }
        }
        assertionFailure("renderer not found for \(schema)")
        return nil
    }
}
