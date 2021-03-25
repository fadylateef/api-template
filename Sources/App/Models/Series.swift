import FluentMySQL
import Vapor

/// A single entry of a Todo list.
final class Series: MySQLModel {
    /// The unique identifier for this `Todo`.
    var id: Int?
    var title: String
    var poster : String
    var type : String
    var trailer : String
    var story : String
    var actors : String
    var categoryID : Int

    init(id: Int? = nil, title : String,poster : String,type : String,trailer : String,story : String,actors : String,categoryID : Int) {
        self.id = id
        self.title = title
        self.poster = poster
        self.type = type
        self.trailer = trailer
        self.story = story
        self.actors = actors
        self.categoryID = categoryID
    }
}

extension Series: Migration { }
extension Series: Content { }
extension Series: Parameter { }
