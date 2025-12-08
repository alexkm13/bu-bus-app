"""
BU Bus Backend API
Provides real-time bus tracking data from TransLoc API
Endpoints: /api/routes, /api/vehicles, /api/vehicle_estimates, /api/stop_arrival_times
"""

from flask import Flask, jsonify
from flask_cors import CORS
import transloc
import time
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Get API key from environment variable (set in .env file)
API_KEY = os.getenv("TRANSLOC_API_KEY")

if not API_KEY:
    raise RuntimeError("TRANSLOC_API_KEY not set in .env file")

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes (iOS simulator, web frontend, etc.)

# Simple in-memory cache so we don't hammer TransLoc
_routes_cache = {
    "data": None,
    "last_fetch": 0.0,
    "ttl": 0,  # disabled for debugging
}

_vehicles_cache = {
    "data": None,
    "last_fetch": 0.0,
    "ttl": 0,  # disabled for debugging
}

_estimates_cache = {
    "data": None,
    "last_fetch": 0.0,
    "ttl": 0,  # disabled for debugging
}

_arrivals_cache = {
    "data": None,
    "last_fetch": 0.0,
    "ttl": 0,  # disabled for debugging
}


@app.route("/api/routes")
def api_routes():
    now = time.time()
    if _routes_cache["data"] is not None and (now - _routes_cache["last_fetch"] < _routes_cache["ttl"]):
        return jsonify(_routes_cache["data"])

    raw = transloc.fetch_transloc(
        "GetRoutesForMapWithScheduleWithEncodedLine",
        params={"apiKey": API_KEY, "isDispatch": "false"},
    )

    # raw can be a dict with a list under some key, or a list directly.
    if isinstance(raw, dict):
        routes_raw = (
            raw.get("Routes")
            or raw.get("routes")
            or raw.get("Data")
            or raw.get("data")
            or []
        )
    elif isinstance(raw, list):
        routes_raw = raw
    else:
        routes_raw = []

    routes_out: list[dict] = []

    for r in routes_raw:
        # Optionally skip routes not visible on map
        if not r.get("IsVisibleOnMap", True):
            continue

        # Build stops list
        stops_out: list[dict] = []
        for s in r.get("Stops", []):
            stops_out.append(
                {
                    "id": s.get("RouteStopID"),
                    "name": s.get("Description") or s.get("Line1"),
                    "lat": s.get("Latitude"),
                    "lon": s.get("Longitude"),
                    "order": s.get("Order"),
                    "show_on_map": s.get("ShowDefaultedOnMap", True),
                }
            )

        route_out = {
            "id": r.get("RouteID"),
            "description": r.get("Description"),
            "color": r.get("MapLineColor"),
            "encoded_polyline": r.get("EncodedPolyline"),
            "is_running": r.get("IsRunning", False),
            "map_center": {
                "lat": r.get("MapLatitude"),
                "lon": r.get("MapLongitude"),
                "zoom": r.get("MapZoom"),
            },
            "stops": stops_out,
        }

        routes_out.append(route_out)

    # Cache and return
    _routes_cache["data"] = routes_out
    _routes_cache["last_fetch"] = now
    return jsonify(routes_out)


@app.route("/api/stops")
def api_stops():
    """
    Returns a flat list of all unique stops across all routes.
    Perfect for iOS stop picker UI.
    """
    # Reuse routes data (which includes stops)
    now = time.time()
    if _routes_cache["data"] is not None and (now - _routes_cache["last_fetch"] < _routes_cache["ttl"]):
        routes_data = _routes_cache["data"]
    else:
        # Fetch fresh routes data
        raw = transloc.fetch_transloc(
            "GetRoutesForMapWithScheduleWithEncodedLine",
            params={"apiKey": API_KEY, "isDispatch": "false"},
        )

        if isinstance(raw, dict):
            routes_raw = (
                raw.get("Routes")
                or raw.get("routes")
                or raw.get("Data")
                or raw.get("data")
                or []
            )
        elif isinstance(raw, list):
            routes_raw = raw
        else:
            routes_raw = []

        routes_data = []
        for r in routes_raw:
            stops_out = []
            for s in r.get("Stops", []):
                stops_out.append({
                    "id": s.get("RouteStopID"),
                    "name": s.get("Description") or s.get("Line1"),
                    "lat": s.get("Latitude"),
                    "lon": s.get("Longitude"),
                    "order": s.get("Order"),
                    "show_on_map": s.get("ShowDefaultedOnMap", True),
                })
            routes_data.append({"stops": stops_out, "route_id": r.get("RouteID"), "route_name": r.get("Description")})

    # Flatten and deduplicate stops by ID
    seen_ids = set()
    stops_out = []
    for route in routes_data:
        route_id = route.get("route_id") or route.get("id")
        route_name = route.get("route_name") or route.get("description")
        for stop in route.get("stops", []):
            stop_id = stop.get("id")
            if stop_id and stop_id not in seen_ids:
                seen_ids.add(stop_id)
                stops_out.append({
                    "id": stop_id,
                    "name": stop.get("name"),
                    "lat": stop.get("lat"),
                    "lon": stop.get("lon"),
                })

    # Sort by name for easier browsing
    stops_out.sort(key=lambda x: x.get("name") or "")

    return jsonify(stops_out)


