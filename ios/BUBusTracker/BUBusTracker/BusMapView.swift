// BusMapView.swift
// BUBusTracker - Main map view

import SwiftUI
import MapKit
import Combine

struct BusMapView: View {
    @StateObject private var api = APIService()
    @StateObject private var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 42.3505, longitude: -71.1054),
        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
    )
    @State private var selectedVehicle: Vehicle?
    @State private var selectedStop: Stop?
    @State private var showRouteFilter = false
    @State private var enabledRoutes: Set<Int> = []
    @State private var hasInitializedRoutes = false
    
    var filteredVehicles: [Vehicle] {
        enabledRoutes.isEmpty ? api.vehicles : api.vehicles.filter { enabledRoutes.contains($0.routeId) }
    }
    
    var body: some View {
        ZStack {
            MapViewWithPolylines(
                region: $region,
                routes: api.routes,
                vehicles: filteredVehicles,
                stops: api.stops,
                enabledRoutes: enabledRoutes,
                selectedVehicle: selectedVehicle,
                onVehicleTap: { v in
                    withAnimation {
                        selectedVehicle = v
                        selectedStop = nil
                    }
                },
                onStopTap: { s in
                    withAnimation {
                        selectedStop = s
                        selectedVehicle = nil
                    }
                }
            )
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BU Bus Tracker").font(.headline).bold()
                        HStack(spacing: 4) {
                            Circle().fill(api.isLoading ? .orange : .green).frame(width: 8, height: 8)
                            Text("\(filteredVehicles.count) buses").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Button(action: centerOnUser) {
                        Image(systemName: "location.fill").font(.title2).foregroundColor(.blue)
                    }.padding(.trailing, 8)
                    Button(action: { showRouteFilter.toggle() }) {
                        Image(systemName: "line.3.horizontal.decrease.circle").font(.title2)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding()
                
                Spacer()
                
                if let v = selectedVehicle {
                    VehicleCard(vehicle: v) { withAnimation { selectedVehicle = nil } }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding()
                }
                
                if let s = selectedStop {
                    StopCard(stop: s) { withAnimation { selectedStop = nil } }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding()
                }
            }
        }
        .sheet(isPresented: $showRouteFilter) {
            RouteFilterView(routes: api.routes, enabledRoutes: $enabledRoutes)
        }
        .task {
            locationManager.requestPermission()
            await api.fetchMap()
            if !hasInitializedRoutes && !api.routes.isEmpty {
                // Only enable routes that are actually running
                enabledRoutes = Set(api.routes.filter { $0.isRunning }.map { $0.id })
                hasInitializedRoutes = true
            }
        }
    }
    
    func centerOnUser() {
        if let loc = locationManager.location {
            withAnimation { region.center = loc.coordinate }
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let mgr = CLLocationManager()
    @Published var location: CLLocation?
    
    override init() {
        super.init()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestPermission() { mgr.requestWhenInUseAuthorization() }
    
    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        location = locs.last
    }
    
    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        if m.authorizationStatus == .authorizedWhenInUse || m.authorizationStatus == .authorizedAlways {
            mgr.startUpdatingLocation()
        }
    }
}

struct VehicleCard: View {
    let vehicle: Vehicle
    let onDismiss: () -> Void
    
    var occupancyColor: Color {
        guard let pct = vehicle.occupancyPercentage else { return .gray }
        if pct < 0.25 { return .green }
        if pct < 0.50 { return .blue }
        if pct < 0.75 { return .orange }
        return .red
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack {
                    Circle().fill(Color(hex: vehicle.routeColor ?? "#000")).frame(width: 12, height: 12)
                    Text(vehicle.displayName).font(.headline)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.secondary)
                }
            }
            Divider()
            HStack(spacing: 16) {
                Label("\(Int(vehicle.speed ?? 0)) mph", systemImage: "speedometer").font(.subheadline)
                
                if let passengers = vehicle.currentPassengers, let capacity = vehicle.capacity, capacity > 0 {
                    Label("\(passengers)/\(capacity)", systemImage: "person.2.fill")
                        .font(.subheadline)
                        .foregroundColor(occupancyColor)
                }
                
                Label(vehicle.isDelayed ? "Delayed" : "On Time",
                      systemImage: vehicle.isDelayed ? "exclamationmark.triangle" : "checkmark.circle")
                    .font(.subheadline)
                    .foregroundColor(vehicle.isDelayed ? .orange : .green)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

struct StopCard: View {
    let stop: Stop
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.blue)
                    Text(stop.name ?? "Bus Stop")
                        .font(.headline)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.secondary)
                }
            }
            
            if let routes = stop.routes, !routes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(routes) { route in
                            Text(route.name ?? "Route \(route.id)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(6)
                                .background(Color(hex: route.color ?? "#000000"))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
            } else {
                Text("Tap for arrival times (coming soon)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

struct RouteFilterView: View {
    let routes: [Route]
    @Binding var enabledRoutes: Set<Int>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button("Show All") { enabledRoutes = Set(routes.map { $0.id }) }
                    Button("Hide All") { enabledRoutes.removeAll() }
                }
                Section("Routes") {
                    ForEach(routes.filter { $0.isRunning }) { route in
                        HStack {
                            Circle().fill(Color(hex: route.color ?? "#000")).frame(width: 12, height: 12)
                            Text(route.displayName)
                            Spacer()
                            if enabledRoutes.contains(route.id) {
                                Image(systemName: "checkmark").foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if enabledRoutes.contains(route.id) {
                                enabledRoutes.remove(route.id)
                            } else {
                                enabledRoutes.insert(route.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Routes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

#Preview { BusMapView() }
