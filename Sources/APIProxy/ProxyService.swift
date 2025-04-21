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
        let httpClient = self.httpClient
        let logger = req.logger

        let recorder = HTTPClientRequestRecorder(
            url: req.url.description,
            method: req.method,
            headers: req.headers,
            body: req.body.data
        )

        // Preparing headers (whitout "Accept-Encoding")
        var requestHeaders: HTTPHeaders = req.headers
        requestHeaders.remove(name: .acceptEncoding)

        // 1. Build outgoing HTTPClient.Request
        let url = baseURL.appending(req.url.path)
        let request = try HTTPClient.Request(
            url: url,
            method: req.method,
            headers: requestHeaders,
            body: req.body.data.map { .byteBuffer($0) }
        )

        // 2. Create the delegate to stream the response
        let delegate = HTTPStreamingResponseDelegate()

        // 3. Send the request
        logger.info("Sending Request \(request.method) \(request.url) with \(requestHeaders)")
        let executionTask = httpClient.execute(request: request, delegate: delegate)
        executionTask.futureResult
            .whenComplete { result in
                switch result {
                case .success:
                    req.logger.debug("success: start post processing")

                    Task {
                        req.logger.info("=================")
                        let replayableRequest = await recorder.request

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
                    req.logger.error("error: \(error)")
                }
            }

        // 4. Wait for the head
        var responseStreamIterator = delegate.stream.makeAsyncIterator()
        guard case .head(let responseHead) = try await responseStreamIterator.next() else {
            throw Abort(.badGateway, reason: "Expected HTTP response head but didn't receive it.")
        }
        await recorder.didReceive(head: responseHead)


        // 5. Build the Response
        var headers = HTTPHeaders()
        var isChunked = false
        for (name, value) in responseHead.headers {
            headers.replaceOrAdd(name: name, value: value)
            if name.lowercased() == "transfer-encoding",
               value.lowercased().contains("chunked") {
                isChunked = true
            }
        }

        let response = Response(status: responseHead.status, headers: headers)

        // If the transimission is chunked, we have to gather all parts as an async body stream
        if isChunked {
            response.body = .init(asyncStream: { [delegateStream = delegate.stream] writer in
                do {
                    for try await event in delegateStream {
                        if case .bodyPart(let buffer) = event {
                            logger.debug("Writing Body Part: \(String(buffer: buffer))")
                            await recorder.didReceive(buffer: buffer)
                            try await writer.write(.buffer(buffer))
                        } else {
                            logger.error("An unexpected event was received: \(event)")
                        }
                    }
                    try await writer.write(.end)
                    await recorder.didFinish()
                } catch {
                    try? await writer.write(.error(error))
                    logger.error("Error reading from stream: \(error)")
                    executionTask.cancel()
                    throw error
                }
            })

        } else {
            // If it is following directly the header: gather the data and create a full response body
            var fullBody = ByteBufferAllocator().buffer(capacity: 0)
            while case .bodyPart(var buffer) = try await responseStreamIterator.next() {
                await recorder.didReceive(buffer: buffer)
                fullBody.writeBuffer(&buffer)
            }
            await recorder.didFinish()

            response.body = .init(buffer: fullBody)
        }

        return response
    }
}

// Store ProxyService  globally in app
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