@app.route("/api/vehicles")
def api_vehicles():
    """
    Live bus locations with route info included.
    This is the primary endpoint for the location-centric iOS app.
    """
    now = time.time()
    
    # Build route lookup table (from cache or fresh fetch)
    route_lookup = _get_route_lookup()
    
    if _vehicles_cache["data"] is not None and (now - _vehicles_cache["last_fetch"] < _vehicles_cache["ttl"]):
        return jsonify(_vehicles_cache["data"])

    raw = transloc.fetch_transloc(
        "GetMapVehiclePoints",
        params={"apiKey": API_KEY, "isDispatch": "false"},
    )

    # raw can be a dict with a list under some key, or a list directly.
    if isinstance(raw, dict):
        vehicles_raw = (
            raw.get("Vehicles")
            or raw.get("vehicles")
            or raw.get("Data")
            or raw.get("data")
            or []
        )
    elif isinstance(raw, list):
        vehicles_raw = raw
    else:
        vehicles_raw = []

    vehicles_out: list[dict] = []

    for v in vehicles_raw:
        # Skip if missing coords
        lat = v.get("Latitude")
        lon = v.get("Longitude")
        if lat is None or lon is None:
            continue

        # Optional: only keep vehicles that are actually on route
        if v.get("IsOnRoute") is False:
            continue

        route_id = v.get("RouteID")
        route_info = route_lookup.get(route_id, {})

        vehicle_out = {
            "id": v.get("VehicleID"),
            "route_id": route_id,
            "route_name": route_info.get("name"),
            "route_color": route_info.get("color"),
            "name": v.get("Name"),
            "lat": lat,
            "lon": lon,
            "heading": v.get("Heading"),
            "speed": v.get("GroundSpeed"),
            "is_on_route": v.get("IsOnRoute", True),
            "is_delayed": v.get("IsDelayed", False),
            "timestamp_raw": v.get("TimeStamp"),
        }

        vehicles_out.append(vehicle_out)

    _vehicles_cache["data"] = vehicles_out
    _vehicles_cache["last_fetch"] = now

    return jsonify(vehicles_out)


def _get_route_lookup():
    """Build a route_id -> {name, color} lookup table."""
    now = time.time()
    
    if _routes_cache["data"] is not None and (now - _routes_cache["last_fetch"] < _routes_cache["ttl"]):
        routes_data = _routes_cache["data"]
    else:
        # Fetch fresh
        raw = transloc.fetch_transloc(
            "GetRoutesForMapWithScheduleWithEncodedLine",
            params={"apiKey": API_KEY, "isDispatch": "false"},
        )
        if isinstance(raw, dict):
            routes_data = raw.get("Routes") or raw.get("routes") or raw.get("Data") or raw.get("data") or []
        elif isinstance(raw, list):
            routes_data = raw
        else:
            routes_data = []
    
    lookup = {}
    for r in routes_data:
        route_id = r.get("RouteID") or r.get("id")
        lookup[route_id] = {
            "name": r.get("Description") or r.get("description"),
            "color": r.get("MapLineColor") or r.get("color"),
        }
    return lookup


