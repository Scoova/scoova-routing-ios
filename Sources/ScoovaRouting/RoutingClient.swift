import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Pluggable HTTP transport — `(URLRequest) -> (Data, Int)`. Inject your
/// own for tests or to share a configured `URLSession` across SDKs.
public typealias RoutingTransport = @Sendable (URLRequest) async throws -> (Data, Int)

/// Routing client for the Scoova routing gateway
/// (`api.scoo-va.info/api/v1/routing`).
///
/// Eight endpoints: `route`, `optimizedRoute`, `isochrone`, `matrix`,
/// `height` (alias `elevation`), `mapMatch`, `locate`, `status`.
///
/// Pass `locale` once (e.g. `"fr"`, `"ar-EG"`, `"pt-BR"`) and every request
/// carries it as both the `?locale=` query parameter and the `Accept-Language`
/// header. Per-call `RouteOptions.locale` / `IsochroneOptions.locale`
/// overrides. Default `"en"`. Pass `apiKey` — required by the gateway —
/// sent as `X-API-Key` on every request.
public final class RoutingClient: @unchecked Sendable {
    private let baseURL: URL
    private let defaultCosting: CostingType
    private let locale: String
    private let apiKey: String?
    private let transport: RoutingTransport
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        baseURL: URL = URL(string: "https://api.scoo-va.info/api/v1/routing")!,
        defaultCosting: CostingType = .scooter,
        locale: String = "en",
        apiKey: String? = nil,
        urlSession: URLSession = .shared,
        transport: RoutingTransport? = nil
    ) {
        // Strip trailing slash.
        if baseURL.absoluteString.hasSuffix("/"),
           let trimmed = URL(string: String(baseURL.absoluteString.dropLast())) {
            self.baseURL = trimmed
        } else {
            self.baseURL = baseURL
        }
        self.defaultCosting = defaultCosting
        self.locale = locale
        self.apiKey = apiKey
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        if let transport {
            self.transport = transport
        } else {
            self.transport = { req in
                let (data, resp) = try await urlSession.data(for: req)
                let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
                return (data, status)
            }
        }
    }

    // MARK: - Endpoints

    public func route(_ locations: [LatLng], options: RouteOptions = RouteOptions()) async throws -> RouteResult {
        let effectiveLocale = options.locale ?? locale
        let payload: [String: Any] = makeRouteBody(locations: locations, options: options,
                                                   path: "route", effectiveLocale: effectiveLocale)
        return try await postJSON("/route", body: payload, locale: effectiveLocale)
    }

    public func optimizedRoute(_ locations: [LatLng], options: RouteOptions = RouteOptions()) async throws -> RouteResult {
        let effectiveLocale = options.locale ?? locale
        let payload: [String: Any] = makeRouteBody(locations: locations, options: options,
                                                   path: "optimized_route", effectiveLocale: effectiveLocale)
        return try await postJSON("/optimized_route", body: payload, locale: effectiveLocale)
    }

    public func isochrone(_ location: LatLng, options: IsochroneOptions) async throws -> AnyJSON {
        let effectiveLocale = options.locale ?? locale
        var contours: [[String: Any]] = []
        for c in options.contours {
            var o: [String: Any] = [:]
            if let t = c.time     { o["time"] = t }
            if let d = c.distance { o["distance"] = d }
            contours.append(o)
        }
        let payload: [String: Any] = [
            "locations": [["lat": location.lat, "lon": location.lon]],
            "costing": (options.costing ?? defaultCosting).rawValue,
            "contours": contours,
            "polygons": options.polygons,
        ]
        return try await postJSON("/isochrone", body: payload, locale: effectiveLocale)
    }

    public func matrix(sources: [LatLng], targets: [LatLng], costing: CostingType = .scooter) async throws -> AnyJSON {
        let payload: [String: Any] = [
            "sources": sources.map { ["lat": $0.lat, "lon": $0.lon] },
            "targets": targets.map { ["lat": $0.lat, "lon": $0.lon] },
            "costing": costing.rawValue,
        ]
        return try await postJSON("/sources_to_targets", body: payload, locale: nil)
    }

    public func height(shape: [LatLng], range: Bool = true) async throws -> AnyJSON {
        let payload: [String: Any] = [
            "shape": shape.map { ["lat": $0.lat, "lon": $0.lon] },
            "range": range,
        ]
        return try await postJSON("/height", body: payload, locale: nil)
    }

    /// Alias for `height(shape:range:)` — matches the unified SDK naming.
    public func elevation(shape: [LatLng], range: Bool = true) async throws -> AnyJSON {
        try await height(shape: shape, range: range)
    }

    public func mapMatch(shape: [LatLng], costing: CostingType = .scooter) async throws -> RouteResult {
        let payload: [String: Any] = [
            "shape": shape.map { ["lat": $0.lat, "lon": $0.lon] },
            "costing": costing.rawValue,
            "shape_match": "map_snap",
        ]
        return try await postJSON("/trace_route", body: payload, locale: nil)
    }

    public func locate(locations: [LatLng], costing: CostingType = .scooter) async throws -> AnyJSON {
        let payload: [String: Any] = [
            "locations": locations.map { ["lat": $0.lat, "lon": $0.lon] },
            "costing": costing.rawValue,
        ]
        return try await postJSON("/locate", body: payload, locale: nil)
    }

    public func status() async throws -> AnyJSON {
        try await get("/status")
    }

    // MARK: - Internals

    private func makeRouteBody(locations: [LatLng], options: RouteOptions,
                               path: String, effectiveLocale: String) -> [String: Any] {
        var body: [String: Any] = [
            "locations": locations.map { ["lat": $0.lat, "lon": $0.lon] },
            "costing": (options.costing ?? defaultCosting).rawValue,
            "directions_options": [
                "units": options.units.rawValue,
                "language": options.language ?? effectiveLocale,
            ],
        ]
        if options.simplifiedInstructions { body["simplified_instructions"] = true }
        if let a = options.alternates { body["alternates"] = a }
        _ = path  // reserved for future per-endpoint tweaks
        return body
    }

    private func urlFor(_ path: String, perCallLocale: String?) -> URL? {
        let effective = perCallLocale ?? locale
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "locale", value: effective)]
        return comps?.url
    }

    private func headers(perCallLocale: String?, includeContentType: Bool) -> [String: String] {
        var h: [String: String] = [
            "Accept": "application/json",
            "Accept-Language": perCallLocale ?? locale,
        ]
        if includeContentType { h["Content-Type"] = "application/json" }
        if let k = apiKey { h["X-API-Key"] = k }
        return h
    }

    private func postJSON<T: Decodable>(_ path: String, body: [String: Any], locale: String?) async throws -> T {
        guard let url = urlFor(path, perCallLocale: locale) else { throw RoutingError.invalidURL }
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            throw RoutingError.decode("encode body: \(error.localizedDescription)")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = data
        for (k, v) in headers(perCallLocale: locale, includeContentType: true) {
            req.setValue(v, forHTTPHeaderField: k)
        }
        return try await execute(req)
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = urlFor(path, perCallLocale: nil) else { throw RoutingError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        for (k, v) in headers(perCallLocale: nil, includeContentType: false) {
            req.setValue(v, forHTTPHeaderField: k)
        }
        return try await execute(req)
    }

    private func execute<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, status): (Data, Int)
        do {
            (data, status) = try await transport(req)
        } catch {
            throw RoutingError.transport(error.localizedDescription)
        }
        guard (200..<300).contains(status) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw RoutingError.http(status: status, body: body)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw RoutingError.decode(error.localizedDescription)
        }
    }
}

// MARK: - Polyline6 decode

/// Decode a polyline (precision 6, Google-format) string into `[LatLng]`.
public func decodePolyline(_ encoded: String, precision: Int = 6) -> [LatLng] {
    var coords: [LatLng] = []
    let factor = pow(10.0, Double(precision))
    let bytes = Array(encoded.utf8)
    var index = 0
    var lat = 0
    var lon = 0
    while index < bytes.count {
        var shift = 0
        var result = 0
        var b: Int
        repeat {
            b = Int(bytes[index]) - 63
            index += 1
            result |= (b & 0x1f) << shift
            shift += 5
        } while b >= 0x20
        lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        shift = 0
        result = 0
        repeat {
            b = Int(bytes[index]) - 63
            index += 1
            result |= (b & 0x1f) << shift
            shift += 5
        } while b >= 0x20
        lon += (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        coords.append(LatLng(lat: Double(lat) / factor, lon: Double(lon) / factor))
    }
    return coords
}
