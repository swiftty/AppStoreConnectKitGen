import Foundation
@preconcurrency import OpenAPIKit30

public typealias OpenAPISchemas = [String: OpenAPISchema]

public struct OpenAPISchema: Decodable {
    public var title: String?
    public var description: String?
    public var value: Property
    public var deprecated: Bool

    public init(_ schema: JSONSchema) {
        title = schema.title
        description = schema.description
        value = Property(from: schema.value)
        deprecated = !schema.required
    }

    public init(from decoder: any Decoder) throws {
        let schema = try JSONSchema(from: decoder)
        self.init(schema)
    }

    public func withDescription(_ description: String?) -> OpenAPISchema {
        var copy = self
        copy.description = description
        return copy
    }
}

extension OpenAPISchema {
    public indirect enum Property {
        case ref(Ref)
        case object(properties: [String: OpenAPISchema], required: Set<String>)
        case array(OpenAPISchema)
        case `enum`(Set<String>)
        case string(format: StringFormat?)
        case integer
        case number
        case boolean
        case anyKey(OpenAPISchema)
        case oneOf([OpenAPISchema])
        case undefined

        public enum StringFormat: String {
            case email
            case uri
            case uriReference = "uri-reference"
            case date
            case dateTime = "date-time"
            case number
            case duration
            case binary
        }

        // swiftlint:disable:next cyclomatic_complexity
        public init(from schema: JSONSchema.Schema) {
            switch schema {
            case .boolean:
                self = .boolean

            case .number:
                self = .number

            case .integer:
                self = .integer

            case .string(let core, _):
                self = .string(format: core.formatString.flatMap(StringFormat.init(rawValue:)))

            case .object(_, let objectContext):
                if let schema = objectContext.additionalProperties?.schemaValue {
                    self = .anyKey(OpenAPISchema(schema))
                } else {
                    let properties = objectContext.properties.mapValues(OpenAPISchema.init).reduce(into: [:]) { result, next in
                        result[next.key] = next.value
                    }
                    self = .object(properties: properties, required: Set(objectContext.requiredProperties))
                }

            case .array(_, let arrayContext):
                let items = arrayContext.items.map(OpenAPISchema.init)
                self = .array(items!)

            case .one(let oneOf, _):
                self = .oneOf(oneOf.map(OpenAPISchema.init))

            case .reference(let ref, _):
                self = .ref(.init(rawValue: ref.name ?? ""))

            case .fragment:
                self = .undefined

            case .all, .any, .not:
                fatalError()
            }
        }
    }
}

extension OpenAPISchema {
    public struct Ref: RawRepresentable {
        public var rawValue: String
        public var key: String { rawValue.components(separatedBy: "/").last! }

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}
