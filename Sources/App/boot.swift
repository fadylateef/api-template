import Vapor
import FluentMySQL
import ShellOut

/// Called after your application has initialized.
public func boot(_ app: Application) throws {
    
    
    
    
    // Add WebSocket upgrade support to GET /echo
    wss.get("echo") { ws, req in

        // Add a new on text callback
        ws.onText { ws, text in
            let split = text.split(separator: ",")
            if split.count != 3 { return }
            guard let series_id = split.first else { return }
            let episode_id = split[1]
            print(series_id)
            guard let episode_link = split.last else { return }
            ws.send(text: "\(series_id),1/6 Downloading ... ")
            do {
                let videoName = "\(series_id)_\(episode_id).mp4"
                let imageName = "\(series_id)_\(episode_id).jpg"
                let hlsName = "\(series_id)_\(episode_id).m3u8"
                try shellOut(to: "youtube-dl -f mpd-3 \(episode_link) -o /videos/\(series_id)/\(videoName)")
                ws.send(text: "\(series_id),2/6 Duration ...")
                let episode_length = try shellOut(to: "mediainfo --Inform=\"General;%Duration%\" /videos/\(series_id)/\(videoName)")
                guard let epi_length = Int(episode_length) else { return }
                let episode_duration = epi_length / 60000
                ws.send(text: "\(series_id),3/6 TS Screenshot ...")
                try shellOut(to: "ffmpeg -ss 00:5:00 -i /videos/\(series_id)/\(videoName) -vframes 1 -q:v 20 /images/\(imageName)")
                ws.send(text: "\(series_id),4/6 TS Conversion ...")
                try shellOut(to: "ffmpeg -i /videos/\(series_id)/\(videoName) -codec: copy -start_number 0 -hls_time 10 -hls_list_size 0 -f hls /videos/\(series_id)/\(hlsName)")
                ws.send(text: "\(series_id),5/6 Saving to DB ...")
                let newEpi = Episode(filename: hlsName, seriesID: Int(series_id)!, thumbnail: imageName, duration: episode_duration, order: Int(episode_id)!)
                guard let newEpisode = try? newEpi.save(on: req) else { return }
                ws.send(text: "\(series_id),Done ✅")
                try Series.find(Int(series_id)!, on: req).map { ser in
                    sendNoti(req: req, to: "\(series_id)", body: "تم إضافة حلقة جديدة من \(ser?.title)", badge: 1)
                }
                
                
            }catch {
                print(error)
                ws.send(text: "\(series_id),⛔️ Error : \n \(error)")
                return
            }
        }
    }
}
