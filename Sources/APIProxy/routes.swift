import Vapor

func routes(_ app: Application) throws {
    // Capture and forward requests to the specified target host and port.
    app.on(.HEAD, "", use: { try await forwardRequest($0, app: app) })
    app.on(.GET, .catchall, use: { try await forwardRequest($0, app: app) })
    app.on(.POST, .catchall, use: { try await forwardRequest($0, app: app) })
}

func forwardRequest(_ request: Request, app: Application) async throws -> ClientResponse {
    let client = app.client

    // Copy all headers from the incoming request.
    var forwardedHeaders = HTTPHeaders()
    for (name, value) in request.headers {
        forwardedHeaders.add(name: name, value: value)
    }

    app.logger.trace("Forwarding request to \(request.url.path)")
    do {
        let body = try await request.body.collect(upTo: .max)
        print(#function, "received body: \(body.readableBytes) bytes")

        // Prepare a new client request to forward with the same properties as the original one.
        let request = ClientRequest(
            method: request.method,
            url: URI(string: "http://localhost:11434\(request.url.path)"),
            headers: forwardedHeaders,
            body: body
        )

        print(#function, "sending request")
        let response = try await client.send(request)

        print(#function, "received response", response)
        app.logger.trace("Returning response \(response.body?.description ?? "nil")")
        return response
    } catch {
        app.logger.error("Error forwarding request: \(error)")
        throw error
    }
}
