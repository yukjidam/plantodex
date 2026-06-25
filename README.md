<div align="center">

# 🌿 PlantoDex
**A Pokémon GO-inspired plant collection app for Android.**  
Point your camera at a plant, identify it, and catch it into your growing personal Dex — complete with rarity badges, species info, and a live map of every plant you've ever found.

![Status](https://img.shields.io/badge/status-active%20development-brightgreen)
![Phase](https://img.shields.io/badge/phase-7%20Map-blue)
![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white)
![Language](https://img.shields.io/badge/language-Dart%20%2F%20Flutter-7F52FF?logo=dart&logoColor=white)

</div>

---

## The Idea

Plant ID apps are purely utilitarian: point, identify, done. PlantoDex turns that moment into *discovery*.

| Pokémon GO | PlantoDex |
|---|---|
| Catch wild Pokémon | Scan real plants |
| Pokédex | PlantoDex |
| Rarity tiers | Rarity badges (Common → Legendary) |
| Gym / Map | Map of where you scanned each plant |
| Trainer profile | Profile screen *(planned)* |

Every scan adds to a personal collection instead of disappearing into a search history. A walk becomes a chance to find something new to catch.

---

## Core Loop

```
📷 Scan  →  🔍 Identify  →  ✨ Catch  →  📖 Collect  →  🗺️ Explore
```

Everything else — the profile, the streaks — is in service of this loop, not a distraction from it.

---

## Tech Stack

| Layer | Library |
|---|---|
| UI | Flutter |
| Camera | image_picker / camera |
| Networking | http |
| Local Storage | Floor (SQLite ORM) |
| Architecture | Provider + Repository pattern |
| Map | flutter_map (OpenStreetMap) |
| GPS | geolocator |
| Reverse Geocoding | geocoding |

### APIs

| API | Purpose | Status |
|---|---|---|
| Pl@ntNet | Plant identification from photo | ✅ Active |
| Wikipedia | Species descriptions & reference data | ✅ Active |
| GBIF | Occurrence-based rarity classification | ✅ Active |
| OpenStreetMap | Free map tiles (no API key) | ✅ Active |
| ~~Perenual~~ | Plant species information | ❌ Replaced |
| ~~Trefle~~ | Plant species information | ❌ Replaced |

---

## Rarity System

Rarity is determined at catch time by querying the **GBIF (Global Biodiversity Information Facility)** API — the world's largest open biodiversity database. The scientific name returned by Pl@ntNet is matched to GBIF's backbone taxonomy, and the total number of recorded occurrences worldwide determines the tier.

| Occurrences (global) | Rarity |
|---|---|
| < 1,000 | 🔥 Legendary |
| 1,000 – 4,999 | 💜 Rare |
| 5,000 – 19,999 | 🌸 Epic |
| 20,000+ | 🌿 Common |

This means geographically restricted endemics — like Philippine Rafflesia or Waling-waling orchids — naturally surface as Legendary without any hardcoded lists. The rarity is real.

---

## App Structure

Four-tab bottom navigation:

| Tab | Description |
|---|---|
| 📷 **Scan** | Camera capture + identification flow |
| 📖 **Dex** | Personal collection album, sorted and grouped by rarity |
| 🗺️ **Map** | Where each plant was scanned — rarity-colored pins, tap to view detail |
| 👤 **Profile** | Levels, achievements, streaks *(planned)* |

---

## Map Feature

The Map tab shows every caught plant pinned to the location where it was scanned, using **OpenStreetMap tiles via `flutter_map`** — fully free, no API key required. GPS coordinates are captured at scan time and persisted alongside each catch.

### Pin design

| Rarity | Pin color | Extra treatment |
|---|---|---|
| 🌿 Common | Green | Standard pin |
| 🌸 Epic | Pink | Standard pin |
| 💜 Rare | Purple | Soft glow halo |
| 🔥 Legendary | Orange | Bright glow halo |

Tapping a pin surfaces a compact info card showing the plant's name, scientific name, rarity badge, catch date, and resolved place name (e.g. "Poblacion, Tarlac City"). The card links through to the full plant detail screen.

### Stacked pin handling

When multiple plants are caught at nearly the same location, pins are automatically spread into a small circle so every pin remains individually visible and tappable — no zooming required.

### Architecture

```
MapScreen
  ├── flutter_map (OSM tile layer)
  ├── MarkerLayer  ←  List<MapCatchMarker> (spread-deduped)
  │     └── CatchMarkerWidget (rarity-colored pin)
  ├── MarkerLayer  ←  live user location dot (blue)
  ├── Info card overlay (tapped pin → place name via GeocodingService)
  ├── Empty state overlay (no catches with GPS yet)
  ├── MapLegendWidget (bottom-left)
  └── Re-center FAB (centers on catch cluster, falls back to GPS)
MapRepository       ←  wraps Floor CaughtPlantDao stream
LocationService     ←  wraps geolocator
GeocodingService    ←  reverse geocoding with in-memory cache
MapCatchMarker      ←  display model (maps from CaughtPlant entity)
```

---

## System Requirements

These are the minimum hardware and software requirements to **run** PlantoDex on an Android device.

| Requirement | Minimum |
|---|---|
| **Android version** | Android 6.0 (Marshmallow, API 23) |
| **RAM** | 2 GB |
| **Storage** | 100 MB free (grows with collection size) |
| **Camera** | Required — any rear camera supported |
| **GPS / Location** | Required for map pins; app functions without it but plants won't appear on the map |
| **Internet** | Required for plant identification (Pl@ntNet, Wikipedia, GBIF) and map tiles; offline state is handled gracefully |
| **Processor** | Any ARMv7 or ARM64 chipset (covers virtually all Android phones since 2013) |

> Location permission can be set to "While using the app" — PlantoDex never requests background location.

---

## Roadmap

### ✅ Phase 1 — Skeleton
- Flutter project setup with all dependencies
- 4-screen navigation shell (Scan / Dex / Map / Profile) with bottom nav
- Stub screens with placeholder content

### ✅ Phase 2 — Camera
- Camera preview + capture on the Scan screen
- Camera permissions and lifecycle handling
- Client-side image resize/compression after capture

### ✅ Phase 3 — API Integration
- Pl@ntNet + Wikipedia service integrations
- Loading → result UI flow after capture
- Offline check + "no signal" blocking state

### ✅ Phase 4 — Catch Result + Storage
- Catch result screen (name, scientific name, rarity badge, care info)
- Floor database schema for caught plants
- Save successful catches to local DB

### ✅ Phase 5 — Dex Screen
- Flat album grid backed by a Floor stream query
- Cards sorted by rarity tier then most recently caught
- Rarity pill on every card, determined by GBIF at catch time
- Delete with confirmation dialog

### ✅ Phase 6 — Polish
* [x] GBIF-based dynamic rarity (no hardcoded lists)
* [x] Flicker-free rarity reveal — fully loaded before result screen shows
* [x] Rarity color theming across all surfaces
* [x] Improved plant scanning and identification flow
* [x] Animated loading screens with unique themes for each rarity tier
* [x] Enhanced Dex cards with additional plant information (catch date, location, ID confidence, XP)
* [x] Dedicated plant detail screen with tap-to-zoom full-screen photo viewer
* [x] Functional Dex search (name, scientific name, family)
* [x] Rarity filter chips and sort control (newest, A–Z, rarity) on the Dex
* [x] Dex grouped into per-rarity sections with styled section headers
* [x] Rare and Legendary catches get a solid-color rarity-accent border
* [x] Performance pass: capped image decode resolution on Dex thumbnails and hero image, converted Dex grid to lazily-built `SliverGrid`, isolated expensive card repaints behind `RepaintBoundary`, moved scan frame-quality updates off the main `setState` path
* [x] Catch and scan animations

### ✅ Phase 7 — Map
* [x] Map screen with real OSM tiles via `flutter_map`
* [x] Rarity-colored pins with glow treatment for Rare/Legendary catches
* [x] Tap-to-show info card overlay with plant name, scientific name, rarity badge, catch date, and resolved place name
* [x] `MapCatchMarker` display model mapping cleanly from `CaughtPlant` Floor entity
* [x] `MapRepository` wired to live Floor DB stream — map updates in real time
* [x] `LocationService` wired to device GPS
* [x] GPS coordinates captured at scan time and persisted to `CaughtPlant` (Floor DB migration v1→v2)
* [x] Map centers on catch cluster on load; falls back to GPS then Tarlac City default
* [x] Re-center FAB centers on catch cluster first, GPS fallback second
* [x] Stacked pin spreading — nearby catches arranged in a circle so every pin is tappable without zooming
* [x] Live user location dot (blue) rendered as a separate marker layer
* [x] Reverse geocoding via `geocoding` package — pins and Dex cards show place names instead of raw coordinates, with in-memory cache to avoid redundant lookups
* [x] Place name shown in Dex card location row and plant detail screen
* [x] Info card arrow wired to `PlantDetailScreen`
* [x] Empty state overlay when no catches with GPS exist yet
* [x] `minZoom` raised from 13 to 4 — can zoom out to see catches across regions
* [x] Map legend widget
* [x] Info card image renders local photo file correctly

### 🔮 Later
- Profile screen (levels, achievements, streaks)
- Background sync queue for offline catches
- Push notification for rare plant sightings nearby

---

## Goals

- **Make learning about plants feel like progress**, not a chore.
- **Borrow what makes collecting games satisfying** — rarity tiers, a Dex to fill, a sense of "what haven't I found yet" — and apply it to something genuinely useful.
- **Encourage going outside and looking closer.** Every walk is a chance to find a new catch.
- **Keep the core loop simple.** Scan → identify → catch → collect → explore.

---

## Status

> This project is under active, iterative development. The roadmap above is the source of truth for current progress; checkboxes are updated as phases complete.

---

Made with ☕ and probably too much love for tiny ui details.
