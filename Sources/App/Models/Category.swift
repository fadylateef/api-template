//
//  File.swift
//  App
//
//  Created by Fady Lateef on 08/03/2021.
//

import Vapor
import FluentMySQL

final class Category: MySQLModel {
    init(id: Int? = nil, title: String) {
        self.id = id
        self.title = title
    }
    
    var id: Int?
    var title : String
}

extension Category: Migration { }
extension Category: Content { }
extension Category: Parameter { }
