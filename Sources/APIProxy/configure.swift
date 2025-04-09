import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // Register ProxyService lifecycle handler
    app.lifecycle.use(app.proxyService)

    // register routes
    try routes(app)
}
