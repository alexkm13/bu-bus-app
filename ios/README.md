# BU Bus Tracker iOS App

A SwiftUI app that shows live BU shuttle bus locations on a map.

## Setup Instructions

### 1. Create Xcode Project

1. Open Xcode → **File → New → Project**
2. Choose **iOS → App**
3. Settings:
   - Product Name: `BUBusTracker`
   - Team: Your team
   - Organization Identifier: `com.yourname`
   - Interface: **SwiftUI**
   - Language: **Swift**
4. Save to any location (you'll replace the files)

### 2. Add the Swift Files

1. In Xcode, delete the auto-generated `ContentView.swift`
2. Drag these files into your project (from `ios/BUBusTracker/BUBusTracker/`):
   - `Models.swift`
   - `APIService.swift`
   - `BusMapView.swift`
   - `BUBusTrackerApp.swift`
3. When prompted, check "Copy items if needed"

### 3. Configure Info.plist

Add these keys for **local network** and **location access**:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Shows your location on the map so you can see nearby buses</string>
```

### 4. Update Backend URL

In `APIService.swift`, update the IP address for real device testing:

```swift
private let baseURL = "http://YOUR_MAC_IP:3000"
```

Your current Mac IP: `10.239.128.183`

### 5. Run

1. Make sure the Python backend is running: `python3 app.py`
2. Run the app in Xcode (Simulator or Device)

## Features

- 🗺️ Live map with bus locations
- 🔄 Auto-refresh every 10 seconds
- 🎨 Color-coded buses by route
- 📍 Directional arrows showing bus heading
- 🚌 Tap bus for details (speed, route, status)
- 🔀 Route filter to show/hide specific routes

## Backend URL

- Simulator: `http://127.0.0.1:3000`
- Real Device: `http://10.239.128.183:3000`
