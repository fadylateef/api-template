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
    
    var epis = epi_list.split(separator: ",")
//    for epi in epis {
//        print(epi)
//        var epi1 = epi.replacingOccurrences(of: ".m3u8", with: "").split(separator: "_")
//        var image = epi.replacingOccurrences(of: "m3u8", with: "jpg")
//
//
//    }
    
    var durations = duration_list.split(separator: ",")
    
    for dur in durations {
        let dura = dur.split(separator: "-").first!
        print(dura)
        let len = Int("\(dura)")! / 60000
        let fl = dur.split(separator: "-").last
        let flname = fl!.split(separator: "/").last!
        try? Episode.query(on: request).filter(\.filename == "\(flname)").all().map { ep in
            print(ep)
            if !ep.isEmpty {
                var nw = ep.first!
                nw.duration = len
                try? nw.save(on: request)
            }
        }
    }
    
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
                    let hlsName = "\(series_id)_\(episode_id).m3u8"
                    try shellOut(to: "youtube-dl -f mpd-3 \(episode_link) -o /videos/\(series_id)/\(videoName)")
                    ws.send(text: "\(series_id),2/10 Duration ...")
                    let episode_length = try shellOut(to: "mediainfo --Inform=\"General;%Duration%\" /videos/\(series_id)/\(videoName)")
                    guard let epi_length = Int(episode_length) else { return }
                    let episode_duration = epi_length / 60000
                    ws.send(text: "\(series_id),3/10 TS Screenshot ...")
                    try shellOut(to: "ffmpeg -ss 00:5:00 -i /videos/\(series_id)/\(videoName) -vframes 1 -q:v 20 /images/\(imageName)")
//                    ws.send(text: "\(series_id),4/10 TS Conversion ...")
//                    try shellOut(to: "ffmpeg -i /videos/\(series_id)/\(videoName) -codec: copy -start_number 0 -hls_time 10 -hls_list_size 0 -f hls /videos/\(series_id)/\(hlsName)")
                    ws.send(text: "\(series_id),5/10 Saving to DB ...")
                    let newEpi = Episode(filename: hlsName, seriesID: Int(series_id)!, thumbnail: imageName, duration: episode_duration, order: Int(episode_id)!)
                    guard let newEpisode = try? newEpi.save(on: req) else { return }
                    ws.send(text: "\(series_id),6/10 Send Video to LB1")
                    try shellOut(to: "sshpass -p'fady123' scp /videos/\(series_id)/\(videoName) root@f.drmdn.app:/ssd/videos/\(series_id)/\(videoName)")
                    ws.send(text: "\(series_id),7/10 LB1 TS Conversion ...")
                    try shellOut(to: "sshpass -p'fady123' ssh root@f.drmdn.app \"ffmpeg -i /ssd/videos/\(series_id)/\(videoName) -codec: copy -start_number 0 -hls_time 10 -hls_list_size 0 -f hls /ssd/videos/\(series_id)/\(hlsName) && rm /ssd/videos/\(series_id)/\(videoName)\"")
                    ws.send(text: "\(series_id),8/10 Send Video to LB2")
                    try shellOut(to: "sshpass -p'fady123' scp /videos/\(series_id)/\(videoName) root@t.drmdn.app:/videos/\(series_id)/\(videoName)")
                    ws.send(text: "\(series_id),9/10 LB2 TS Conversion ...")
                    try shellOut(to: "sshpass -p'fady123' ssh root@t.drmdn.app \"ffmpeg -i /videos/\(series_id)/\(videoName) -codec: copy -start_number 0 -hls_time 10 -hls_list_size 0 -f hls /videos/\(series_id)/\(hlsName) && rm /videos/\(series_id)/\(videoName)\"")
                    ws.send(text: "\(series_id),10/10 Delete from DO")
                    try shellOut(to: "rm -rf /videos/\(series_id)/\(videoName)")
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
}







