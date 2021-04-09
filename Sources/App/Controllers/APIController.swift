import Vapor
import FluentMySQL

/// Controls basic CRUD operations on `Todo`s.
final class APIController : RouteCollection {
    /// Returns a list of all `Todo`s.
    func boot(router: Router) throws {
        let prot = router.grouped(APIAccessMiddleware.self)
        prot.get("/ios/splash", use: allAds)
        prot.post("/ios/episodes", use: episodes)
        prot.post("/ios/getLink", use: getLink)
        
        let droid = router.grouped(APIAccessMiddleware2.self)
        droid.get("/android/all", use: allDroid)
        droid.post("/android/episodes", use : episodes)
        droid.post("/android/getLink", use: getLink)
        
        let ios2 = router.grouped(APIAccessMiddleware.self)
        ios2.get("/ios2/splash", use: allIos2)
        ios2.post("/ios2/episodes", use : episodes)
        ios2.post("/ios2/getLink", use: getLink)
    }
    
    func allAds( _ req : Request) -> Future<splashResponse> {
        return dispatch(request: req, handler: { _ -> splashResponse in
            let serieses = try Series.query(on: req).all().wait()
            let categories = try Category.query(on: req).all().wait()
            guard let api = try ApiControl.find(1, on: req).wait() else { throw Abort(.notFound)}
            return splashResponse(serieses: serieses, categories: categories,apiControl: api)
        })
    }
    
    func allDroid( _ req : Request) -> Future<droidResponse> {
        return dispatch(request: req, handler: { _ -> droidResponse in
            let serieses = try Series.query(on: req).all().wait()
            let categories = try Category.query(on: req).all().wait()
            return droidResponse(serieses: serieses, categories: categories)
        })
    }
    
    func allIos2( _ req : Request) -> Future<splashResponse> {
        return dispatch(request: req, handler: { _ -> splashResponse in
            let serieses = try Series.query(on: req).all().wait()
            let categories = try Category.query(on: req).all().wait()
            guard let api = try ApiControl.find(2, on: req).wait() else { throw Abort(.notFound)}
            return splashResponse(serieses: serieses, categories: categories,apiControl: api)
        })
    }
    
    func episodes( _ req : Request) -> Future<[Episode]> {
        return dispatch(request: req, handler: { _ -> [Episode] in
            let id = try req.content.decode(episodesRequest.self).wait().series_id
            let episodes = try Episode.query(on: req).filter(\.seriesID == id).sort(\.order , .ascending).all().wait().convertToPublich()
            return episodes
        })
    }
    
    func getLink(_ req : Request) -> Future<String> {
        return dispatch(request: req, handler: { _ -> String in
            let episode_id = try req.content.decode(linkRequest.self).wait().episode_id
            guard let epi = try Episode.find(episode_id, on: req).wait() else { throw Abort(.notFound) }
            return "https://drmdn.app/videos/\(epi.seriesID)/\(epi.filename!)"
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

final class droidResponse : Content {
    init(serieses: [Series], categories: [Category]) {
        self.serieses = serieses
        self.categories = categories
    }
    
    var serieses : [Series]
    var categories : [Category]
}

struct episodesRequest : Content {
    var series_id : Int
}

struct linkRequest : Content {
    var episode_id : Int
}
