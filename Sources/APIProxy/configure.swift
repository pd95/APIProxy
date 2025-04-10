import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // Allow port configuration via environment
    app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init) ?? 8080

    // Register ProxyService lifecycle handler
    app.lifecycle.use(app.proxyService)

    // register routes
    try routes(app)
}
