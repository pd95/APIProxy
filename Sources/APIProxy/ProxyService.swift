import AsyncHTTPClient
import NIOHTTP1
import Vapor

struct ProxyService: LifecycleHandler {
    let httpClient: HTTPClient
    let baseURL: String

    init(app: Application) {
        self.httpClient = HTTPClient(eventLoopGroupProvider: .shared(app.eventLoopGroup))
        baseURL = Environment.get("TARGET_URL") ?? "http://localhost:11434"
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
        let httpClient = self.httpClient
        let logger = req.logger

        response.body = Response.Body(stream: { writer in
            do {
                var requestBody: HTTPClient.Body?
                if let data = req.body.data {
                    requestBody = .byteBuffer(data)
                }

                let request = try HTTPClient.Request(
                    url: baseURL.appending(req.url.path),
                    method: req.method,
                    headers: req.headers,
                    body: requestBody
                )

                let delegate = CallbackHTTPClientDelegate(
                    onHead: { head in
                        response.version = head.version
                        response.status = head.status
                        response.headers = head.headers
                        logger.debug("HTTP Header: \(head.description)")
                    },
                    onBodyPart: { buffer in
                        logger.debug("Body Part: \(String(buffer: buffer))")
                        _ = writer.write(.buffer(buffer))
                    },
                    onError: { error in
                        logger.debug("Request Received error: \(error)")
                        _ = writer.write(.error(error))
                    },
                    onComplete: {
                        logger.debug("Request Finished")
                        _ = writer.write(.end)
                    }
                )

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

