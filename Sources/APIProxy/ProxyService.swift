import AsyncHTTPClient
import Vapor

struct ProxyService {
    let httpClient: HTTPClient

    init(app: Application) {
        self.httpClient = HTTPClient(eventLoopGroupProvider: .shared(app.eventLoopGroup))
    }

    func shutdown() throws {
        try httpClient.syncShutdown()
    }
}

// Store globally in app
extension Application {
    private struct ProxyServiceKey: StorageKey {
        typealias Value = ProxyService
    }

    var proxyService: ProxyService {
        if let existing = self.storage[ProxyServiceKey.self] {
            return existing
        }
        let new = ProxyService(app: self)
        self.storage[ProxyServiceKey.self] = new
        return new
    }
}