@app.route("/api/map")
def api_map():
    """
    Combined endpoint for iOS map view - returns everything needed in one call:
    - vehicles: live bus positions with route info
    - routes: polylines and metadata
    - stops: all stop locations
    
    Poll this every 10-15s for live updates.
    """
    # Get vehicles (leverages caching)
    vehicles_response = api_vehicles()
    vehicles_data = vehicles_response.get_json()
    
    # Get routes (leverages caching)
    routes_response = api_routes()
    routes_data = routes_response.get_json()
    
    # Get stops (leverages routes data)
    stops_response = api_stops()
    stops_data = stops_response.get_json()
    
    return jsonify({
        "vehicles": vehicles_data,
        "routes": routes_data,
        "stops": stops_data,
        "timestamp": time.time(),
    })


@app.route("/api/vehicle_estimates/")
def api_vehicle_estimates():
    now = time.time()
    if _estimates_cache["data"] is not None and (now - _estimates_cache["last_fetch"] < _estimates_cache["ttl"]):
        return jsonify(_estimates_cache["data"])

    # Get all vehicles so we know which IDs to ask for
    vehicles_raw = transloc.fetch_transloc(
        "GetMapVehiclePoints",
        params={"apiKey": API_KEY, "isPublicMap": "true"},
    )

    if isinstance(vehicles_raw, dict):
        vehicles_list = (
            vehicles_raw.get("Vehicles")
            or vehicles_raw.get("vehicles")
            or vehicles_raw.get("Data")
            or vehicles_raw.get("data")
            or []
        )
    elif isinstance(vehicles_raw, list):
        vehicles_list = vehicles_raw
    else:
        vehicles_list = []

    # Filter to on-route vehicles and collect IDs
    vehicle_ids = []
    for v in vehicles_list:
        if v.get("IsOnRoute") is False:
            continue
        vid = v.get("VehicleID")
        if vid is not None:
            vehicle_ids.append(str(vid))

    # If no active vehicles, just return empty list
    if not vehicle_ids:
        _estimates_cache["data"] = []
        _estimates_cache["last_fetch"] = now
        return jsonify([])

    # Call TransLoc for all those vehicles at once
    id_string = ",".join(vehicle_ids)
    
    # DEBUG: Log which vehicle IDs we're requesting
    print(f"\n[DEBUG] /api/vehicle_estimates requesting vehicleIdStrings: {vehicle_ids}")
    
    raw = transloc.fetch_transloc(
        "GetVehicleRouteStopEstimates",
        params={
            "vehicleIdStrings": id_string,
            "quantity": "5",  # how many upcoming stops per vehicle
        },
    )

    if not isinstance(raw, list) or not raw:
        raw = []
    
    # DEBUG: Log what we got back per vehicle
    for entry in raw:
        vid = entry.get("VehicleID")
        est_count = len(entry.get("Estimates", []) or [])
        print(f"[DEBUG] VehicleID={vid} returned {est_count} estimates")
    
    # 3. Normalize output
    estimates_out: list[dict] = []

    for entry in raw:
        vid = entry.get("VehicleID")
        est_list = entry.get("Estimates", []) or []

        # Skip vehicles with no estimates (cleaner UX for v1)
        if not est_list:
            print(f"[DEBUG] Skipping VehicleID={vid} (no estimates)")
            continue

        arrivals = []
        for est in est_list:
            arrivals.append(
                {
                    "stop_id": est.get("RouteStopID"),
                    "stop_name": est.get("Description"),
                    "seconds_until_arrival": est.get("Seconds"),
                    "timestamp_raw": est.get("EstimateTime") or est.get("Time"),
                    "on_time_status": est.get("OnTimeStatus"),
                    "is_arriving": est.get("IsArriving"),
                    "on_route": est.get("OnRoute"),
                }
            )

        estimates_out.append(
            {
                "vehicle_id": vid,
                "arrivals": arrivals,
            }
        )

    _estimates_cache["data"] = estimates_out
    _estimates_cache["last_fetch"] = now

    return jsonify(estimates_out)

@app.route("/api/stop_arrival_times/")
def api_stop_arrival_times():
    now = time.time()
    if _arrivals_cache["data"] is not None and (now - _arrivals_cache["last_fetch"] < _arrivals_cache["ttl"]):
        return jsonify(_arrivals_cache["data"])
    
    raw = transloc.fetch_transloc(
        "GetStopArrivalTimes",
        params={"apiKey": API_KEY, "isDispatch": "false"},
    )

    return jsonify(raw)


