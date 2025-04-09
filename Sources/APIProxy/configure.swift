import Vapor

struct ProxyLifecycleHandler: LifecycleHandler {
    let proxyService: ProxyService

    func willBoot(_ app: Application) throws {
        app.logger.info("Application is about to boot")
    }

    func didBoot(_ app: Application) throws {
        app.logger.info("Application has booted")
    }

    func shutdown(_ app: Application) {
        app.logger.info("Application is shutting down")
        try? proxyService.shutdown()
    }
}

// configures your application
public func configure(_ app: Application) async throws {
    let proxyService = app.proxyService
    app.lifecycle.use(ProxyLifecycleHandler(proxyService: proxyService))

    // register routes
    try routes(app)
}
