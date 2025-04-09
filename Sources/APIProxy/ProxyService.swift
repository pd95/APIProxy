import AsyncHTTPClient
import Vapor

struct ProxyService: LifecycleHandler {
    let httpClient: HTTPClient

    init(app: Application) {
        self.httpClient = HTTPClient(eventLoopGroupProvider: .shared(app.eventLoopGroup))
    }

    func willBoot(_ app: Application) throws {
        app.logger.info("Application is about to boot")
    }

    func didBoot(_ app: Application) throws {
        app.logger.info("Application has booted")
    }

    func shutdown(_ app: Application) {
        app.logger.info("Application is shutting down")
        try? httpClient.syncShutdown()
    }

    func forwardRequest(_ req: Request) async throws -> Response {
        //print(#function, req.url.path, req.method, req.body)

        let response = Response(status: .ok) // real status will be async

        response.body = Response.Body(stream: { writer in
            var body: HTTPClient.Body?
            if let data = req.body.data {
                body = .byteBuffer(data)
            }

            do {
                let request = try HTTPClient.Request(
                    url: "http://localhost:11434\(req.url.path)",
                    method: req.method,
                    headers: req.headers,
                    body: body
                )

                //app.logger.info("Request: \(request.headers)")

                let delegate = ProxyStreamDelegate(writer: writer, logger: req.logger)

                httpClient.execute(request: request, delegate: delegate)
                    .futureResult.whenComplete { result in
                        switch result {
                        case .success:
                            req.logger.debug("success")
                        case .failure(let error):
                            req.logger.debug("error: \(error)")
                        }
                    }
            } catch {
                _ = writer.write(.error(error))
            }
         })

        return response
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

