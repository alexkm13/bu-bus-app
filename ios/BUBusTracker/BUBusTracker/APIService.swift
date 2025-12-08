// APIService.swift
// BUBusTracker - Network layer for fetching bus data

import Foundation

class APIService: ObservableObject {
    // Change this to your Mac's IP for real device testing
    #if targetEnvironment(simulator)
    private let baseURL = "http://127.0.0.1:3000"
    #else
    private let baseURL = "http://10.239.128.183:3000"
    #endif
    
    @Published var vehicles: [Vehicle] = []
    @Published var routes: [Route] = []
    @Published var stops: [Stop] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdate: Date?
    
    private var refreshTimer: Timer?
    
    init() {
        startAutoRefresh()
    }
    
    deinit {
        stopAutoRefresh()
    }
    
    func startAutoRefresh(interval: TimeInterval = 10) {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.fetchVehicles() }
        }
        Task { await fetchMap() }
    }
    
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    @MainActor
    func fetchMap() async {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/api/map") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(MapResponse.self, from: data)
            
            self.vehicles = response.vehicles
            self.routes = response.routes
            self.stops = response.stops
            self.lastUpdate = Date()
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
            print("Fetch error: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    func fetchVehicles() async {
        guard let url = URL(string: "\(baseURL)/api/vehicles") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let vehicles = try JSONDecoder().decode([Vehicle].self, from: data)
            self.vehicles = vehicles
            self.lastUpdate = Date()
        } catch {
            print("Vehicle refresh error: \(error)")
        }
    }
}
