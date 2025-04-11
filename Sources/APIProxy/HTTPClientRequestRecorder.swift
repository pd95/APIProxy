//
//  CallbackHTTPClientDelegate.swift
//  APIProxy
//
//  Created by Philipp on 09.04.2025.
//
import AsyncHTTPClient
import NIOHTTP1
import Vapor


final class HTTPClientRequestRecorder: HTTPClientResponseDelegate {
    typealias Response = ReplayableHTTPRequest

    let onHead: (HTTPResponseHead) -> Void
    let onBodyPart: (ByteBuffer) -> Void
    let onError: (any Error) -> Void
    let onComplete: () -> Void

    var request: ReplayableHTTPRequest

    private var buffers: [RequestReplayState] = []

    private let clock: ContinuousClock
    private let startTime: ContinuousClock.Instant
    private var headerTime: ContinuousClock.Instant?
    private var lastBodyPartTime: ContinuousClock.Instant?

    init(
        request: HTTPClient.Request,
        requestBody: ByteBuffer?,
        onHead: @escaping (HTTPResponseHead) -> Void,
        onBodyPart: @escaping (ByteBuffer) -> Void,
        onError: @escaping (any Error) -> Void,
        onComplete: @escaping () -> Void
    ) {
        clock = ContinuousClock()
        startTime =  clock.now
        self.request = ReplayableHTTPRequest(url: request.url, method: request.method, headers: request.headers, body: requestBody, startTime: startTime)
        self.onHead = onHead
        self.onBodyPart = onBodyPart
        self.onError = onError
        self.onComplete = onComplete
    }

    func didReceiveHead(task: HTTPClient.Task<ReplayableHTTPRequest>, _ head: HTTPResponseHead) -> EventLoopFuture<Void> {
        request.response = ReplayableHTTPResponse(status: head.status, headers: head.headers, version: head.version, headerTime: clock.now)
        onHead(head)
        return task.eventLoop.makeSucceededFuture(())
    }

    func didReceiveBodyPart(task: HTTPClient.Task<ReplayableHTTPRequest>, _ buffer: ByteBuffer) -> EventLoopFuture<Void> {
        request.response?.append(bodyChunk: buffer, at: clock.now)
        onBodyPart(buffer)
        return task.eventLoop.makeSucceededFuture(())
    }

    func didReceiveError(task: HTTPClient.Task<ReplayableHTTPRequest>, _ error: any Error) -> EventLoopFuture<Void> {
        onError(error)
        return task.eventLoop.makeSucceededFuture(())
    }

    func didFinishRequest(task: HTTPClient.Task<ReplayableHTTPRequest>) throws -> ReplayableHTTPRequest {
        onComplete()
        request.response?.endTime = clock.now
        return request
    }
}
