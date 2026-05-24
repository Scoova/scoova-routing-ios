import XCTest
@testable import ScoovaRouting

private let okTripJSON = """
{
  "trip": {
    "legs": [],
    "summary": {"length": 0, "time": 0},
    "status": 0,
    "status_message": "OK",
    "units": "kilometers"
  }
}
""".data(using: .utf8)!

private actor Recorder {
    var lastRequest: URLRequest?
    var lastBody: [String: Any]?
    func record(_ req: URLRequest) {
        lastRequest = req
        if let body = req.httpBody,
           let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            lastBody = obj
        }
    }
}

final class RoutingClientTests: XCTestCase {
    func testRouteHitsRouteWithSaneDefaults() async throws {
        let recorder = Recorder()
        let client = RoutingClient(
            baseURL: URL(string: "https://example.test")!,
            transport: { req in
                await recorder.record(req)
                return (okTripJSON, 200)
            }
        )
        _ = try await client.route([LatLng(lat: 30, lon: 31), LatLng(lat: 31, lon: 32)])
        let req = await recorder.lastRequest
        let body = await recorder.lastBody
        XCTAssertEqual(req?.httpMethod, "POST")
        XCTAssertTrue(req?.url?.absoluteString.contains("https://example.test/route") ?? false)
        XCTAssertTrue(req?.url?.query?.contains("locale=en") ?? false)
        XCTAssertEqual(req?.value(forHTTPHeaderField: "Accept-Language"), "en")
        XCTAssertEqual(body?["costing"] as? String, "scooter")
        let directions = body?["directions_options"] as? [String: Any]
        XCTAssertEqual(directions?["language"] as? String, "en")
    }

    func testClientLocaleFlowsIntoUrlHeaderAndDirectionsOptions() async throws {
        let recorder = Recorder()
        let client = RoutingClient(
            baseURL: URL(string: "https://example.test")!,
            locale: "fr",
            transport: { req in
                await recorder.record(req)
                return (okTripJSON, 200)
            }
        )
        _ = try await client.route([LatLng(lat: 30, lon: 31), LatLng(lat: 31, lon: 32)])
        let req = await recorder.lastRequest
        let body = await recorder.lastBody
        XCTAssertTrue(req?.url?.query?.contains("locale=fr") ?? false)
        XCTAssertEqual(req?.value(forHTTPHeaderField: "Accept-Language"), "fr")
        XCTAssertEqual((body?["directions_options"] as? [String: Any])?["language"] as? String, "fr")
    }

    func testPerCallLocaleOverridesClientDefault() async throws {
        let recorder = Recorder()
        let client = RoutingClient(
            baseURL: URL(string: "https://example.test")!,
            locale: "fr",
            transport: { req in
                await recorder.record(req)
                return (okTripJSON, 200)
            }
        )
        let opts = RouteOptions(locale: "ar-EG")
        _ = try await client.route([LatLng(lat: 30, lon: 31), LatLng(lat: 31, lon: 32)], options: opts)
        let req = await recorder.lastRequest
        let body = await recorder.lastBody
        XCTAssertTrue(req?.url?.query?.contains("locale=ar-EG") ?? false)
        XCTAssertEqual(req?.value(forHTTPHeaderField: "Accept-Language"), "ar-EG")
        XCTAssertEqual((body?["directions_options"] as? [String: Any])?["language"] as? String, "ar-EG")
    }

    func testApiKeyHeader() async throws {
        let recorder = Recorder()
        let client = RoutingClient(
            baseURL: URL(string: "https://example.test")!,
            apiKey: "demo",
            transport: { req in
                await recorder.record(req)
                return (okTripJSON, 200)
            }
        )
        _ = try await client.route([LatLng(lat: 30, lon: 31), LatLng(lat: 31, lon: 32)])
        let req = await recorder.lastRequest
        XCTAssertEqual(req?.value(forHTTPHeaderField: "X-API-Key"), "demo")
    }

