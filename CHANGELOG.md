# Changelog

All notable changes to `ScoovaRouting` (Swift) are recorded here.
This project follows [Semantic Versioning](https://semver.org/).

## 1.1.1 — 2026-05-25
- Default `baseURL` switched from the retired `https://routing.scoo-va.info` subdomain to the central gateway at `https://api.scoo-va.info/api/v1/routing`. Callers who explicitly set `baseURL` are unaffected. The old subdomain returns `ENDPOINT_RETIRED`.

## 1.1.0 — 2026-05-25

First public release. Routing client for
`routing.scoo-va.info`.

### Endpoints (verified parity across all 5 platforms)

`route`, `optimizedRoute`, `isochrone`, `matrix`, `height` (alias `elevation`),
`mapMatch`, `locate`, `status`.

### Features

- Built-in locale support — pass `locale: "fr"` / `"ar-EG"` / `"pt-BR"` once
  and every request carries it as both the `?locale=` query parameter and
  the `Accept-Language` header. Per-call `RouteOptions.locale` /
  `IsochroneOptions.locale` override. Default `"en"`.
- `apiKey` constructor argument — sent as `X-API-Key` when set, for calls
  routed through the `api.scoo-va.info/v1/routing/*` gateway.
- Pluggable `RoutingTransport` (`(URLRequest) async throws -> (Data, Int)`)
  for tests and shared `URLSession` configurations.
- Polyline6 decoder included.
- Pure Swift, no third-party dependencies.

### Platforms

iOS 15+, macOS 12+, tvOS 15+, watchOS 8+.

### Repo

<https://github.com/Scoova/scoova-routing-ios>
