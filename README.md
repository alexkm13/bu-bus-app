# BU Bus Tracker

**If you like what you see, consider buying me a cup of coffee ☕.**

[![GitHub stars](https://img.shields.io/github/stars/alexkm13/bu-bus-app?style=social)](https://github.com/alexkm13/bu-bus-app/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/alexkm13/bu-bus-app?style=social)](https://github.com/alexkm13/bu-bus-app/network/members)

---

Tired of waiting at the bus stop wondering when your bus will arrive? Want to see exactly where your bus is in real-time? Looking for a clean, native iOS experience for tracking Boston University's bus system? Look no further!

**BU Bus Tracker** is a real-time bus tracking iOS application for Boston University's bus system. Built with SwiftUI and MapKit, this app provides live bus locations, route visualization, and detailed vehicle information right at your fingertips.

This repository contains both the iOS app and the Python backend API that powers it.

## 📸 Screenshots

_Add your app screenshots here!_

## ✨ Features

- 🗺️ **Interactive Map View** - Real-time visualization of buses, routes, and stops on a map
- 🚌 **Live Bus Tracking** - See all active buses with their current locations and headings
- 🛣️ **Route Visualization** - View bus routes as colored polylines on the map
- 🚏 **Bus Stop Information** - Tap on stops to see which routes serve them
- 🔍 **Route Filtering** - Filter the map to show only specific routes
- 📊 **Vehicle Details** - View speed, occupancy, capacity, and delay status for each bus
- 📍 **User Location** - Center the map on your current location
- 🔄 **Auto-Refresh** - Automatically updates bus positions every 10 seconds

## 📀 Installation

### Requirements

- iOS 15.0 or later
- Xcode 14.0 or later
- Swift 5.7 or later
- Active internet connection
- Location permissions (optional, for user location feature)

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/alexkm13/bu-bus-app.git
   cd bu-bus-app
   ```

2. **Open iOS app in Xcode**
   ```bash
   cd ios/BUBusTracker
   open BUBusTracker.xcodeproj
   ```

3. **Configure API Endpoint**
   
   The app uses different endpoints based on the build target:
   - **Simulator**: `http://127.0.0.1:3000` (for local development - requires running the backend API locally)
   - **Physical Device**: `https://bu-bus-app.onrender.com` (production API)
   
   To change the API endpoint, edit `APIService.swift`:
   ```swift
   #if targetEnvironment(simulator)
   private let baseURL = "http://YOUR_LOCAL_IP:3000"
   #else
   private let baseURL = "https://your-api-url.com"
   #endif
   ```

4. **Build and Run**
   - Select your target device or simulator
   - Press `Cmd + R` to build and run

## 📱 Usage

### Viewing Buses
- The map automatically loads and displays all active buses
- Buses are shown as colored markers that rotate based on their heading
- The bus count is displayed in the top-left corner

### Selecting a Bus
- Tap on any bus marker to view detailed information
- The vehicle card shows:
  - Route name and color
  - Current speed
  - Occupancy (passengers/capacity)
  - Delay status

### Filtering Routes
1. Tap the filter icon (three horizontal lines) in the top-right
2. Select which routes to display on the map
3. Use "Show All" or "Hide All" for quick filtering
4. Only running routes are shown in the filter list

### Viewing Stops
- Tap on any bus stop marker to see which routes serve that stop
- Stop information is displayed in a card at the bottom of the screen

### Centering on Your Location
- Tap the location icon in the top-right to center the map on your current location
- Location permissions will be requested on first use

## ✏️ Development

### iOS App

To build the iOS app locally, navigate to the iOS directory and open it in Xcode:

```bash
cd ios/BUBusTracker
open BUBusTracker.xcodeproj
```

### Backend API

The backend is a Python Flask application. To run it locally:

```bash
pip install -r requirements.txt
python app.py
```

The API will run on `http://localhost:3000` by default.

🛎️ **Have suggestions?** Feel free to create an issue or make a pull request.

🤝 **Want to contribute?** Check out the issues tab for open tasks!

### Project Structure

```
bu-bus-app/
├── ios/
│   └── BUBusTracker/
│       └── BUBusTracker/
│           ├── BUBusTrackerApp.swift          # Main app entry point
│           ├── BusMapView.swift               # Primary map view with UI controls
│           ├── MapViewWithPolylines.swift     # UIKit MapView wrapper with annotations
│           ├── APIService.swift               # Network layer for API communication
│           ├── Models.swift                   # Data models (Vehicle, Route, Stop, etc.)
│           └── Info.plist                     # App configuration
├── app.py                                     # Flask backend API
├── transloc.py                                # TransLoc API integration
├── requirements.txt                           # Python dependencies
└── README.md                                  # This file
```

### Dependencies

**iOS:**
* **SwiftUI** - Modern declarative UI framework
* **MapKit** - Map rendering and annotations
* **Combine** - Reactive data flow
* **Foundation** - Core system functionality

**Backend:**
* **Flask** - Python web framework
* **requests** - HTTP library for API calls

### Architecture

- **SwiftUI** for the iOS user interface
- **MapKit** for map rendering and annotations
- **Combine** for reactive data flow
- **Async/Await** for network requests
- **MVVM-like pattern** with `ObservableObject` for state management
- **Flask** for the backend API server

## 🔌 API Endpoints

The backend API provides the following endpoints:

### `GET /api/map`
Returns complete map data including vehicles, routes, and stops.

**Response:**
```json
{
  "vehicles": [...],
  "routes": [...],
  "stops": [...],
  "timestamp": 1234567890.0
}
```

### `GET /api/vehicles`
Returns updated vehicle positions (used for faster refresh cycles).

**Response:**
```json
[
  {
    "id": 1,
    "route_id": 101,
    "route_name": "Route A",
    "route_color": "#FF0000",
    "lat": 42.3505,
    "lon": -71.1054,
    "heading": 90,
    "speed": 25.5,
    "is_on_route": true,
    "is_delayed": false,
    "capacity": 40,
    "current_passengers": 15,
    "occupancy_percentage": 0.375
  }
]
```

## 🔄 Auto-Refresh

The iOS app automatically refreshes bus positions every 10 seconds. The refresh interval can be customized in `APIService.swift`:

```swift
func startAutoRefresh(interval: TimeInterval = 10) {
    // Change the default interval value
}
```

## 📜 License

MIT License

_Disclaimer: Not affiliated with Boston University._

## About

Real-time bus tracking iOS application for Boston University's bus system. Made possible with SwiftUI, MapKit, and Flask.

This repository contains both the iOS frontend and Python backend API.

### Topics

swift swiftui ios mapkit bus-tracking real-time boston-university python flask backend api

### Resources

Readme

### License

MIT license

### Code of conduct

[Code of conduct](CODE_OF_CONDUCT.md)

### Contributing

[Contributing](CONTRIBUTING.md)