    func testRespectsCostingAlternates() async throws {
        let recorder = Recorder()
        let client = RoutingClient(
            baseURL: URL(string: "https://example.test")!,
            transport: { req in
                await recorder.record(req)
                return (okTripJSON, 200)
            }
        )
        let opts = RouteOptions(
            costing: .pedestrian,
            language: "ar-EG",
            alternates: 2,
            simplifiedInstructions: true
        )
        _ = try await client.route([LatLng(lat: 30, lon: 31), LatLng(lat: 31, lon: 32)], options: opts)
        let body = await recorder.lastBody
        XCTAssertEqual(body?["costing"] as? String, "pedestrian")
        XCTAssertEqual((body?["directions_options"] as? [String: Any])?["language"] as? String, "ar-EG")
        XCTAssertEqual(body?["alternates"] as? Int, 2)
        XCTAssertEqual(body?["simplified_instructions"] as? Bool, true)
    }

    func testMatrixHitsSourcesToTargets() async throws {
        let recorder = Recorder()
        let client = RoutingClient(
            baseURL: URL(string: "https://example.test")!,
            transport: { req in await recorder.record(req); return ("{}".data(using: .utf8)!, 200) }
        )
        _ = try await client.matrix(sources: [LatLng(lat: 30, lon: 31)], targets: [LatLng(lat: 31, lon: 32)])
        let req = await recorder.lastRequest
        XCTAssertTrue(req?.url?.absoluteString.contains("https://example.test/sources_to_targets") ?? false)
    }

    func testHeightAndElevationHitHeight() async throws {
        let recorder = Recorder()
        let client = RoutingClient(
            baseURL: URL(string: "https://example.test")!,
            transport: { req in await recorder.record(req); return ("{}".data(using: .utf8)!, 200) }
        )
        _ = try await client.height(shape: [LatLng(lat: 30, lon: 31)])
        let req1 = await recorder.lastRequest
        XCTAssertTrue(req1?.url?.absoluteString.contains("https://example.test/height") ?? false)

        _ = try await client.elevation(shape: [LatLng(lat: 30, lon: 31)])
        let req2 = await recorder.lastRequest
        XCTAssertTrue(req2?.url?.absoluteString.contains("https://example.test/height") ?? false)
    }

    func testMapMatchHitsTraceRoute() async throws {
        let recorder = Recorder()
        let client = RoutingClient(
            baseURL: URL(string: "https://example.test")!,
            transport: { req in await recorder.record(req); return (okTripJSON, 200) }
        )
        _ = try await client.mapMatch(shape: [LatLng(lat: 30, lon: 31), LatLng(lat: 31, lon: 32)])
        let req = await recorder.lastRequest
        let body = await recorder.lastBody
        XCTAssertTrue(req?.url?.absoluteString.contains("https://example.test/trace_route") ?? false)
        XCTAssertEqual(body?["shape_match"] as? String, "map_snap")
    }

    func testStatusHitsStatus() async throws {
        let recorder = Recorder()
        let client = RoutingClient(
            baseURL: URL(string: "https://example.test")!,
            transport: { req in await recorder.record(req); return ("{}".data(using: .utf8)!, 200) }
        )
        _ = try await client.status()
        let req = await recorder.lastRequest
        XCTAssertEqual(req?.httpMethod, "GET")
        XCTAssertTrue(req?.url?.absoluteString.contains("https://example.test/status") ?? false)
    }

    func testNon2xxThrowsHttpError() async throws {
        let client = RoutingClient(
            baseURL: URL(string: "https://example.test")!,
            transport: { _ in ("boom".data(using: .utf8)!, 502) }
        )
        do {
            _ = try await client.route([LatLng(lat: 30, lon: 31), LatLng(lat: 31, lon: 32)])
            XCTFail("expected error")
        } catch let RoutingError.http(status, _) {
            XCTAssertEqual(status, 502)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }
}

final class PolylineTests: XCTestCase {
    func testDecodesCanonicalFixture() {
        let coords = decodePolyline("_p~iF~ps|U_ulLnnqC_mqNvxq`@")
        XCTAssertEqual(coords.count, 3)
    }
}
