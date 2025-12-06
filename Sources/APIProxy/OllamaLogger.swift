//
//  OllamaLogger.swift
//  APIProxy
//
//  Created by Philipp on 06.12.2025.
//

import NIOCore
import Logging
import Foundation

struct OllamaLogger {

    static let logger = Logger(label: "OllamaAPI")

    func log(request: ReplayableHTTPRequest) {
        Self.logger.info("REQ: \(request.method) \(request.url)")

        request.body.map { 
            log(buffer: $0)
        }
    }

    func log(buffer: ByteBuffer) {
        let bodyData = Data(buffer: buffer)

        if let jsonObject: [String : Any] = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any] {
            //print(jsonObject)
            if let message = jsonObject[
                "message"] as? [String: Any], let done = jsonObject["done"] as? Bool, done == false {
                if let content = message["thinking"] as? String {
                    print(content, terminator: "")
                }
                if let content = message["content"] as? String {
                    print(content, terminator: "")
                }
            }
        }
    }

    func log(response: ReplayableHTTPResponse) {
        Self.logger.info("RSP starting: \(response.status.description)")
    }

    func log(fullResponse response: ReplayableHTTPResponse) {
        let total = response.bodyChunks.reduce(0) { $0 + $1.readableBytes }
        var data = Data(capacity: total)
        response.bodyChunks.forEach {
            data.append(contentsOf: $0.readableBytesView)
        }
        if let jsonObject: [String : Any] = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            //print(jsonObject)
            if let message = jsonObject["message"] as? [String: Any] {
                if let content = message["content"] as? String {
                    print(content, terminator: "")
                }
                print()
            }
        }
        Self.logger.info("RSP completed: \(response.status.description)")
    }
}
