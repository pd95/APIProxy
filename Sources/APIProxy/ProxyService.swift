import AsyncHTTPClient
import NIOHTTP1
import Vapor

struct ProxyService: LifecycleHandler {
    let httpClient: HTTPClient
    let baseURL: String
    var writeFile = false
    var simulateResponse = false

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

        response.body = Response.Body(asyncStream: { writer in
            do {
                // Preparing body
                var requestBody: HTTPClient.Body?
                if let data = req.body.data {
                    requestBody = .byteBuffer(data)
                }

                // Preparing headers (whitout "Accept-Encoding")
                var requestHeaders: HTTPHeaders = req.headers
                requestHeaders.remove(name: .acceptEncoding)

                let request = try HTTPClient.Request(
                    url: baseURL.appending(req.url.path),
                    method: req.method,
                    headers: requestHeaders,
                    body: requestBody
                )

                // Preparing delegate
                let delegate = HTTPClientRequestRecorder(
                    request: request,
                    requestBody: req.body.data,
                    onHead: { head in
                        response.version = head.version
                        response.status = head.status
                        response.headers = head.headers
                        logger.debug("HTTP Header: \(head.description)")
                    },
                    onBodyPart: { buffer in
                        logger.debug("Body Part: \(String(buffer: buffer))")
                        Task { try await writer.writeBuffer(buffer) }
                    },
                    onError: { error in
                        logger.debug("Request Received error: \(error)")
                        Task { try await writer.write(.error(error)) }
                    },
                    onComplete: {
                        logger.debug("Request Finished")
                        Task { try await writer.write(.end) }
                    }
                )

                logger.info("Sending Request \(request.method) \(request.url) with \(requestHeaders)")
                httpClient.execute(request: request, delegate: delegate)
                    .futureResult
                    .whenComplete { result in
                        switch result {
                        case .success(let replayableRequest):
                            req.logger.debug("success:")

                            Task {
                                req.logger.info("=================")

                                if writeFile {
                                    do {
                                        let data = try JSONEncoder().encode(replayableRequest)

                                        let tempDirectoryURL = FileManager.default.temporaryDirectory
                                        let fileName = "request-\(Date.now.formatted(.iso8601.timeZoneSeparator(.omitted).dateTimeSeparator(.standard).timeSeparator(.omitted))).json"
                                        let fileURL = tempDirectoryURL.appendingPathComponent(fileName)

                                        // Write data to the file at the specified URL
                                        try data.write(to: fileURL)

                                        req.logger.info("replayable request written to \(fileURL.path(percentEncoded: false))")
                                    } catch {
                                        req.logger.error("Failed to write file: \(error.localizedDescription)")
                                    }
                                }

                                if simulateResponse {
                                    if let httpResponse = replayableRequest.httpResponse(speedFactor: 1) {
                                        print("replaying response")
                                        var count = 0
                                        for try await chunk in httpResponse.body {
                                            count += 1
                                            print(count, String(buffer: chunk).trimmingCharacters(in: .whitespacesAndNewlines))
                                        }

                                        print(count, "chunks received")
                                    }
                                }
                            }

                        case .failure(let error):
                            req.logger.debug("error: \(error)")
                        }
                    }
            } catch {
                try await writer.write(.error(error))
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

