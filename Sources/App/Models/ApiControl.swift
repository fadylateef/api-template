//
//  ApiControl.swift
//  App
//
//  Created by Fady Lateef on 08/03/2021.
//

import Vapor
import FluentMySQL

final class ApiControl: MySQLModel {
    init(id: Int? = nil, api: Bool, tvLink: String, apiUpdate: Bool, apiJB: Bool, apiAB: Bool, apiUpdateLink: String, apiPlus: Bool, apiPlusPrefix: String, loop1: String, loop2: String, loopTime: Int,ad : Int) {
        self.id = id
        self.api = api
        self.tvLink = tvLink
        self.apiUpdate = apiUpdate
        self.apiJB = apiJB
        self.apiAB = apiAB
        self.apiUpdateLink = apiUpdateLink
        self.apiPlus = apiPlus
        self.apiPlusPrefix = apiPlusPrefix
        self.loop1 = loop1
        self.loop2 = loop2
        self.loopTime = loopTime
        self.ad = ad
    }
    
    
    var id: Int?
    var api : Bool
    var tvLink : String
    var apiUpdate : Bool
    var apiJB : Bool
    var apiAB : Bool
    var apiUpdateLink : String
    var apiPlus : Bool
    var apiPlusPrefix : String
    var loop1 : String
    var loop2 : String
    var loopTime : Int
    var ad : Int
}

extension ApiControl: Migration { }
extension ApiControl: Content { }
extension ApiControl: Parameter { }
