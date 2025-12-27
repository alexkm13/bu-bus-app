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
    // Capacity data
    let capacity: Int?
    let currentPassengers: Int?
    let occupancyPercentage: Double?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    var displayName: String {
        routeName ?? "Route \(routeId)"
    }
    
    var occupancyLevel: String {
        guard let percentage = occupancyPercentage else { return "Unknown" }
        if percentage < 0.25 { return "Empty" }
        if percentage < 0.50 { return "Light" }
        if percentage < 0.75 { return "Moderate" }
        return "Full"
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
        case capacity
        case currentPassengers = "current_passengers"
        case occupancyPercentage = "occupancy_percentage"
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
    let routes: [RouteInfo]?
    
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = lat, let lon = lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    static func == (lhs: Stop, rhs: Stop) -> Bool {
        lhs.id == rhs.id
    }
}

struct RouteInfo: Codable, Identifiable, Equatable {
    let id: Int
    let name: String?
    let color: String?
}
