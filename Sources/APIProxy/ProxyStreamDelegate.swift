//
//  ProxyStreamDelegate.swift
//  APIProxy
//
//  Created by Philipp on 09.04.2025.
//

import Vapor
import NIOHTTP1
import AsyncHTTPClient

final class ProxyStreamDelegate: HTTPClientResponseDelegate {
    typealias Response = Void

    let writer: any BodyStreamWriter
    let logger: Logger

    init(writer: any BodyStreamWriter, logger: Logger) {
        print(#function)
        self.writer = writer
        self.logger = logger
    }

    deinit {
        print(#function)
    }

    func didReceiveHead(task: HTTPClient.Task<Void>, _ head: HTTPResponseHead) -> EventLoopFuture<Void> {
        logger.debug("HTTP Header: \(head.description)")
        // Headers received; nothing to do
        return task.eventLoop.makeSucceededFuture(())
    }

    func didReceiveBodyPart(task: HTTPClient.Task<Void>, _ buffer: ByteBuffer) -> EventLoopFuture<Void> {
        logger.debug("Body Part: \(String(buffer: buffer))")
        //print(#function, String(buffer: buffer))
        return writer.write(.buffer(buffer))
    }

    func didFinishRequest(task: HTTPClient.Task<Void>) throws -> Void {
        logger.debug("Request Finished")
        _ = writer.write(.end)
    }

    func didReceiveError(task: HTTPClient.Task<Void>, _ error: any Error) {
        logger.debug("Request Received error: \(error)")
        _ = writer.write(.error(error))
    }
}