var epi_list = "1_1.m3u8,1_2.m3u8,1_3.m3u8,1_4.m3u8,1_5.m3u8,1_6.m3u8,1_7.m3u8,10_1.m3u8,10_2.m3u8,10_3.m3u8,10_4.m3u8,10_5.m3u8,10_6.m3u8,10_7.m3u8,100_1.m3u8,100_2.m3u8,100_3.m3u8,100_4.m3u8,100_5.m3u8,100_6.m3u8,100_7.m3u8,102_1.m3u8,102_2.m3u8,102_3.m3u8,102_4.m3u8,102_5.m3u8,102_6.m3u8,102_7.m3u8,103_1.m3u8,103_2.m3u8,103_3.m3u8,103_4.m3u8,103_5.m3u8,103_6.m3u8,103_7.m3u8,106_1.m3u8,106_2.m3u8,106_3.m3u8,106_4.m3u8,106_5.m3u8,106_6.m3u8,106_7.m3u8,106_1.m3u8,106_2.m3u8,106_3.m3u8,106_4.m3u8,106_5.m3u8,106_6.m3u8,106_7.m3u8,107_1.m3u8,107_2.m3u8,107_3.m3u8,107_4.m3u8,107_5.m3u8,107_6.m3u8,107_7.m3u8,107_8.m3u8,108_1.m3u8,108_2.m3u8,108_3.m3u8,108_4.m3u8,108_5.m3u8,108_6.m3u8,108_7.m3u8,109_1.m3u8,109_2.m3u8,109_3.m3u8,109_4.m3u8,109_5.m3u8,109_6.m3u8,109_7.m3u8,109_8.m3u8,11_1.m3u8,11_2.m3u8,11_3.m3u8,11_4.m3u8,11_5.m3u8,11_6.m3u8,11_7.m3u8,110_1.m3u8,110_2.m3u8,110_3.m3u8,110_4.m3u8,110_5.m3u8,110_6.m3u8,110_7.m3u8,110_8.m3u8,111_1.m3u8,111_2.m3u8,111_3.m3u8,111_4.m3u8,111_5.m3u8,111_6.m3u8,111_7.m3u8,111_8.m3u8,112_1.m3u8,112_2.m3u8,112_3.m3u8,112_4.m3u8,112_5.m3u8,112_6.m3u8,112_7.m3u8,112_8.m3u8,113_1.m3u8,113_2.m3u8,116_1.m3u8,116_2.m3u8,116_3.m3u8,116_4.m3u8,116_5.m3u8,116_6.m3u8,116_7.m3u8,118_1.m3u8,118_2.m3u8,118_3.m3u8,118_4.m3u8,118_5.m3u8,118_6.m3u8,118_7.m3u8,119_1.m3u8,119_2.m3u8,12_1.m3u8,12_2.m3u8,12_3.m3u8,12_4.m3u8,12_5.m3u8,12_6.m3u8,12_7.m3u8,120_1.m3u8,120_2.m3u8,120_3.m3u8,120_4.m3u8,120_5.m3u8,120_6.m3u8,120_7.m3u8,122_1.m3u8,122_2.m3u8,122_3.m3u8,122_4.m3u8,122_5.m3u8,122_6.m3u8,122_7.m3u8,122_8.m3u8,122_9.m3u8,123_1.m3u8,123_2.m3u8,123_3.m3u8,123_4.m3u8,123_5.m3u8,123_6.m3u8,123_7.m3u8,124_1.m3u8,124_2.m3u8,124_3.m3u8,124_4.m3u8,124_5.m3u8,124_6.m3u8,124_7.m3u8,125_1.m3u8,125_2.m3u8,125_3.m3u8,125_4.m3u8,125_5.m3u8,125_6.m3u8,125_7.m3u8,126_1.m3u8,126_2.m3u8,126_3.m3u8,126_4.m3u8,126_5.m3u8,126_6.m3u8,126_7.m3u8,127_1.m3u8,127_2.m3u8,127_3.m3u8,127_4.m3u8,127_5.m3u8,127_6.m3u8,127_7.m3u8,128_1.m3u8,128_2.m3u8,128_3.m3u8,128_4.m3u8,128_5.m3u8,128_6.m3u8,128_7.m3u8,129_1.m3u8,129_2.m3u8,129_3.m3u8,129_4.m3u8,129_5.m3u8,129_6.m3u8,129_7.m3u8,13_1.m3u8,13_2.m3u8,13_3.m3u8,13_4.m3u8,13_5.m3u8,13_6.m3u8,13_7.m3u8,130_1.m3u8,130_2.m3u8,130_3.m3u8,130_4.m3u8,130_5.m3u8,130_6.m3u8,130_7.m3u8,131_1.m3u8,131_2.m3u8,131_3.m3u8,131_4.m3u8,131_5.m3u8,131_6.m3u8,131_7.m3u8,132_1.m3u8,132_2.m3u8,132_3.m3u8,132_4.m3u8,132_5.m3u8,132_6.m3u8,132_7.m3u8,133_1.m3u8,133_2.m3u8,133_3.m3u8,133_4.m3u8,133_5.m3u8,133_6.m3u8,133_7.m3u8,134_1.m3u8,134_2.m3u8,134_3.m3u8,134_4.m3u8,135_1.m3u8,135_2.m3u8,135_3.m3u8,135_4.m3u8,135_5.m3u8,135_6.m3u8,135_7.m3u8,136_1.m3u8,136_2.m3u8,136_3.m3u8,136_4.m3u8,136_5.m3u8,136_6.m3u8,136_7.m3u8,137_1.m3u8,137_2.m3u8,137_3.m3u8,137_4.m3u8,137_5.m3u8,137_6.m3u8,137_7.m3u8,138_1.m3u8,138_2.m3u8,138_3.m3u8,138_4.m3u8,138_5.m3u8,138_6.m3u8,138_7.m3u8,139_1.m3u8,139_2.m3u8,139_3.m3u8,139_4.m3u8,139_5.m3u8,139_6.m3u8,139_7.m3u8,14_1.m3u8,14_2.m3u8,14_3.m3u8,14_4.m3u8,14_5.m3u8,14_6.m3u8,14_7.m3u8,14_8.m3u8,140_1.m3u8,140_2.m3u8,140_3.m3u8,140_4.m3u8,140_5.m3u8,140_6.m3u8,140_7.m3u8,141_1.m3u8,141_2.m3u8,141_3.m3u8,141_4.m3u8,141_5.m3u8,141_6.m3u8,141_7.m3u8,15_1.m3u8,15_2.m3u8,15_3.m3u8,15_4.m3u8,15_5.m3u8,15_6.m3u8,15_7.m3u8,15_8.m3u8,15_9.m3u8,17_1.m3u8,17_2.m3u8,17_3.m3u8,17_4.m3u8,17_5.m3u8,17_6.m3u8,17_7.m3u8,17_8.m3u8,18_1.m3u8,18_2.m3u8,18_3.m3u8,18_4.m3u8,18_5.m3u8,18_6.m3u8,18_7.m3u8,18_8.m3u8,19_1.m3u8,19_2.m3u8,19_3.m3u8,19_4.m3u8,19_5.m3u8,19_6.m3u8,19_7.m3u8,2_1.m3u8,2_2.m3u8,2_3.m3u8,2_4.m3u8,2_5.m3u8,2_6.m3u8,2_7.m3u8,20_1.m3u8,20_2.m3u8,20_3.m3u8,20_4.m3u8,20_5.m3u8,20_6.m3u8,20_7.m3u8,21_1.m3u8,21_2.m3u8,21_3.m3u8,21_4.m3u8,21_5.m3u8,21_6.m3u8,21_7.m3u8,21_8.m3u8,22_1.m3u8,22_2.m3u8,22_3.m3u8,22_4.m3u8,22_5.m3u8,22_6.m3u8,22_7.m3u8,22_8.m3u8,23_1.m3u8,23_2.m3u8,23_3.m3u8,23_4.m3u8,23_5.m3u8,23_6.m3u8,23_7.m3u8,23_8.m3u8,23_9.m3u8,24_1.m3u8,24_2.m3u8,24_3.m3u8,24_4.m3u8,24_5.m3u8,24_6.m3u8,24_7.m3u8,25_1.m3u8,25_2.m3u8,25_3.m3u8,25_4.m3u8,25_5.m3u8,25_6.m3u8,26_1.m3u8,26_2.m3u8,26_3.m3u8,26_4.m3u8,26_5.m3u8,26_6.m3u8,26_7.m3u8,26_8.m3u8,27_1.m3u8,27_2.m3u8,27_3.m3u8,27_4.m3u8,27_5.m3u8,27_6.m3u8,27_7.m3u8,27_8.m3u8,28_1.m3u8,28_2.m3u8,28_3.m3u8,28_4.m3u8,28_5.m3u8,28_6.m3u8,28_7.m3u8,29_1.m3u8,29_2.m3u8,29_3.m3u8,29_4.m3u8,29_5.m3u8,29_6.m3u8,29_7.m3u8,29_8.m3u8,3_1.m3u8,3_2.m3u8,3_3.m3u8,3_4.m3u8,3_5.m3u8,3_6.m3u8,3_7.m3u8,30_1.m3u8,30_2.m3u8,30_3.m3u8,30_4.m3u8,30_5.m3u8,30_6.m3u8,30_7.m3u8,31_1.m3u8,31_2.m3u8,31_3.m3u8,31_4.m3u8,31_5.m3u8,31_6.m3u8,31_7.m3u8,31_8.m3u8,32_1.m3u8,32_2.m3u8,32_3.m3u8,32_4.m3u8,32_5.m3u8,32_6.m3u8,32_7.m3u8,33_1.m3u8,33_2.m3u8,33_3.m3u8,33_4.m3u8,33_5.m3u8,33_6.m3u8,33_7.m3u8,34_1.m3u8,34_2.m3u8,34_3.m3u8,34_4.m3u8,34_5.m3u8,34_6.m3u8,34_7.m3u8,35_1.m3u8,35_2.m3u8,35_3.m3u8,35_4.m3u8,35_5.m3u8,35_6.m3u8,35_7.m3u8,36_1.m3u8,36_2.m3u8,36_3.m3u8,36_4.m3u8,36_5.m3u8,36_6.m3u8,36_7.m3u8,37_1.m3u8,37_2.m3u8,37_3.m3u8,37_4.m3u8,37_5.m3u8,37_6.m3u8,37_7.m3u8,38_1.m3u8,38_2.m3u8,38_3.m3u8,38_4.m3u8,38_5.m3u8,38_6.m3u8,38_7.m3u8,4_1.m3u8,4_2.m3u8,4_3.m3u8,4_4.m3u8,4_5.m3u8,4_6.m3u8,4_7.m3u8,5_1.m3u8,5_2.m3u8,5_3.m3u8,5_4.m3u8,5_5.m3u8,5_6.m3u8,5_7.m3u8,6_1.m3u8,6_2.m3u8,6_3.m3u8,6_4.m3u8,6_5.m3u8,6_6.m3u8,6_7.m3u8,7_1.m3u8,7_2.m3u8,7_3.m3u8,7_4.m3u8,7_5.m3u8,7_6.m3u8,7_7.m3u8,8_1.m3u8,8_2.m3u8,8_3.m3u8,8_4.m3u8,8_5.m3u8,8_6.m3u8,8_7.m3u8,8_8.m3u8,9_1.m3u8,9_2.m3u8,9_3.m3u8,9_4.m3u8,9_5.m3u8,9_6.m3u8,9_7.m3u8,93_1.m3u8,93_2.m3u8,93_3.m3u8,93_4.m3u8,93_5.m3u8,93_6.m3u8,93_7.m3u8,93_8.m3u8,94_1.m3u8,94_2.m3u8,94_3.m3u8,94_4.m3u8,94_5.m3u8,94_6.m3u8,94_7.m3u8,94_8.m3u8,96_1.m3u8,96_2.m3u8,96_3.m3u8,96_4.m3u8,96_5.m3u8,96_6.m3u8,96_7.m3u8,97_1.m3u8,97_2.m3u8,97_3.m3u8,97_4.m3u8,97_5.m3u8,97_6.m3u8,97_7.m3u8,97_8.m3u8,99_1.m3u8,99_2.m3u8,99_3.m3u8,99_4.m3u8,99_5.m3u8,99_6.m3u8,99_7.m3u8"



    var duration_list = "3938966-/ssd/videos/1/1_1.m3u8,2600666-/ssd/videos/1/1_2.m3u8,2919212-/ssd/videos/1/1_3.m3u8,2843686-/ssd/videos/1/1_4.m3u8,2083898-/ssd/videos/1/1_5.m3u8,2216346-/ssd/videos/1/1_6.m3u8,2110886-/ssd/videos/1/1_7.m3u8,3255066-/ssd/videos/10/10_1.m3u8,2413505-/ssd/videos/10/10_2.m3u8,1878566-/ssd/videos/10/10_3.m3u8,1932326-/ssd/videos/10/10_4.m3u8,2099366-/ssd/videos/10/10_5.m3u8,2171166-/ssd/videos/10/10_6.m3u8,2260253-/ssd/videos/10/10_7.m3u8,2319464-/ssd/videos/100/100_1.m3u8,2154277-/ssd/videos/100/100_2.m3u8,1792650-/ssd/videos/100/100_3.m3u8,1801984-/ssd/videos/100/100_4.m3u8,1787472-/ssd/videos/100/100_5.m3u8,1838068-/ssd/videos/100/100_6.m3u8,1936103-/ssd/videos/100/100_7.m3u8,2082006-/ssd/videos/102/102_1.m3u8,2173364-/ssd/videos/102/102_2.m3u8,2206766-/ssd/videos/102/102_3.m3u8,2183506-/ssd/videos/102/102_4.m3u8,2164866-/ssd/videos/102/102_5.m3u8,1957406-/ssd/videos/102/102_6.m3u8,2292204-/ssd/videos/102/102_7.m3u8,2302165-/ssd/videos/103/103_1.m3u8,2319348-/ssd/videos/103/103_2.m3u8,2331426-/ssd/videos/103/103_3.m3u8,2323458-/ssd/videos/103/103_4.m3u8,2313886-/ssd/videos/103/103_5.m3u8,2344007-/ssd/videos/103/103_6.m3u8,2317351-/ssd/videos/103/103_7.m3u8,2457026-/ssd/videos/106/106_1.m3u8,2060538-/ssd/videos/106/106_2.m3u8,2426206-/ssd/videos/106/106_3.m3u8,2454606-/ssd/videos/106/106_4.m3u8,2465610-/ssd/videos/106/106_5.m3u8,2031420-/ssd/videos/106/106_6.m3u8,2448006-/ssd/videos/106/106_7.m3u8,2604001-/ssd/videos/107/107_1.m3u8,2547666-/ssd/videos/107/107_2.m3u8,2593297-/ssd/videos/107/107_3.m3u8,2589466-/ssd/videos/107/107_4.m3u8,2602515-/ssd/videos/107/107_5.m3u8,2620209-/ssd/videos/107/107_6.m3u8,2638080-/ssd/videos/107/107_7.m3u8,2603086-/ssd/videos/107/107_8.m3u8,2262306-/ssd/videos/108/108_1.m3u8,2547600-/ssd/videos/108/108_2.m3u8,2545696-/ssd/videos/108/108_3.m3u8,2507151-/ssd/videos/108/108_4.m3u8,2197926-/ssd/videos/108/108_5.m3u8,2598074-/ssd/videos/108/108_6.m3u8,2608158-/ssd/videos/108/108_7.m3u8,2316966-/ssd/videos/109/109_1.m3u8,2332886-/ssd/videos/109/109_2.m3u8,2309726-/ssd/videos/109/109_3.m3u8,2346366-/ssd/videos/109/109_4.m3u8,2281706-/ssd/videos/109/109_5.m3u8,2363846-/ssd/videos/109/109_6.m3u8,2308506-/ssd/videos/109/109_7.m3u8,2290166-/ssd/videos/109/109_8.m3u8,1786963-/ssd/videos/11/11_1.m3u8,2014966-/ssd/videos/11/11_2.m3u8,2155068-/ssd/videos/11/11_3.m3u8,1899067-/ssd/videos/11/11_4.m3u8,2051826-/ssd/videos/11/11_5.m3u8,1974286-/ssd/videos/11/11_6.m3u8,1977922-/ssd/videos/11/11_7.m3u8,3444686-/ssd/videos/110/110_1.m3u8,2753786-/ssd/videos/110/110_2.m3u8,3489610-/ssd/videos/110/110_3.m3u8,3083566-/ssd/videos/110/110_4.m3u8,3068266-/ssd/videos/110/110_5.m3u8,3122006-/ssd/videos/110/110_6.m3u8,2949026-/ssd/videos/110/110_7.m3u8,3036786-/ssd/videos/110/110_8.m3u8,479386-/ssd/videos/111/111_1.m3u8,476286-/ssd/videos/111/111_2.m3u8,476286-/ssd/videos/111/111_3.m3u8,490886-/ssd/videos/111/111_4.m3u8,587606-/ssd/videos/111/111_5.m3u8,406386-/ssd/videos/111/111_6.m3u8,519680-/ssd/videos/111/111_7.m3u8,565286-/ssd/videos/111/111_8.m3u8,2386506-/ssd/videos/112/112_1.m3u8,1962566-/ssd/videos/112/112_2.m3u8,1710288-/ssd/videos/112/112_3.m3u8,1812506-/ssd/videos/112/112_4.m3u8,1557846-/ssd/videos/112/112_5.m3u8,1802946-/ssd/videos/112/112_6.m3u8,1679708-/ssd/videos/112/112_7.m3u8,1480806-/ssd/videos/112/112_8.m3u8,1136245-/ssd/videos/113/113_1.m3u8,1365826-/ssd/videos/113/113_2.m3u8,1505628-/ssd/videos/116/116_1.m3u8,1591966-/ssd/videos/116/116_2.m3u8,1556026-/ssd/videos/116/116_3.m3u8,1508606-/ssd/videos/116/116_4.m3u8,1544080-/ssd/videos/116/116_5.m3u8,1566394-/ssd/videos/116/116_6.m3u8,1593086-/ssd/videos/116/116_7.m3u8,2320826-/ssd/videos/118/118_1.m3u8,2190406-/ssd/videos/118/118_2.m3u8,2097667-/ssd/videos/118/118_3.m3u8,2438386-/ssd/videos/118/118_4.m3u8,2327326-/ssd/videos/118/118_5.m3u8,2204326-/ssd/videos/118/118_6.m3u8,2302006-/ssd/videos/118/118_7.m3u8,2319464-/ssd/videos/119/119_1.m3u8,2154277-/ssd/videos/119/119_2.m3u8,1913626-/ssd/videos/12/12_1.m3u8,1519526-/ssd/videos/12/12_2.m3u8,1613926-/ssd/videos/12/12_3.m3u8,1538252-/ssd/videos/12/12_4.m3u8,2008166-/ssd/videos/12/12_5.m3u8,1718086-/ssd/videos/12/12_6.m3u8,1910909-/ssd/videos/12/12_7.m3u8,886151-/ssd/videos/120/120_1.m3u8,798144-/ssd/videos/120/120_2.m3u8,865926-/ssd/videos/120/120_3.m3u8,1005029-/ssd/videos/120/120_4.m3u8,965926-/ssd/videos/120/120_5.m3u8,997726-/ssd/videos/120/120_6.m3u8,978604-/ssd/videos/120/120_7.m3u8,867946-/ssd/videos/122/122_1.m3u8,1014906-/ssd/videos/122/122_2.m3u8,917926-/ssd/videos/122/122_3.m3u8,847626-/ssd/videos/122/122_4.m3u8,828813-/ssd/videos/122/122_5.m3u8,900191-/ssd/videos/122/122_6.m3u8,942286-/ssd/videos/122/122_7.m3u8,891026-/ssd/videos/122/122_8.m3u8,778890-/ssd/videos/122/122_9.m3u8,1504490-/ssd/videos/123/123_1.m3u8,1359806-/ssd/videos/123/123_2.m3u8,1513477-/ssd/videos/123/123_3.m3u8,1411006-/ssd/videos/123/123_4.m3u8,1514036-/ssd/videos/123/123_5.m3u8,1293188-/ssd/videos/123/123_6.m3u8,1644779-/ssd/videos/123/123_7.m3u8,2084316-/ssd/videos/124/124_1.m3u8,2110020-/ssd/videos/124/124_2.m3u8,2057914-/ssd/videos/124/124_3.m3u8,2143271-/ssd/videos/124/124_4.m3u8,2106467-/ssd/videos/124/124_5.m3u8,2075190-/ssd/videos/124/124_6.m3u8,2115662-/ssd/videos/124/124_7.m3u8,2366746-/ssd/videos/125/125_1.m3u8,2382555-/ssd/videos/125/125_2.m3u8,2416186-/ssd/videos/125/125_3.m3u8,2398126-/ssd/videos/125/125_4.m3u8,2363186-/ssd/videos/125/125_5.m3u8,2432326-/ssd/videos/125/125_6.m3u8,2343686-/ssd/videos/125/125_7.m3u8,2405099-/ssd/videos/126/126_1.m3u8,2280385-/ssd/videos/126/126_2.m3u8,2185369-/ssd/videos/126/126_3.m3u8,2377839-/ssd/videos/126/126_4.m3u8,2247645-/ssd/videos/126/126_5.m3u8,2127435-/ssd/videos/126/126_6.m3u8,1999493-/ssd/videos/126/126_7.m3u8,2373726-/ssd/videos/127/127_1.m3u8,2401186-/ssd/videos/127/127_2.m3u8,2369486-/ssd/videos/127/127_3.m3u8,2373166-/ssd/videos/127/127_4.m3u8,2371686-/ssd/videos/127/127_5.m3u8,2377366-/ssd/videos/127/127_6.m3u8,2372946-/ssd/videos/127/127_7.m3u8,2161336-/ssd/videos/128/128_1.m3u8,2138302-/ssd/videos/128/128_2.m3u8,2144943-/ssd/videos/128/128_3.m3u8,2156158-/ssd/videos/128/128_4.m3u8,2214109-/ssd/videos/128/128_5.m3u8,2174130-/ssd/videos/128/128_6.m3u8,2135214-/ssd/videos/128/128_7.m3u8,2339693-/ssd/videos/129/129_1.m3u8,2445293-/ssd/videos/129/129_2.m3u8,2274023-/ssd/videos/129/129_3.m3u8,2252806-/ssd/videos/129/129_4.m3u8,2355482-/ssd/videos/129/129_5.m3u8,2119331-/ssd/videos/129/129_6.m3u8,2590408-/ssd/videos/129/129_7.m3u8,2068766-/ssd/videos/13/13_1.m3u8,1828186-/ssd/videos/13/13_2.m3u8,1732806-/ssd/videos/13/13_3.m3u8,1667846-/ssd/videos/13/13_4.m3u8,1749926-/ssd/videos/13/13_5.m3u8,2077446-/ssd/videos/13/13_6.m3u8,2140706-/ssd/videos/13/13_7.m3u8,2520788-/ssd/videos/130/130_1.m3u8,2704053-/ssd/videos/130/130_2.m3u8,2706076-/ssd/videos/130/130_3.m3u8,2669070-/ssd/videos/130/130_4.m3u8,2570054-/ssd/videos/130/130_5.m3u8,2615077-/ssd/videos/130/130_6.m3u8,2613067-/ssd/videos/130/130_7.m3u8,2515673-/ssd/videos/131/131_1.m3u8,2625486-/ssd/videos/131/131_2.m3u8,2477246-/ssd/videos/131/131_3.m3u8,2591006-/ssd/videos/131/131_4.m3u8,2550046-/ssd/videos/131/131_5.m3u8,2438286-/ssd/videos/131/131_6.m3u8,2519388-/ssd/videos/131/131_7.m3u8,2455370-/ssd/videos/132/132_1.m3u8,2461338-/ssd/videos/132/132_2.m3u8,2454743-/ssd/videos/132/132_3.m3u8,2455765-/ssd/videos/132/132_4.m3u8,2464126-/ssd/videos/132/132_5.m3u8,2455406-/ssd/videos/132/132_6.m3u8,2463103-/ssd/videos/132/132_7.m3u8,1789004-/ssd/videos/133/133_1.m3u8,1490628-/ssd/videos/133/133_2.m3u8,1511686-/ssd/videos/133/133_3.m3u8,1472480-/ssd/videos/133/133_4.m3u8,1426886-/ssd/videos/133/133_5.m3u8,1455846-/ssd/videos/133/133_6.m3u8,1415511-/ssd/videos/133/133_7.m3u8,2457019-/ssd/videos/134/134_1.m3u8,2060538-/ssd/videos/134/134_2.m3u8,2426206-/ssd/videos/134/134_3.m3u8,2454606-/ssd/videos/134/134_4.m3u8,2095566-/ssd/videos/135/135_1.m3u8,2213106-/ssd/videos/135/135_2.m3u8,2336006-/ssd/videos/135/135_3.m3u8,2306763-/ssd/videos/135/135_4.m3u8,2389926-/ssd/videos/135/135_5.m3u8,2491326-/ssd/videos/135/135_6.m3u8,2196186-/ssd/videos/135/135_7.m3u8,2892566-/ssd/videos/136/136_1.m3u8,3054526-/ssd/videos/136/136_2.m3u8,2767186-/ssd/videos/136/136_3.m3u8,2741046-/ssd/videos/136/136_4.m3u8,3182480-/ssd/videos/136/136_5.m3u8,2373446-/ssd/videos/136/136_6.m3u8,2777733-/ssd/videos/136/136_7.m3u8,1687812-/ssd/videos/137/137_1.m3u8,1642846-/ssd/videos/137/137_2.m3u8,1617926-/ssd/videos/137/137_3.m3u8,1644826-/ssd/videos/137/137_4.m3u8,1573430-/ssd/videos/137/137_5.m3u8,1524459-/ssd/videos/137/137_6.m3u8,1623330-/ssd/videos/137/137_7.m3u8,588090-/ssd/videos/138/138_1.m3u8,743990-/ssd/videos/138/138_2.m3u8,747990-/ssd/videos/138/138_3.m3u8,663990-/ssd/videos/138/138_4.m3u8,655990-/ssd/videos/138/138_5.m3u8,775990-/ssd/videos/138/138_6.m3u8,707990-/ssd/videos/138/138_7.m3u8,2452006-/ssd/videos/139/139_1.m3u8,2262018-/ssd/videos/139/139_2.m3u8,2486369-/ssd/videos/139/139_3.m3u8,2524009-/ssd/videos/139/139_4.m3u8,2496423-/ssd/videos/139/139_5.m3u8,2470185-/ssd/videos/139/139_6.m3u8,2559187-/ssd/videos/139/139_7.m3u8,2529906-/ssd/videos/14/14_1.m3u8,1688671-/ssd/videos/14/14_2.m3u8,1705343-/ssd/videos/14/14_3.m3u8,1828346-/ssd/videos/14/14_4.m3u8,1969466-/ssd/videos/14/14_5.m3u8,2124186-/ssd/videos/14/14_6.m3u8,2139231-/ssd/videos/14/14_7.m3u8,2017626-/ssd/videos/14/14_8.m3u8,2750146-/ssd/videos/140/140_1.m3u8,2738654-/ssd/videos/140/140_2.m3u8,2791886-/ssd/videos/140/140_3.m3u8,2781666-/ssd/videos/140/140_4.m3u8,2768846-/ssd/videos/140/140_5.m3u8,2742346-/ssd/videos/140/140_6.m3u8,2695466-/ssd/videos/140/140_7.m3u8,1693086-/ssd/videos/141/141_1.m3u8,1798826-/ssd/videos/141/141_2.m3u8,1756966-/ssd/videos/141/141_3.m3u8,1758086-/ssd/videos/141/141_4.m3u8,1735286-/ssd/videos/141/141_5.m3u8,1385126-/ssd/videos/141/141_6.m3u8,1733926-/ssd/videos/141/141_7.m3u8,2744486-/ssd/videos/15/15_1.m3u8,2191206-/ssd/videos/15/15_2.m3u8,1624986-/ssd/videos/15/15_3.m3u8,1846886-/ssd/videos/15/15_4.m3u8,1711526-/ssd/videos/15/15_5.m3u8,1622266-/ssd/videos/15/15_6.m3u8,1766434-/ssd/videos/15/15_7.m3u8,2147366-/ssd/videos/15/15_8.m3u8,1718415-/ssd/videos/15/15_9.m3u8,2474326-/ssd/videos/17/17_1.m3u8,2018246-/ssd/videos/17/17_2.m3u8,2105126-/ssd/videos/17/17_3.m3u8,1746886-/ssd/videos/17/17_4.m3u8,1701606-/ssd/videos/17/17_5.m3u8,1943254-/ssd/videos/17/17_6.m3u8,2255826-/ssd/videos/17/17_7.m3u8,2033673-/ssd/videos/17/17_8.m3u8,2204107-/ssd/videos/18/18_1.m3u8,2352726-/ssd/videos/18/18_2.m3u8,1785475-/ssd/videos/18/18_3.m3u8,1818266-/ssd/videos/18/18_4.m3u8,1796026-/ssd/videos/18/18_5.m3u8,1961018-/ssd/videos/18/18_6.m3u8,1960986-/ssd/videos/18/18_7.m3u8,2427626-/ssd/videos/18/18_8.m3u8,2802986-/ssd/videos/19/19_1.m3u8,2035846-/ssd/videos/19/19_2.m3u8,1916686-/ssd/videos/19/19_3.m3u8,2095206-/ssd/videos/19/19_4.m3u8,2084524-/ssd/videos/19/19_5.m3u8,1801466-/ssd/videos/19/19_6.m3u8,2188726-/ssd/videos/19/19_7.m3u8,2132567-/ssd/videos/2/2_1.m3u8,1594106-/ssd/videos/2/2_2.m3u8,2004646-/ssd/videos/2/2_3.m3u8,1814407-/ssd/videos/2/2_4.m3u8,1738720-/ssd/videos/2/2_5.m3u8,2263906-/ssd/videos/2/2_6.m3u8,1862635-/ssd/videos/2/2_7.m3u8,2327446-/ssd/videos/20/20_1.m3u8,2315192-/ssd/videos/20/20_2.m3u8,2331190-/ssd/videos/20/20_3.m3u8,1942406-/ssd/videos/20/20_4.m3u8,2327219-/ssd/videos/20/20_5.m3u8,1968026-/ssd/videos/20/20_6.m3u8,2322706-/ssd/videos/20/20_7.m3u8,2858126-/ssd/videos/21/21_1.m3u8,2259046-/ssd/videos/21/21_2.m3u8,1813786-/ssd/videos/21/21_3.m3u8,1656186-/ssd/videos/21/21_4.m3u8,1659553-/ssd/videos/21/21_5.m3u8,1747557-/ssd/videos/21/21_6.m3u8,2078806-/ssd/videos/21/21_7.m3u8,1805286-/ssd/videos/21/21_8.m3u8,2394790-/ssd/videos/22/22_1.m3u8,2622601-/ssd/videos/22/22_2.m3u8,1899090-/ssd/videos/22/22_3.m3u8,2125995-/ssd/videos/22/22_4.m3u8,2134563-/ssd/videos/22/22_5.m3u8,2150632-/ssd/videos/22/22_6.m3u8,2204107-/ssd/videos/22/22_7.m3u8,2106235-/ssd/videos/22/22_8.m3u8,2099086-/ssd/videos/23/23_1.m3u8,2420766-/ssd/videos/23/23_2.m3u8,1721945-/ssd/videos/23/23_3.m3u8,2208326-/ssd/videos/23/23_4.m3u8,1749906-/ssd/videos/23/23_5.m3u8,2508986-/ssd/videos/23/23_6.m3u8,2326314-/ssd/videos/23/23_7.m3u8,2574826-/ssd/videos/23/23_8.m3u8,2136346-/ssd/videos/23/23_9.m3u8,2483055-/ssd/videos/24/24_1.m3u8,2497073-/ssd/videos/24/24_2.m3u8,2553054-/ssd/videos/24/24_3.m3u8,2481055-/ssd/videos/24/24_4.m3u8,2496055-/ssd/videos/24/24_5.m3u8,2524055-/ssd/videos/24/24_6.m3u8,2524071-/ssd/videos/24/24_7.m3u8,2524906-/ssd/videos/25/25_1.m3u8,2513699-/ssd/videos/25/25_2.m3u8,2220570-/ssd/videos/25/25_3.m3u8,2501446-/ssd/videos/25/25_4.m3u8,2501499-/ssd/videos/25/25_5.m3u8,2136793-/ssd/videos/25/25_6.m3u8,2613766-/ssd/videos/26/26_1.m3u8,2610746-/ssd/videos/26/26_2.m3u8,3333206-/ssd/videos/26/26_3.m3u8,2637299-/ssd/videos/26/26_4.m3u8,2616633-/ssd/videos/26/26_5.m3u8,2673526-/ssd/videos/26/26_6.m3u8,3721972-/ssd/videos/26/26_7.m3u8,2603126-/ssd/videos/26/26_8.m3u8,2386221-/ssd/videos/27/27_1.m3u8,2060006-/ssd/videos/27/27_2.m3u8,2400706-/ssd/videos/27/27_3.m3u8,2431786-/ssd/videos/27/27_4.m3u8,2366586-/ssd/videos/27/27_5.m3u8,2407426-/ssd/videos/27/27_6.m3u8,2428306-/ssd/videos/27/27_7.m3u8,2407566-/ssd/videos/27/27_8.m3u8,2879854-/ssd/videos/28/28_1.m3u8,2567806-/ssd/videos/28/28_2.m3u8,2744691-/ssd/videos/28/28_3.m3u8,2772485-/ssd/videos/28/28_4.m3u8,2858864-/ssd/videos/28/28_5.m3u8,2871774-/ssd/videos/28/28_6.m3u8,2817986-/ssd/videos/28/28_7.m3u8,2305626-/ssd/videos/29/29_1.m3u8,2392212-/ssd/videos/29/29_2.m3u8,2503886-/ssd/videos/29/29_3.m3u8,2405889-/ssd/videos/29/29_4.m3u8,2500347-/ssd/videos/29/29_5.m3u8,2403126-/ssd/videos/29/29_6.m3u8,2433311-/ssd/videos/29/29_7.m3u8,2408806-/ssd/videos/29/29_8.m3u8,3042486-/ssd/videos/3/3_1.m3u8,2300806-/ssd/videos/3/3_2.m3u8,2074086-/ssd/videos/3/3_3.m3u8,1958417-/ssd/videos/3/3_4.m3u8,2371128-/ssd/videos/3/3_5.m3u8,2183395-/ssd/videos/3/3_6.m3u8,1919686-/ssd/videos/3/3_7.m3u8,1811713-/ssd/videos/30/30_1.m3u8,1546006-/ssd/videos/30/30_2.m3u8,1581069-/ssd/videos/30/30_3.m3u8,1634246-/ssd/videos/30/30_4.m3u8,1519246-/ssd/videos/30/30_5.m3u8,1690110-/ssd/videos/30/30_6.m3u8,1623748-/ssd/videos/30/30_7.m3u8,2555526-/ssd/videos/31/31_1.m3u8,2284786-/ssd/videos/31/31_2.m3u8,2529246-/ssd/videos/31/31_3.m3u8,2588374-/ssd/videos/31/31_4.m3u8,2291226-/ssd/videos/31/31_5.m3u8,2574210-/ssd/videos/31/31_6.m3u8,2597059-/ssd/videos/31/31_7.m3u8,2583186-/ssd/videos/31/31_8.m3u8,2402566-/ssd/videos/32/32_1.m3u8,2415266-/ssd/videos/32/32_2.m3u8,2440306-/ssd/videos/32/32_3.m3u8,2308249-/ssd/videos/32/32_4.m3u8,2341086-/ssd/videos/32/32_5.m3u8,2087786-/ssd/videos/32/32_6.m3u8,2594326-/ssd/videos/32/32_7.m3u8,2536362-/ssd/videos/33/33_1.m3u8,2563831-/ssd/videos/33/33_2.m3u8,2574024-/ssd/videos/33/33_3.m3u8,2511626-/ssd/videos/33/33_4.m3u8,2153446-/ssd/videos/33/33_5.m3u8,2121932-/ssd/videos/33/33_6.m3u8,2549846-/ssd/videos/33/33_7.m3u8,1597649-/ssd/videos/34/34_1.m3u8,1757803-/ssd/videos/34/34_2.m3u8,1862626-/ssd/videos/34/34_3.m3u8,1903966-/ssd/videos/34/34_4.m3u8,1886086-/ssd/videos/34/34_5.m3u8,1845539-/ssd/videos/34/34_6.m3u8,1767733-/ssd/videos/34/34_7.m3u8,2678570-/ssd/videos/35/35_1.m3u8,2244074-/ssd/videos/35/35_2.m3u8,2703053-/ssd/videos/35/35_3.m3u8,2696053-/ssd/videos/35/35_4.m3u8,2603560-/ssd/videos/35/35_5.m3u8,2609886-/ssd/videos/35/35_6.m3u8,2641906-/ssd/videos/35/35_7.m3u8,3009106-/ssd/videos/36/36_1.m3u8,2485206-/ssd/videos/36/36_2.m3u8,2905506-/ssd/videos/36/36_3.m3u8,2320393-/ssd/videos/36/36_4.m3u8,2718766-/ssd/videos/36/36_5.m3u8,3095366-/ssd/videos/36/36_6.m3u8,2142520-/ssd/videos/36/36_7.m3u8,1802147-/ssd/videos/37/37_1.m3u8,1524006-/ssd/videos/37/37_2.m3u8,1530148-/ssd/videos/37/37_3.m3u8,1506566-/ssd/videos/37/37_4.m3u8,1504446-/ssd/videos/37/37_5.m3u8,1506586-/ssd/videos/37/37_6.m3u8,1821766-/ssd/videos/37/37_7.m3u8,2531300-/ssd/videos/38/38_1.m3u8,2579626-/ssd/videos/38/38_2.m3u8,2540518-/ssd/videos/38/38_3.m3u8,2518831-/ssd/videos/38/38_4.m3u8,2562406-/ssd/videos/38/38_5.m3u8,2206166-/ssd/videos/38/38_6.m3u8,2153837-/ssd/videos/38/38_7.m3u8,2921488-/ssd/videos/4/4_1.m3u8,2096006-/ssd/videos/4/4_2.m3u8,1779686-/ssd/videos/4/4_3.m3u8,1903846-/ssd/videos/4/4_4.m3u8,1848806-/ssd/videos/4/4_5.m3u8,1815243-/ssd/videos/4/4_6.m3u8,2235006-/ssd/videos/4/4_7.m3u8,1788400-/ssd/videos/5/5_1.m3u8,1578631-/ssd/videos/5/5_2.m3u8,1602086-/ssd/videos/5/5_3.m3u8,1573446-/ssd/videos/5/5_4.m3u8,1732394-/ssd/videos/5/5_5.m3u8,1633446-/ssd/videos/5/5_6.m3u8,1606566-/ssd/videos/5/5_7.m3u8,1790406-/ssd/videos/6/6_1.m3u8,1806406-/ssd/videos/6/6_2.m3u8,1695526-/ssd/videos/6/6_3.m3u8,1653051-/ssd/videos/6/6_4.m3u8,1786287-/ssd/videos/6/6_5.m3u8,1774566-/ssd/videos/6/6_6.m3u8,2385726-/ssd/videos/6/6_7.m3u8,2252366-/ssd/videos/7/7_1.m3u8,2010726-/ssd/videos/7/7_2.m3u8,1961306-/ssd/videos/7/7_3.m3u8,1833126-/ssd/videos/7/7_4.m3u8,1870566-/ssd/videos/7/7_5.m3u8,1900486-/ssd/videos/7/7_6.m3u8,2311166-/ssd/videos/7/7_7.m3u8,2923646-/ssd/videos/8/8_1.m3u8,2485672-/ssd/videos/8/8_2.m3u8,2476043-/ssd/videos/8/8_3.m3u8,2535270-/ssd/videos/8/8_4.m3u8,2655317-/ssd/videos/8/8_5.m3u8,2545886-/ssd/videos/8/8_6.m3u8,2756487-/ssd/videos/8/8_7.m3u8,2711686-/ssd/videos/8/8_8.m3u8,2221466-/ssd/videos/9/9_1.m3u8,2243286-/ssd/videos/9/9_2.m3u8,1666086-/ssd/videos/9/9_3.m3u8,2243286-/ssd/videos/9/9_4.m3u8,2185486-/ssd/videos/9/9_5.m3u8,2165655-/ssd/videos/9/9_6.m3u8,2053866-/ssd/videos/9/9_7.m3u8,1941257-/ssd/videos/93/93_1.m3u8,1581766-/ssd/videos/93/93_2.m3u8,1758075-/ssd/videos/93/93_3.m3u8,1797672-/ssd/videos/93/93_4.m3u8,2155113-/ssd/videos/93/93_5.m3u8,1462726-/ssd/videos/93/93_6.m3u8,1378606-/ssd/videos/93/93_7.m3u8,1768006-/ssd/videos/93/93_8.m3u8,3220468-/ssd/videos/94/94_1.m3u8,1688338-/ssd/videos/94/94_2.m3u8,1600005-/ssd/videos/94/94_3.m3u8,1568136-/ssd/videos/94/94_4.m3u8,2239053-/ssd/videos/94/94_5.m3u8,1979338-/ssd/videos/94/94_6.m3u8,2471578-/ssd/videos/94/94_7.m3u8,1510359-/ssd/videos/94/94_8.m3u8,2538219-/ssd/videos/96/96_1.m3u8,2530069-/ssd/videos/96/96_2.m3u8,2547995-/ssd/videos/96/96_3.m3u8,2436678-/ssd/videos/96/96_4.m3u8,2496191-/ssd/videos/96/96_5.m3u8,2394650-/ssd/videos/96/96_6.m3u8,2388311-/ssd/videos/96/96_7.m3u8,2353342-/ssd/videos/97/97_1.m3u8,2035600-/ssd/videos/97/97_2.m3u8,2018505-/ssd/videos/97/97_3.m3u8,1896954-/ssd/videos/97/97_4.m3u8,1982241-/ssd/videos/97/97_5.m3u8,1809182-/ssd/videos/97/97_6.m3u8,1856388-/ssd/videos/97/97_7.m3u8,2354874-/ssd/videos/97/97_8.m3u8,1598726-/ssd/videos/99/99_1.m3u8,1214266-/ssd/videos/99/99_2.m3u8,1209086-/ssd/videos/99/99_3.m3u8,1182268-/ssd/videos/99/99_4.m3u8,1310600-/ssd/videos/99/99_5.m3u8,1078246-/ssd/videos/99/99_6.m3u8,1225926-/ssd/videos/99/99_7.m3u8"
