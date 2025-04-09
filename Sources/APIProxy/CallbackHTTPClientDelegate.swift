//
//  CallbackHTTPClientDelegate.swift
//  APIProxy
//
//  Created by Philipp on 09.04.2025.
//
import AsyncHTTPClient
import NIOHTTP1
import Vapor

final class CallbackHTTPClientDelegate: HTTPClientResponseDelegate {
    typealias Response = Void

    let onHead: (HTTPResponseHead) -> Void
    let onBodyPart: (ByteBuffer) -> Void
    let onError: (any Error) -> Void
    let onComplete: () -> Void

    init(
        onHead: @escaping (HTTPResponseHead) -> Void,
        onBodyPart: @escaping (ByteBuffer) -> Void,
        onError: @escaping (any Error) -> Void,
        onComplete: @escaping () -> Void
    ) {
        self.onHead = onHead
        self.onBodyPart = onBodyPart
        self.onError = onError
        self.onComplete = onComplete
    }

    func didReceiveHead(task: HTTPClient.Task<Response>, _ head: HTTPResponseHead) -> EventLoopFuture<Void> {
        onHead(head)
        return task.eventLoop.makeSucceededFuture(())
    }

    func didReceiveBodyPart(task: HTTPClient.Task<Response>, _ buffer: ByteBuffer) -> EventLoopFuture<Void> {
        onBodyPart(buffer)
        return task.eventLoop.makeSucceededFuture(())
    }

    func didReceiveError(task: HTTPClient.Task<Response>, _ error: any Error) -> EventLoopFuture<Void> {
        onError(error)
        return task.eventLoop.makeSucceededFuture(())
    }

    func didFinishRequest(task: HTTPClient.Task<Void>) throws -> Void {
        onComplete()
    }
}

