/**
 * safety-map.js
 * --------------
 * Framework-agnostic, drop-in map widget that renders place-level safety
 * scores as red<->green shaded markers on a Leaflet map.
 *
 * Dependencies (load before this script, or via your bundler):
 *   - Leaflet.js  (https://leafletjs.com)  — CSS + JS
 *
 * Usage (plain HTML):
 *   <div id="safety-map" style="height:600px"></div>
 *   <script src="leaflet.js"></script>
 *   <script src="safety-map.js"></script>
 *   <script>
 *     const map = new SafetyMap('safety-map', { center: [21.1458, 79.0882], zoom: 12 });
 *     map.loadFromUrl('safety_scores.json');   // or map.loadData(jsonObject)
 *   </script>
 *
 * Usage (React/Vue/any bundler):
 *   import 'leaflet/dist/leaflet.css';
 *   import L from 'leaflet';
 *   window.L = L; // this module expects a global L, or refactor the two lines
 *                 // below to `import L from 'leaflet'` directly.
 *   import { SafetyMap } from './safety-map.js';
 *
 * Data contract (matches output/safety_scores.json from the Python pipeline):
 *   {
 *     "places": [
 *       {
 *         "place": "Sitabuldi",
 *         "lat": 21.148, "lon": 79.081,
 *         "safety_score": 62.3,          // 0-100, 100 = safest
 *         "risk_tier": "Moderate",
 *         "kmeans_tier": "Moderate",
 *         "total_incidents": 12,
 *         "high_severity_count": 2,
 *         "top_crime_types": [{ "Crime_Type": "Theft", "count": 5 }, ...]
 *       }, ...
 *     ]
 *   }
 */

(function (root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = factory();
  } else {
    root.SafetyMap = factory();
  }
})(typeof self !== "undefined" ? self : this, function () {
  "use strict";

  const DEFAULT_OPTIONS = {
    center: [21.1458, 79.0882], // Nagpur
    zoom: 12,
    minZoom: 10,
    maxZoom: 18,
    tileUrl: "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
    tileAttribution:
      '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
    minRadius: 9,
    maxRadius: 26,
    onMarkerClick: null, // (placeRecord) => void
  };

  // Calm Emergency Intelligence Palette: Emergency Red (#DC2626) -> Amber (#F59E0B) -> Safety Green (#16A34A)
  const COLOR_STOPS = [
    { score: 0, color: [220, 38, 38] },   // Emergency Red #DC2626 (Immediate Danger)
    { score: 25, color: [234, 88, 12] },  // Orange-Red #EA580C (High Risk)
    { score: 50, color: [245, 158, 11] }, // Amber #F59E0B (Potential Risk)
    { score: 75, color: [74, 222, 128] }, // Soft Green #4ADE80 (Safe)
    { score: 100, color: [22, 163, 74] }, // Safety Green #16A34A (Very Safe)
  ];

  function lerp(a, b, t) {
    return a + (b - a) * t;
  }

  function scoreToColor(score) {
    const s = Math.max(0, Math.min(100, score));
    for (let i = 0; i < COLOR_STOPS.length - 1; i++) {
      const cur = COLOR_STOPS[i];
      const next = COLOR_STOPS[i + 1];
      if (s >= cur.score && s <= next.score) {
        const t = (s - cur.score) / (next.score - cur.score);
        const rgb = [
          Math.round(lerp(cur.color[0], next.color[0], t)),
          Math.round(lerp(cur.color[1], next.color[1], t)),
          Math.round(lerp(cur.color[2], next.color[2], t)),
        ];
        return `rgb(${rgb[0]}, ${rgb[1]}, ${rgb[2]})`;
      }
    }
    return "rgb(120,120,120)";
  }

  function scoreToRadius(score, totalIncidents, maxIncidents, opts) {
    // Radius primarily reflects incident volume (visibility of "how much
    // signal" backs the score), scaled between minRadius..maxRadius.
    const ratio = maxIncidents > 0 ? totalIncidents / maxIncidents : 0;
    return Math.round(lerp(opts.minRadius, opts.maxRadius, Math.sqrt(ratio)));
  }

  function buildPopupHtml(place) {
    const crimes = (place.top_crime_types || [])
      .map((c) => `<li>${c.Crime_Type} &times; ${c.count}</li>`)
      .join("");
    return `
      <div class="safety-popup">
        <h4>${place.place}</h4>
        <div class="safety-popup-score" style="color:${scoreToColor(place.safety_score)}">
          ${place.safety_score.toFixed(1)} / 100
        </div>
        <div class="safety-popup-tier">${place.risk_tier}</div>
        <div class="safety-popup-stats">
          <span>${place.total_incidents} incidents logged</span>
          <span>${place.high_severity_count} high-severity</span>
        </div>
        ${crimes ? `<ul class="safety-popup-crimes">${crimes}</ul>` : ""}
      </div>`;
  }

  class SafetyMap {
    constructor(containerId, options) {
      if (typeof L === "undefined") {
        throw new Error("SafetyMap requires Leaflet (global `L`) to be loaded first.");
      }
      this.opts = Object.assign({}, DEFAULT_OPTIONS, options || {});
      this.map = L.map(containerId, {
        center: this.opts.center,
        zoom: this.opts.zoom,
        minZoom: this.opts.minZoom,
        maxZoom: this.opts.maxZoom,
      });
      L.tileLayer(this.opts.tileUrl, {
        attribution: this.opts.tileAttribution,
        maxZoom: this.opts.maxZoom,
      }).addTo(this.map);

      this.markersLayer = L.layerGroup().addTo(this.map);
      this.places = [];
      this._activeTierFilter = null;
    }

    async loadFromUrl(url) {
      const res = await fetch(url);
      if (!res.ok) throw new Error(`Failed to load ${url}: ${res.status}`);
      const data = await res.json();
      this.loadData(data);
      return data;
    }

    loadData(data) {
      this.places = (data.places || data).slice();
      this._render();
    }

    setTierFilter(tier /* string | null */) {
      this._activeTierFilter = tier;
      this._render();
    }

    _render() {
      this.markersLayer.clearLayers();
      if (!this.places.length) return;

      const maxIncidents = Math.max(...this.places.map((p) => p.total_incidents || 0));
      const visible = this._activeTierFilter
        ? this.places.filter((p) => p.risk_tier === this._activeTierFilter)
        : this.places;

      visible.forEach((place) => {
        if (place.lat == null || place.lon == null) return;
        const color = scoreToColor(place.safety_score);
        const radius = scoreToRadius(place.safety_score, place.total_incidents, maxIncidents, this.opts);

        const marker = L.circleMarker([place.lat, place.lon], {
          radius,
          fillColor: color,
          color: "#0b0f14",
          weight: 1.5,
          opacity: 0.9,
          fillOpacity: 0.85,
        });

        marker.bindTooltip(`${place.place}: ${place.safety_score.toFixed(1)}`, {
          direction: "top",
          offset: [0, -radius],
        });
        marker.bindPopup(buildPopupHtml(place));

        if (this.opts.onMarkerClick) {
          marker.on("click", () => this.opts.onMarkerClick(place));
        }

        marker.addTo(this.markersLayer);
      });
    }

    fitToMarkers() {
      const pts = this.places
        .filter((p) => p.lat != null && p.lon != null)
        .map((p) => [p.lat, p.lon]);
      if (pts.length) this.map.fitBounds(pts, { padding: [30, 30] });
    }

    destroy() {
      this.map.remove();
    }
  }

  SafetyMap.scoreToColor = scoreToColor; // exposed for legends/UI reuse

  return SafetyMap;
});
