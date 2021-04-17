import Vapor
import FluentMySQL
import ShellOut
import SwiftSoup

var global_series : [Series] = []
var global_categories : [Category] = []

/// Called after your application has initialized.
public func boot(_ app: Application) throws {
    
    
    // Add WebSocket upgrade support to GET /echo
    
    let request = Request(using: app)
    try? Series.query(on: request).all().map {ser in
        global_series = ser
    }
    try? Category.query(on: request).all().map {cats in
        global_categories = cats
    }
    
    wss.get("echo") { ws, req in

        // Add a new on text callback
        ws.onText { ws, text in
            let split = text.split(separator: ",")
            if split.count != 3 { return }
            guard let series_id = split.first else { return }
            let episode_id = split[1]
            print(series_id)
            guard let episode_link = split.last else { return }
            ws.send(text: "\(series_id),1/10 Downloading ... ")
            do {
                let videoName = "\(series_id)_\(episode_id).mp4"
                let imageName = "\(series_id)_\(episode_id).jpg"
                let hlsName = "\(series_id)_\(episode_id).m3u8"
                try shellOut(to: "youtube-dl -f mpd-3 \(episode_link) -o /videos/\(series_id)/\(videoName)")
                ws.send(text: "\(series_id),2/10 Duration ...")
                let episode_length = try shellOut(to: "mediainfo --Inform=\"General;%Duration%\" /videos/\(series_id)/\(videoName)")
                guard let epi_length = Int(episode_length) else { return }
                let episode_duration = epi_length / 60000
                ws.send(text: "\(series_id),3/10 TS Screenshot ...")
                try shellOut(to: "ffmpeg -ss 00:5:00 -i /videos/\(series_id)/\(videoName) -vframes 1 -q:v 20 /images/\(imageName)")
                ws.send(text: "\(series_id),4/10 TS Conversion ...")
                try shellOut(to: "ffmpeg -i /videos/\(series_id)/\(videoName) -codec: copy -start_number 0 -hls_time 10 -hls_list_size 0 -f hls /videos/\(series_id)/\(hlsName)")
                ws.send(text: "\(series_id),5/10 Saving to DB ...")
                let newEpi = Episode(filename: hlsName, seriesID: Int(series_id)!, thumbnail: imageName, duration: episode_duration, order: Int(episode_id)!)
                guard let newEpisode = try? newEpi.save(on: req) else { return }
                ws.send(text: "\(series_id),6/10 Send Video to LB1")
                try shellOut(to: "sshpass -p'fady123' scp /videos/\(series_id)/\(videoName) root@185.101.107.142:/videos/\(series_id)/\(videoName)")
                ws.send(text: "\(series_id),7/10 LB1 TS Conversion ...")
                try shellOut(to: "sshpass -p'fady123' ssh root@185.101.107.142 \"ffmpeg -i /videos/\(series_id)/\(videoName) -codec: copy -start_number 0 -hls_time 10 -hls_list_size 0 -f hls /videos/\(series_id)/\(hlsName) && rm /videos/\(series_id)/\(videoName)\"")
                ws.send(text: "\(series_id),8/10 Send Video to LB2")
                try shellOut(to: "sshpass -p'fady123' scp /videos/\(series_id)/\(videoName) root@89.41.180.90:/videos/\(series_id)/\(videoName)")
                ws.send(text: "\(series_id),9/10 LB2 TS Conversion ...")
                try shellOut(to: "sshpass -p'fady123' ssh root@89.41.180.90 \"ffmpeg -i /videos/\(series_id)/\(videoName) -codec: copy -start_number 0 -hls_time 10 -hls_list_size 0 -f hls /videos/\(series_id)/\(hlsName) && rm /videos/\(series_id)/\(videoName)\"")
                ws.send(text: "\(series_id),Done ✅")
                try Series.find(Int(series_id)!, on: req).map { ser in
                    sendNoti(req: req, to: "\(series_id)", body: "\(ser!.title) : تم إضافة حلقة جديدة. ", badge: 1)
                }
                
            }catch {
                print(error)
                ws.send(text: "\(series_id),⛔️ Error : \n \(error)")
                return
            }
        }
    }
}
