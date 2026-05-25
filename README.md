# ScoovaRouting

Routing client for `routing.scoo-va.info`. Swift
package — iOS 15+ / macOS 12+ / tvOS 15+ / watchOS 8+.

## Install

In **Xcode** → File → Add Packages → enter
`https://github.com/Scoova/scoova-routing-ios.git`.

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Scoova/scoova-routing-ios.git", from: "1.1.0")
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "ScoovaRouting", package: "scoova-routing-ios")
    ])
]
```

## Usage

```swift
import ScoovaRouting

let client = RoutingClient(
    locale: "ar-EG",                                          // sent as ?locale= + Accept-Language
    apiKey: ProcessInfo.processInfo.environment["SCOOVA_API_KEY"]
)

let result = try await client.route(
    [LatLng(lat: 30.04, lon: 31.24), LatLng(lat: 30.06, lon: 31.25)],
    options: RouteOptions(costing: .scooter)
)
let path = decodePolyline(result.trip.legs[0].shape)
```

## Endpoints

`route`, `optimizedRoute`, `isochrone`, `matrix`, `height` (alias `elevation`),
`mapMatch`, `locate`, `status`.

## Locale

Set a default locale once on the client and every call carries it as both the
`?locale=` query parameter and the `Accept-Language` HTTP header. Per-call
`RouteOptions.locale` overrides the client default. The server falls back to
`en` for any unsupported code.

## Build + test

```sh
swift build
swift test
```

Repo: <https://github.com/Scoova/scoova-routing-ios>.
License: Apache-2.0.
