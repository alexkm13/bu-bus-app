// MapViewWithPolylines.swift
// BUBusTracker - UIKit MapView wrapper with polylines

import SwiftUI
import MapKit

struct MapViewWithPolylines: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let routes: [Route]
    let vehicles: [Vehicle]
    let enabledRoutes: Set<Int>
    let selectedVehicle: Vehicle?
    let onVehicleTap: (Vehicle) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.setRegion(region, animated: false)
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update polylines
        mapView.removeOverlays(mapView.overlays)
        for route in routes where enabledRoutes.contains(route.id) {
            if let encoded = route.encodedPolyline,
               let coords = decodePolyline(encoded) {
                let polyline = RoutePolyline(coordinates: coords, count: coords.count)
                polyline.color = UIColor(Color(hex: route.color ?? "#0000FF"))
                mapView.addOverlay(polyline)
            }
        }
        
        // Update annotations
        let existing = mapView.annotations.compactMap { $0 as? VehicleAnnotation }
        let existingIds = Set(existing.map { $0.vehicle.id })
        let filteredVehicles = vehicles.filter { enabledRoutes.isEmpty || enabledRoutes.contains($0.routeId) }
        let newIds = Set(filteredVehicles.map { $0.id })
        
        mapView.removeAnnotations(existing.filter { !newIds.contains($0.vehicle.id) })
        
        for vehicle in filteredVehicles {
            if let ann = existing.first(where: { $0.vehicle.id == vehicle.id }) {
                ann.coordinate = vehicle.coordinate
                ann.vehicle = vehicle
            } else {
                mapView.addAnnotation(VehicleAnnotation(vehicle: vehicle))
            }
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewWithPolylines
        init(_ parent: MapViewWithPolylines) { self.parent = parent }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? RoutePolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = polyline.color ?? .blue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let va = annotation as? VehicleAnnotation else { return nil }
            let id = "Bus"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
            if view == nil {
                view = MKAnnotationView(annotation: annotation, reuseIdentifier: id)
            }
            view?.annotation = annotation
            view?.image = makeBusImage(va.vehicle)
            return view
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let va = view.annotation as? VehicleAnnotation {
                parent.onVehicleTap(va.vehicle)
            }
            mapView.deselectAnnotation(view.annotation, animated: false)
        }
        
        func makeBusImage(_ v: Vehicle) -> UIImage {
            let size: CGFloat = 32
            return UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
                ctx.cgContext.translateBy(x: size/2, y: size/2)
                ctx.cgContext.rotate(by: CGFloat(v.heading ?? 0) * .pi / 180)
                ctx.cgContext.translateBy(x: -size/2, y: -size/2)
                
                let color = UIColor(Color(hex: v.routeColor ?? "#0000FF"))
                let path = UIBezierPath()
                path.move(to: CGPoint(x: size/2, y: 2))
                path.addLine(to: CGPoint(x: size-4, y: size-4))
                path.addLine(to: CGPoint(x: size/2, y: size*0.7))
                path.addLine(to: CGPoint(x: 4, y: size-4))
                path.close()
                color.setFill()
                path.fill()
            }
        }
    }
}

class RoutePolyline: MKPolyline {
    var color: UIColor?
}

class VehicleAnnotation: NSObject, MKAnnotation {
    var vehicle: Vehicle
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String? { vehicle.displayName }
    
    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        self.coordinate = vehicle.coordinate
    }
}

func decodePolyline(_ encoded: String) -> [CLLocationCoordinate2D]? {
    var coords: [CLLocationCoordinate2D] = []
    var index = encoded.startIndex
    var lat = 0, lng = 0
    
    while index < encoded.endIndex {
        var result = 0, shift = 0, byte: Int
        repeat {
            guard index < encoded.endIndex else { return nil }
            byte = Int(encoded[index].asciiValue ?? 0) - 63
            index = encoded.index(after: index)
            result |= (byte & 0x1F) << shift
            shift += 5
        } while byte >= 0x20
        lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        
        result = 0; shift = 0
        repeat {
            guard index < encoded.endIndex else { return nil }
            byte = Int(encoded[index].asciiValue ?? 0) - 63
            index = encoded.index(after: index)
            result |= (byte & 0x1F) << shift
            shift += 5
        } while byte >= 0x20
        lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        
        coords.append(CLLocationCoordinate2D(latitude: Double(lat)/1e5, longitude: Double(lng)/1e5))
    }
    return coords
}
