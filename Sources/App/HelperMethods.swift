//
//  HelperMethods.swift
//  App
//
//  Created by Fady Lateef on 08/03/2021.
//

import Vapor
import Crypto

public func dispatch<T>(request: Request, handler: @escaping (Request) throws -> T) -> Future<T> {
    let promise = request.eventLoop.newPromise(T.self)

    DispatchQueue.global().async {
        do {
            let result = try handler(request)
            promise.succeed(result: result)
        } catch {
            promise.fail(error: error)
        }
    }

    return promise.futureResult
}


extension RangeReplaceableCollection where Indices: Equatable {
    mutating func rearrange(from: Index, to: Index) {
        precondition(from != to && indices.contains(from) && indices.contains(to), "invalid indices")
        insert(remove(at: from), at: to)
    }
}


func md5Hash(_ source: String) -> String {
    if let hash = try? MD5.hash(source.data(using: .utf8)!).map { String(format: "%02hhx", $0) }.joined() {
        return Data(hash.utf8).base64EncodedString()
    }else {
        return "hash not calc"
    }
}

extension Date {
    func unixNow() -> Int {
        return Int(self.timeIntervalSince1970)
    }
}
