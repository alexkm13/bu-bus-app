## Created to call BU Bus API endpoints on TransLoc
import json
import requests
import time
from flask import Flask, jsonify

# TransLoc base website for API calls
TRANSLOC_BASE = "https://bu.transloc.com/Services/JSONPRelay.svc"

def fetch_transloc(endpoint, params):
    """
    Call a TransLoc JSONPRelay endpoint and return parsed JSON.

    endpoint example:
      "GetRoutesForMapWithScheduleWithEncodedLine"
      "GetMapVehiclePoints"
    """
    url = f'{TRANSLOC_BASE}/{endpoint}'
    resp = requests.get(url, params=params or {})
    resp.raise_for_status()
    text = resp.text.strip()

    print(f"\n[DEBUG] Raw response from {endpoint} (first 300 chars):\n{text[:300]}\n")

    # Many of these are plain JSON. Some are JSONP like: callback123({...});
    if text.startswith("callback") or text.startswith("jQuery"):
        first_paren = text.find("(")
        last_paren = text.rfind(")")
        json_str = text[first_paren + 1:last_paren]
    else:
        json_str = text

    data = json.loads(json_str)
    print(f"[DEBUG] Parsed type for {endpoint}: {type(data)}, keys: {list(data.keys()) if isinstance(data, dict) else 'n/a'}")
    return data