@app.route("/api/stops/<int:route_stop_id>/arrivals")
def api_stop_arrivals(route_stop_id):
    """
    MVP stop-centric endpoint: "When is the next bus coming to MY stop?"
    Returns upcoming arrivals for a specific stop across all vehicles/routes.
    """
    # Get all vehicle estimates (reuses same TransLoc call logic)
    vehicles_raw = transloc.fetch_transloc(
        "GetMapVehiclePoints",
        params={"apiKey": API_KEY, "isPublicMap": "true"},
    )

    if isinstance(vehicles_raw, dict):
        vehicles_list = (
            vehicles_raw.get("Vehicles")
            or vehicles_raw.get("vehicles")
            or vehicles_raw.get("Data")
            or vehicles_raw.get("data")
            or []
        )
    elif isinstance(vehicles_raw, list):
        vehicles_list = vehicles_raw
    else:
        vehicles_list = []

    # Collect on-route vehicle IDs
    vehicle_ids = []
    for v in vehicles_list:
        if v.get("IsOnRoute") is False:
            continue
        vid = v.get("VehicleID")
        if vid is not None:
            vehicle_ids.append(str(vid))

    if not vehicle_ids:
        return jsonify({"stop_id": route_stop_id, "arrivals": []})

    # Get estimates for all vehicles
    id_string = ",".join(vehicle_ids)
    raw = transloc.fetch_transloc(
        "GetVehicleRouteStopEstimates",
        params={
            "vehicleIdStrings": id_string,
            "quantity": "10",  # Get more stops to increase chance of matching
        },
    )

    if not isinstance(raw, list) or not raw:
        return jsonify({"stop_id": route_stop_id, "arrivals": []})

    # Flatten all arrivals and filter to requested stop
    all_arrivals = []
    for entry in raw:
        vid = entry.get("VehicleID")
        est_list = entry.get("Estimates", []) or []

        for est in est_list:
            stop_id = est.get("RouteStopID")
            if stop_id != route_stop_id:
                continue

            seconds = est.get("Seconds")
            # Skip departed buses (negative seconds) unless still useful
            if seconds is not None and seconds < 0:
                continue

            all_arrivals.append({
                "vehicle_id": vid,
                "stop_id": stop_id,
                "stop_name": est.get("Description"),
                "seconds_until_arrival": seconds,
                "timestamp_raw": est.get("EstimateTime") or est.get("Time"),
                "on_time_status": est.get("OnTimeStatus"),
                "is_arriving": est.get("IsArriving"),
            })

    # Sort by seconds_until_arrival (soonest first)
    all_arrivals.sort(key=lambda x: x.get("seconds_until_arrival") or 9999)

    # Return top 5 arrivals
    return jsonify({
        "stop_id": route_stop_id,
        "arrivals": all_arrivals[:5],
    })


@app.route("/api/health/transloc")
def api_health_transloc():
    """Debug endpoint to check TransLoc API connectivity and vehicle counts."""
    raw = transloc.fetch_transloc(
        "GetMapVehiclePoints",
        params={"apiKey": API_KEY, "isPublicMap": "true"},
    )

    # Parse response
    if isinstance(raw, dict):
        vehicles_list = (
            raw.get("Vehicles")
            or raw.get("vehicles")
            or raw.get("Data")
            or raw.get("data")
            or []
        )
    elif isinstance(raw, list):
        vehicles_list = raw
    else:
        vehicles_list = []

    # Count total and on-route vehicles
    vehicles_total = len(vehicles_list)
    on_route_vehicles = [v for v in vehicles_list if v.get("IsOnRoute") is not False]
    vehicles_on_route = len(on_route_vehicles)

    # Get first 10 vehicle IDs that are on route
    vehicle_ids_on_route = [
        v.get("VehicleID") for v in on_route_vehicles[:10] if v.get("VehicleID") is not None
    ]

    return jsonify({
        "vehicles_total": vehicles_total,
        "vehicles_on_route": vehicles_on_route,
        "vehicle_ids_on_route": vehicle_ids_on_route,
    })


if __name__ == "__main__":
    debug_mode = os.getenv("FLASK_DEBUG", "False").lower() == "true"
    host = os.getenv("FLASK_HOST", "127.0.0.1")
    port = int(os.getenv("FLASK_PORT", "3000"))
    
    app.run(debug=debug_mode, host=host, port=port)  