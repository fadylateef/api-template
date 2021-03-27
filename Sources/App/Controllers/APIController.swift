import Vapor
import FluentMySQL

/// Controls basic CRUD operations on `Todo`s.
final class APIController : RouteCollection {
    /// Returns a list of all `Todo`s.
    func boot(router: Router) throws {
        router.get("/ios/splash", use: allAds)
        router.post("/ios/episodes", use: episodes)
        router.post("/ios/getLink", use: getLink)
    }
    
    func allAds( _ req : Request) -> Future<splashResponse> {
        return dispatch(request: req, handler: { _ -> splashResponse in
            let serieses = try Series.query(on: req).all().wait()
            let categories = try Category.query(on: req).all().wait()
            guard let api = try ApiControl.find(1, on: req).wait() else { throw Abort(.notFound)}
            return splashResponse(serieses: serieses, categories: categories,apiControl: api)
        })
    }
    
    func episodes( _ req : Request) -> Future<[Episode]> {
        print(req.http)
        return dispatch(request: req, handler: { _ -> [Episode] in
            let id = try req.content.decode(episodesRequest.self).wait().series_id
            let episodes = try Episode.query(on: req).filter(\.seriesID == id).sort(\.order , .ascending).all().wait()
            return episodes
        })
    }
    
    func getLink(_ req : Request) -> Future<String> {
        return dispatch(request: req, handler: { _ -> String in
            let episode_id = try req.content.decode(linkRequest.self).wait().episode_id
            guard let link = try Episode.find(episode_id, on: req).wait()?.filename else { throw Abort(.notFound) }
            return link
        })
    }
}

final class splashResponse : Content {
    init(serieses: [Series], categories: [Category], apiControl: ApiControl) {
        self.serieses = serieses
        self.categories = categories
        self.apiControl = apiControl
    }
    
    var serieses : [Series]
    var categories : [Category]
    var apiControl : ApiControl
}

struct episodesRequest : Content {
    var series_id : Int
}

struct linkRequest : Content {
    var episode_id : Int
}
