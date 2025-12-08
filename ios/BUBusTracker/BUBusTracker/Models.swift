// Models.swift
// BUBusTracker - Data models for the API

import Foundation
import CoreLocation

// MARK: - API Response Models

struct MapResponse: Codable {
    let vehicles: [Vehicle]
    let routes: [Route]
    let stops: [Stop]
    let timestamp: Double
}

struct Vehicle: Codable, Identifiable, Equatable {
    let id: Int
    let routeId: Int
    let routeName: String?
    let routeColor: String?
    let name: String?
    let lat: Double
    let lon: Double
    let heading: Int?
    let speed: Double?
    let isOnRoute: Bool
    let isDelayed: Bool
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    var displayName: String {
        routeName ?? "Route \(routeId)"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case routeId = "route_id"
        case routeName = "route_name"
        case routeColor = "route_color"
        case name
        case lat, lon, heading, speed
        case isOnRoute = "is_on_route"
        case isDelayed = "is_delayed"
    }
    
    static func == (lhs: Vehicle, rhs: Vehicle) -> Bool {
        lhs.id == rhs.id
    }
}

struct Route: Codable, Identifiable, Equatable {
    let id: Int
    let description: String?
    let color: String?
    let encodedPolyline: String?
    let isRunning: Bool
    let stops: [RouteStop]?
    
    var displayName: String {
        description ?? "Route \(id)"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case description
        case color
        case encodedPolyline = "encoded_polyline"
        case isRunning = "is_running"
        case stops
    }
    
    static func == (lhs: Route, rhs: Route) -> Bool {
        lhs.id == rhs.id
    }
}

struct RouteStop: Codable, Identifiable, Equatable {
    let id: Int
    let name: String?
    let lat: Double?
    let lon: Double?
    let order: Int?
    
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = lat, let lon = lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct Stop: Codable, Identifiable, Equatable {
    let id: Int
    let name: String?
    let lat: Double?
    let lon: Double?
    
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = lat, let lon = lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
