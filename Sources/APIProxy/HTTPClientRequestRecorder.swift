//
//  CallbackHTTPClientDelegate.swift
//  APIProxy
//
//  Created by Philipp on 09.04.2025.
//

import NIOCore
import NIOHTTP1

final actor HTTPClientRequestRecorder{
    var request: ReplayableHTTPRequest

    private let clock: ContinuousClock
    private let startTime: ContinuousClock.Instant

    init(
        url: String,
        method: HTTPMethod = .GET,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil,
    ) {
        clock = ContinuousClock()
        startTime =  clock.now
        self.request = ReplayableHTTPRequest(
            url: url,
            method: method,
            headers: headers,
            body: body,
            startTime: startTime
        )
    }

    func didReceive(head: HTTPResponseHead) {
        request.response = ReplayableHTTPResponse(
            status: head.status,
            headers: head.headers,
            version: head.version,
            headerTime: clock.now
        )
    }

    func didReceive(buffer: ByteBuffer) {
        request.response?.append(bodyChunk: buffer, at: clock.now)
    }

    func didFinish() {
        request.response?.endTime = clock.now
    }
}
