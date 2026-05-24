import Foundation

// MARK: - Shared

public struct LatLng: Codable, Sendable, Hashable {
    public let lat: Double
    public let lon: Double
    public init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }
}

public enum CostingType: String, Codable, Sendable {
    case auto
    case bicycle
    case scooter
    case pedestrian
    case truck
    case motorcycle
    case motorScooter = "motor_scooter"
}

public enum Units: String, Codable, Sendable {
    case kilometers
    case miles
}

// MARK: - Route

public struct RouteOptions: Sendable {
    public var costing: CostingType?
    /// Sent as `directions_options.language`. When `nil`, the effective locale
    /// (per-call → client → `"en"`) is used.
    public var language: String?
    /// Per-call locale override. Sent as the `?locale=` query parameter and
    /// the `Accept-Language` header for this single request.
    public var locale: String?
    public var units: Units
    public var alternates: Int?
    public var simplifiedInstructions: Bool

    public init(
        costing: CostingType? = nil,
        language: String? = nil,
        locale: String? = nil,
        units: Units = .kilometers,
        alternates: Int? = nil,
        simplifiedInstructions: Bool = false
    ) {
        self.costing = costing
        self.language = language
        self.locale = locale
        self.units = units
        self.alternates = alternates
        self.simplifiedInstructions = simplifiedInstructions
    }
}

public struct IsochroneContour: Sendable {
    /// Time in minutes.
    public var time: Double?
    /// Distance in km.
    public var distance: Double?
    public init(time: Double? = nil, distance: Double? = nil) {
        self.time = time
        self.distance = distance
    }
}

public struct IsochroneOptions: Sendable {
    public var contours: [IsochroneContour]
    public var costing: CostingType?
    public var polygons: Bool
    public var locale: String?
    public init(
        contours: [IsochroneContour],
        costing: CostingType? = nil,
        polygons: Bool = true,
        locale: String? = nil
    ) {
        self.contours = contours
        self.costing = costing
        self.polygons = polygons
        self.locale = locale
    }
}

// MARK: - Response types

public struct RouteSummary: Codable, Sendable {
    public let length: Double           // km
    public let time: Double             // seconds
    public let hasToll: Bool?
    public let hasHighway: Bool?
    public let hasFerry: Bool?
    enum CodingKeys: String, CodingKey {
        case length, time
        case hasToll = "has_toll"
        case hasHighway = "has_highway"
        case hasFerry = "has_ferry"
    }
}

public struct Maneuver: Codable, Sendable {
    public let type: Int
    public let instruction: String?
    public let length: Double
    public let time: Double
    public let beginShapeIndex: Int
    public let endShapeIndex: Int
    public let streetNames: [String]?
    public let verbalPreTransition: String?
    public let verbalPostTransition: String?
    public let scoova: AnyJSON?
    enum CodingKeys: String, CodingKey {
        case type, instruction, length, time, scoova
        case beginShapeIndex = "begin_shape_index"
        case endShapeIndex = "end_shape_index"
        case streetNames = "street_names"
        case verbalPreTransition = "verbal_pre_transition_instruction"
        case verbalPostTransition = "verbal_post_transition_instruction"
    }
}

public struct RouteLeg: Codable, Sendable {
    public let shape: String
    public let summary: RouteSummary
    public let maneuvers: [Maneuver]
}

public struct RouteTrip: Codable, Sendable {
    public let legs: [RouteLeg]
    public let summary: RouteSummary
    public let status: Int
    public let statusMessage: String
    public let units: String
    public let language: String?
    public let scoova: AnyJSON?
    enum CodingKeys: String, CodingKey {
        case legs, summary, status, units, language, scoova
        case statusMessage = "status_message"
    }
}

public struct RouteResult: Codable, Sendable {
    public let trip: RouteTrip
}

// MARK: - Errors

public enum RoutingError: Error, CustomStringConvertible, Sendable {
    case http(status: Int, body: String)
    case decode(String)
    case transport(String)
    case invalidURL

    public var description: String {
        switch self {
        case .http(let s, let b): return "RoutingError.http(\(s)): \(b.prefix(200))"
        case .decode(let m):      return "RoutingError.decode: \(m)"
        case .transport(let m):   return "RoutingError.transport: \(m)"
        case .invalidURL:         return "RoutingError.invalidURL"
        }
    }
}

// MARK: - AnyJSON

/// Opaque carrier for the `scoova` block (and any other nested JSON we
/// don't want to fully model). Decodes any valid JSON; encodes back the
/// same shape.
///
/// `@unchecked Sendable` because the backing value is `Any`. In practice we
/// only ever decode JSON primitives + collections, which are all value
/// types; we just can't statically express that to the compiler.
public struct AnyJSON: Codable, @unchecked Sendable {
    public let rawValue: Any
    public init(rawValue: Any) { self.rawValue = rawValue }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self.rawValue = NSNull(); return }
        if let v = try? c.decode(Bool.self)   { self.rawValue = v; return }
        if let v = try? c.decode(Int64.self)  { self.rawValue = v; return }
        if let v = try? c.decode(Double.self) { self.rawValue = v; return }
        if let v = try? c.decode(String.self) { self.rawValue = v; return }
        if let v = try? c.decode([AnyJSON].self) { self.rawValue = v.map { $0.rawValue }; return }
        if let v = try? c.decode([String: AnyJSON].self) {
            self.rawValue = v.mapValues { $0.rawValue }; return
        }
        self.rawValue = NSNull()
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch rawValue {
        case is NSNull: try c.encodeNil()
        case let b as Bool: try c.encode(b)
        case let i as Int64: try c.encode(i)
        case let d as Double: try c.encode(d)
        case let s as String: try c.encode(s)
        case let arr as [Any]: try c.encode(arr.map { AnyJSON(rawValue: $0) })
        case let obj as [String: Any]: try c.encode(obj.mapValues { AnyJSON(rawValue: $0) })
        default: try c.encodeNil()
        }
    }
}
