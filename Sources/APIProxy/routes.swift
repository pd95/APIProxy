import Vapor

func routes(_ app: Application) throws {
    // Capture and forward requests to the specified target host and port.
    app.on(.HEAD, "", use: { try await forwardRequest($0, app: app) })
    app.on(.GET, .catchall, use: { try await forwardRequest($0, app: app) })
    app.on(.POST, .catchall, use: { try await forwardRequest($0, app: app) })
}

func forwardRequest(_ req: Request, app: Application) async throws -> Response {
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

            let httpClient = app.proxyService.httpClient
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
