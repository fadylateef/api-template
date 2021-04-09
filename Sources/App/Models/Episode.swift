//
//  Episode.swift
//  App
//
//  Created by Fady Lateef on 08/03/2021.
//

import Vapor
import FluentMySQL

final class Episode: MySQLModel {
    init(id: Int? = nil, filename: String? = nil, seriesID: Int, thumbnail: String? = nil, duration: Int? = nil, order: Int) {
        self.id = id
        self.filename = filename
        self.seriesID = seriesID
        self.thumbnail = thumbnail
        self.duration = duration
        self.order = order
    }
    
    /// The unique identifier for this `Todo`.
    var id: Int?
    var filename: String?
    var seriesID : Int
    var thumbnail : String?
    var duration : Int?
    var order : Int
}

extension Episode: Migration { }
extension Episode: Content { }
extension Episode: Parameter { }

extension Array where Element == Episode {
    func convertToPublich() -> [Episode] {
        return self.map {
            var epi = $0
            epi.thumbnail = "https://drmdn.app/img/\(epi.thumbnail!)"
            return epi
        }
    }
    
}
