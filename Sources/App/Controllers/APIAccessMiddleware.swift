//
//  APIAccessMiddleware.swift
//  App
//
//  Created by Fady Lateef on 9/24/19.
//

import Vapor

struct APIAccessMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> EventLoopFuture<Response> {
        guard request.http.headers.firstValue(name: HTTPHeaderName("api-key")) == "77208572-0e3d-4397-bb0b-1e764500ed72"
        else {
            throw Abort(.unauthorized)
        }
        return try next.respond(to: request)
    }
}

extension APIAccessMiddleware: ServiceType {
  /// See `ServiceType`.
  static func makeService(for container: Container) throws -> APIAccessMiddleware {
    return try .init()
  }
}

struct APIAccessMiddleware2: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> EventLoopFuture<Response> {
        guard request.http.headers.firstValue(name: HTTPHeaderName("api-key")) == "01273362-0e3d-4397-bb0b-1e764500edxx"
        else {
            throw Abort(.unauthorized)
        }
        return try next.respond(to: request)
    }
}

extension APIAccessMiddleware2: ServiceType {
    static func makeService(for container: Container) throws -> APIAccessMiddleware2 {
        return try .init()
    }
}
