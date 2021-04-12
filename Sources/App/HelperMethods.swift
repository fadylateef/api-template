//
//  HelperMethods.swift
//  App
//
//  Created by Fady Lateef on 08/03/2021.
//

import Vapor

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
