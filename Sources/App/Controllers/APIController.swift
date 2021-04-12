import Vapor
import FluentMySQL

var country_whitelist = ["SA","KW","AE","EG","OM","BH","IQ","LY","QA"]

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
            var categories = try Category.query(on: req).all().wait()
            guard let api = try ApiControl.find(1, on: req).wait() else { throw Abort(.notFound)}
            guard let ip = req.http.remotePeer.hostname else { throw Abort(.unauthorized) }
            guard let country_code = try req.withNewConnection(to: .mysql, closure: { conn -> EventLoopFuture<mysqlresult?> in
                return conn.raw("SELECT `country_code` FROM `ip2location` WHERE INET_ATON('\(ip)') <= ip_to LIMIT 1").first(decoding: mysqlresult.self)
            }).wait()?.country_code else { throw Abort(.unauthorized)}
//            if country_whitelist.contains(country_code) {
//                api.api = true
//            }else {
//                api.api = false
//            }
            switch country_code {
            case "KW" :
                categories[2].title += " 🇰🇼"
                categories.rearrange(from: 2, to: 0)
            case "EG" :
                categories[0].title += " 🇪🇬"
            case "SA" :
                categories[1].title += " 🇸🇦"
                categories.rearrange(from: 1, to: 0)
            default : print("do nothing")
            }
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

struct mysqlresult : Content {
    var country_code : String
}

public func sendNoti(req : Request,to : String,body : String,badge : Int) {
    var heads = HTTPHeaders()
    heads.add(name: "content-type", value: "application/json")
    heads.add(name: "authorization", value: "key=AAAAyY-mcpA:APA91bG-ffbFLVbWU4Bg4uyXQVlCCfu85scfbihI_oB3N72uorXLLCX6YztfwjcPzoBrAAMeMs1PqgZZh9aPAGqGE594nesENH1xlJziVPchNfBa5Tt4-fxCpmgg1TPU1px89PxDPDFa")
    let a = try? req.client().post(URL(string: "https://fcm.googleapis.com/fcm/send")!, headers: heads, beforeSend: { req in
        try req.content.encode(json: notificationBody(to: "/topics/\(to)", notification: notification(body: body,badge: badge)))
    }).map { res in
        print(res.description)
    }
}

struct notificationBody : Content {
    var to : String
    var notification : notification
}

struct notification : Content {
//    var title : String
    var body : String
    var badge : Int
 //   var sound : String
}
