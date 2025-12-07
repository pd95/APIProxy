//
//  OllamaLogger.swift
//  APIProxy
//
//  Created by Philipp on 06.12.2025.
//

import NIOCore
import Logging
import Foundation

private extension ByteBuffer {
    mutating func readDataUntilNewline() -> Data? {
        guard let index = self.readableBytesView.firstIndex(of: 10) else {
            return nil
        }

        let length = index - self.readerIndex
        let data = self.readData(length: length)
        _ = self.readBytes(length: 1) // das "\n" konsumieren

        return data
    }
}

struct OllamaLogger {

    static let logger = {
        var logger = Logger(label: "OllamaAPI")
        logger.logLevel = .info
        return logger
    }()

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
        let isOpenAICompatibility = url.prefix(3) == "/v1"
        var readBuffer = buffer

        // Some requests start with a plain text prefix
        if isOpenAICompatibility && readBuffer.getString(at: 0, length: 5) == "data:" {
            readBuffer.moveReaderIndex(forwardBy: 5)
        }
        guard let bodyData = readBuffer.readDataUntilNewline() ?? readBuffer.readData(length: readBuffer.readableBytes),
              let json = try? JSONSerialization.jsonObject(with: bodyData, options: [])
        else {
            print()
            Self.logger.error("Invalid JSON Data: \(buffer.getString(at: 0, length: buffer.readableBytes) ?? "")")
            return // not a valid JSON response or possibly only part of the message
        }

        Self.logger.debug("json: \(json)")

        guard let jsonObject = json as? [String: Any] else {
            Self.logger.error("\(url) returned not a JSON object: \(json)")
            return
        }


        if isOpenAICompatibility {
            let object = jsonObject["object"] as? String
            if object == "chat.completion.chunk" {
                if let message = (jsonObject["choices"] as? [[String: Any]])?[0],
                   let delta = message["delta"] as? [String: Any]
                {
                    if let content = delta["content"] as? String {
                        print(content, terminator: "")
                    }
                    if let content = message["content"] as? String {
                        print(content, terminator: "")
                    }
                }
            }
        } else {
            if let message = jsonObject["message"] as? [String: Any],
               let done = jsonObject["done"] as? Bool,
               done == false
            {
                if let content = message["thinking"] as? String {
                    print(content, terminator: "")
                }
                if let content = message["content"] as? String {
                    print(content, terminator: "")
                }
            }
        }

        if readBuffer.readableBytes > 1 {
            print("")
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
