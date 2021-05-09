import Vapor
import FluentMySQL
import ShellOut
import SwiftSoup
import Crypto

var global_series : [Series] = []
var global_categories : [Category] = []

/// Called after your application has initialized.
public func boot(_ app: Application) throws {
    
    do {
        let tm = Date().addingTimeInterval(7200).unixNow()
        let md = try? shellOut(to: "echo -n '\(tm)37.39.233.114 9865' | openssl md5 -binary | openssl base64 | tr +/ -_ | tr -d =")
    }catch {
        print(error)
    }
    
    // Add WebSocket upgrade support to GET /echo
    let request = Request(using: app)
//
//    var epis = epi_list.split(separator: ",")
//    for epi in epis {
//        print(epi)
//        var epi1 = epi.replacingOccurrences(of: ".m3u8", with: "").split(separator: "_")
//        var image = epi.replacingOccurrences(of: "m3u8", with: "jpg")
//
//
//    }
    
//    var durations = duration_list.split(separator: ",")
//
//    for dur in durations {
//        let dura = dur.split(separator: "-").first!
//        print(dura)
//        let len = Int("\(dura)")! / 60000
//        let fl = dur.split(separator: "-").last
//        let flname = fl!.split(separator: "/").last!
//        try? Episode.query(on: request).filter(\.filename == "\(flname)").all().map { ep in
//            print(ep)
//            if !ep.isEmpty {
//                var nw = ep.first!
//                nw.duration = len
//                try? nw.save(on: request)
//            }
//        }
//    }
    
//    do {
//        let episode_length = try shellOut(to: "sshpass -p'fady123' ssh root@185.101.107.142 \"mediainfo --Inform=\\\"General;%Duration%\\\" /ssd/videos/1/1_1.m3u8\"")
//        guard let epi_length = Int(episode_length) else { return }
//        let episode_duration = epi_length / 60000
//        print(episode_duration)
//    }catch {
//        print(error)
//    }
    
    
    
    try? Series.query(on: request).sort(\.ord , .ascending).all().map {ser in
        global_series = ser
    }
    try? Category.query(on: request).all().map {cats in
        global_categories = cats
    }
    
    wss.get("echo") { ws, req in

        var noti = true
        // Add a new on text callback
        ws.onText { ws, text in
            let split = text.split(separator: ",")
            if split.count != 3 { return }
            guard let series_id = split.first else { return }
            let episode_id = split[1]
            print(series_id)
            guard let episode_link = split.last else { return }
            ws.send(text: "\(series_id),1/10 Downloading ... ")
            DispatchQueue.global().async {
                do {
                    let videoName = "\(series_id)_\(episode_id).mp4"
                    let imageName = "\(series_id)_\(episode_id).jpg"
                    let hlsName = "\(series_id)_\(episode_id)_.m3u8"
                    let old_episode = try? Episode.query(on: req).filter(\.seriesID == Int(series_id)!).filter(\.order == Int(episode_id)!).all().wait()
                    if old_episode != nil && old_episode!.isEmpty {
                  //      ws.send(text: "\(series_id),New Episode")
                    }else {
                        noti = false
                    //    ws.send(text: "\(series_id),Old Episode")
                        try shellOut(to: "rm /images/\(imageName) 2>/dev/null")
                        try? old_episode?.first!.delete(on: req).wait()
                    }
                    if episode_link.contains("ok.ru") {
                        try shellOut(to: "youtube-dl -f mpd-3 \(episode_link) -o /videos/\(series_id)/\(videoName)")
                    }else if episode_link.contains(".mp4") {
                        try shellOut(to: "curl -o /videos/\(series_id)/\(videoName) \(episode_link) -k")
                    }else if episode_link.contains(".m3u8") {
                        try shellOut(to: "youtube-dl \(episode_link) -o /videos/\(series_id)/\(videoName)")
                    }
                    ws.send(text: "\(series_id),2/12 Duration ...")
                    let episode_length = try shellOut(to: "mediainfo --Inform=\"General;%Duration%\" /videos/\(series_id)/\(videoName)")
                    guard let epi_length = Int(episode_length) else { return }
                    let episode_duration = epi_length / 60000
                    ws.send(text: "\(series_id),3/12 TS Screenshot ...")
                    try shellOut(to: "ffmpeg -ss 00:05:00 -i /videos/\(series_id)/\(videoName) -vframes 1 -q:v 20 /images/\(imageName) 2>/dev/null")
//                    ws.send(text: "\(series_id),4/10 TS Conversion ...")
//                    try shellOut(to: "ffmpeg -i /videos/\(series_id)/\(videoName) -codec: copy -start_number 0 -hls_time 10 -hls_list_size 0 -f hls /videos/\(series_id)/\(hlsName)")
                    ws.send(text: "\(series_id),6/12 Send Video to LB1")
                    try shellOut(to: "sshpass -p'fady123' scp /videos/\(series_id)/\(videoName) root@f.drmdn.app:/ssd/videos/\(series_id)/\(videoName)")
                    ws.send(text: "\(series_id),7/12 LB1 TS Conversion ...")
                    try shellOut(to: "sshpass -p'fady123' ssh root@f.drmdn.app \"ffmpeg -i /ssd/videos/\(series_id)/\(videoName) -codec: copy -start_number 0 -hls_time 10 -hls_list_size 0 -f hls /ssd/videos/\(series_id)/\(hlsName) && rm /ssd/videos/\(series_id)/\(videoName)\"")
                    ws.send(text: "\(series_id),8/12 Send Video to LB2")
                    try shellOut(to: "sshpass -p'fady123' scp /videos/\(series_id)/\(videoName) root@t.drmdn.app:/ssd/videos/\(series_id)/\(videoName)")
                    ws.send(text: "\(series_id),9/12 LB2 TS Conversion ...")
                    try shellOut(to: "sshpass -p'fady123' ssh root@t.drmdn.app \"ffmpeg -i /ssd/videos/\(series_id)/\(videoName) -codec: copy -start_number 0 -hls_time 10 -hls_list_size 0 -f hls /ssd/videos/\(series_id)/\(hlsName) && rm /ssd/videos/\(series_id)/\(videoName)\"")
                    ws.send(text: "\(series_id),10/12 Send Video to LB3")
                    try shellOut(to: "sshpass -p'fady123' scp /videos/\(series_id)/\(videoName) root@x.drmdn.app:/videos/\(series_id)/\(videoName)")
                    ws.send(text: "\(series_id),11/12 LB2 TS Conversion ...")
                    try shellOut(to: "sshpass -p'fady123' ssh root@x.drmdn.app \"ffmpeg -i /videos/\(series_id)/\(videoName) -codec: copy -start_number 0 -hls_time 10 -hls_list_size 0 -f hls /videos/\(series_id)/\(hlsName) && rm /videos/\(series_id)/\(videoName)\"")
                    ws.send(text: "\(series_id),12/12 Delete from DO")
                    try shellOut(to: "rm -rf /videos/\(series_id)/\(videoName)")
                    ws.send(text: "\(series_id),5 Saving to DB ...")
                    let newEpi = Episode(filename: hlsName, seriesID: Int(series_id)!, thumbnail: imageName, duration: episode_duration, order: Int(episode_id)!)
                    guard let newEpisode = try? newEpi.save(on: req) else { return }
                    ws.send(text: "\(series_id),Done ✅")
                    try Series.find(Int(series_id)!, on: req).map { ser in
                        if noti {
                            sendNoti(req: req, to: "\(series_id)", body: "\(ser!.title) : تم إضافة حلقة جديدة. ", badge: 1)
                        }
                    }
                    
                }catch {
                    print(error)
                    ws.send(text: "\(series_id),⛔️ Error : \n \(error)")
                    return
                }
            }
        }
    }
}

