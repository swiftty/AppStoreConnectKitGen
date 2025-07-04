import Foundation
import AppStoreConnectGenKit

struct EndpointNamespaceRenderer: Renderer {
    var filePath: String { "Endpoints/Namespace.swift" }
    var components: [[String]]

    init(endpoints: OpenAPIEndpoints) {
        components = endpoints.filter(\.value.hasMethod).keys.map(makePathComponents)
    }

    func render() throws -> String? {
        let root = Tree(value: "root")
        var current = root

        for comps in components {
            let root = current
            for c in comps {
                current = current.child(c)
            }
            current = root
        }

        func visit(_ tree: Tree) -> Decl {
            EnumDecl(access: .public, name: tree.value, cases: [],
                     nested: tree.children.sorted().map(visit))
        }

        return """
        // autogenerated

        // swiftlint:disable all
        import Foundation

        \(root.children.sorted().map {
            SourceFile(decl: visit($0)).render()
        }.joined(separator: "\n"))

        // swiftlint:enable all

        """.cleaned()
    }
}

// MARK: - private
private class Tree: Hashable, Comparable {
    var value: String
    var children: Set<Tree>

    init(value: String) {
        self.value = value
        self.children = []
    }

    func child(_ value: String) -> Tree {
        for child in children where child.value == value {
            return child
        }
        return child(Tree(value: value))
    }

    func child(_ child: Tree) -> Tree {
        children.insert(child)
        return child
    }

    static func == (lhs: Tree, rhs: Tree) -> Bool {
        return lhs.value == rhs.value
        && lhs.children == rhs.children
    }

    static func < (lhs: Tree, rhs: Tree) -> Bool {
        lhs.value < rhs.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
        hasher.combine(children)
    }
}
