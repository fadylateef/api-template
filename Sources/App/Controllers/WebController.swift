//
//  WebController.swift
//  App
//
//  Created by Fady Lateef on 08/04/2021.
//

import Vapor
import Leaf
import FluentMySQL

final class WebController : RouteCollection {
    /// Returns a list of all `Todo`s.
    func boot(router: Router) throws {
        router.get("cpanel", use: cpanel)
    }
    
    func cpanel( _ req : Request) -> Future<View> {
        return dispatch(request: req, handler: { req -> View in
            let serieses = try Series.query(on: req).all().wait()
            let episodes = try Episode.query(on: req).all().wait()
            var results : [seriesWeb] = []
            for serie in serieses {
                if let epi_id = episodes.last(where: { $0.seriesID == serie.id })?.order {
                    results.append(seriesWeb(id: serie.id!, name: serie.title, last_episode: epi_id + 1))
                }else {
                    results.append(seriesWeb(id: serie.id!, name: serie.title, last_episode: 1))
                }
            }
            let view = try req.view().render("base",panelResponse(results: results)).wait()
            return view

        })
    }
    
}

struct panelResponse : Content {
    var results : [seriesWeb]
}

struct seriesWeb : Content{
    var id : Int
    var name : String
    var last_episode : Int
}
