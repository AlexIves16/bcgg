const axios = require('axios');

// In-memory cache for OSM data
const cache = new Map();
const CACHE_TTL = 1000 * 60 * 60; // 1 hour

/**
 * Maps OSM tags to Digital Ether BiomeTypes
 */
const OSM_TO_BIOME = {
    'leisure=park': 'B_FOREST',
    'landuse=forest': 'B_FOREST',
    'natural=water': 'B_OCEAN',
    'waterway=river': 'B_OCEAN',
    'natural=mountain_range': 'B_MOUNTAINS',
    'natural=peak': 'B_MOUNTAINS',
    'landuse=residential': 'B_PLAINS',
    'landuse=commercial': 'B_PLAINS',
    'landuse=industrial': 'B_PLAINS',
    'landuse=allotments': 'B_PLAINS'
};

/**
 * Fetches OSM features for a bounding box with caching and grid-snapping
 */
async function fetchOSMFeatures(lat, lng) {
    // Snap to 0.01 grid (~1.1km) to maximize cache hits
    const snappedLat = Math.round(lat * 100) / 100;
    const snappedLng = Math.round(lng * 100) / 100;
    const margin = 0.01;
    const bbox = `${snappedLat - margin},${snappedLng - margin},${snappedLat + margin},${snappedLng + margin}`;

    if (cache.has(bbox)) {
        const cached = cache.get(bbox);
        if (Date.now() - cached.timestamp < CACHE_TTL) {
            return cached.data;
        }
    }

    const query = `
        [out:json][timeout:25];
        (
          node["leisure"="park"](${bbox});
          way["leisure"="park"](${bbox});
          node["landuse"="forest"](${bbox});
          way["landuse"="forest"](${bbox});
          node["natural"="water"](${bbox});
          way["natural"="water"](${bbox});
          node["waterway"="river"](${bbox});
          way["natural"="mountain_range"](${bbox});
          node["natural"="peak"](${bbox});
          node["landuse"~"residential|commercial|industrial|allotments"](${bbox});
          way["landuse"~"residential|commercial|industrial|allotments"](${bbox});
        );
        out body;
        >;
        out skel qt;
    `;
    
    try {
        console.log(`[OSM] Fetching data for snapped bbox: ${bbox} (Source: ${lat}, ${lng})`);
        const response = await axios.post('https://overpass-api.de/api/interpreter', `data=${encodeURIComponent(query)}`);
        cache.set(bbox, { data: response.data, timestamp: Date.now() });
        return response.data;
    } catch (error) {
        if (error.response && error.response.status === 429) {
            console.warn('[OSM] Rate limited (429). Using partial/empty data.');
        } else {
            console.error('Error fetching OSM data:', error.message);
        }
        return null;
    }
}

/**
 * Estimates biome based on OSM features
 */
function resolveBiomeFromOSM(lat, lng, osmData) {
    if (!osmData || !osmData.elements) return 'B_PLAINS';

    // Simple proximity check: Find the closest feature
    let bestBiome = 'B_PLAINS';
    let minDistance = 0.002; // ~200m radius for feature influence

    for (const el of osmData.elements) {
        if (!el.tags) continue;
        
        const elLat = el.lat || (el.center && el.center.lat);
        const elLng = el.lon || (el.center && el.center.lon);
        
        if (!elLat || !elLng) continue;

        const dist = Math.sqrt(Math.pow(lat - elLat, 2) + Math.pow(lng - elLng, 2));
        if (dist < minDistance) {
            for (const [tag, biome] in Object.entries(OSM_TO_BIOME)) {
                const [k, v] = tag.split('=');
                if (el.tags[k] === v) {
                    minDistance = dist;
                    bestBiome = biome;
                    break;
                }
            }
        }
    }
    return bestBiome;
}

module.exports = { fetchOSMFeatures, resolveBiomeFromOSM };
