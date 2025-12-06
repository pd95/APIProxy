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

    let method: String
    let url: String

    init(method: String, uri: String) {
        self.method = method
        self.url = uri
        Self.logger.info("REQ: \(method) \(url)")
    }

    func log(request: ReplayableHTTPRequest) {
        if let data = request.body {
            log(buffer: data)
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
