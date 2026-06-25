<div align="center">

# 🌿 PlantoDex
**A Pokémon GO-inspired plant collection app for Android.**  
Point your camera at a plant, identify it, and catch it into your growing personal Dex — complete with rarity badges, species info, and a world of flora to discover.

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

The Map tab shows every caught plant pinned to the location where it was scanned, using **OpenStreetMap tiles via `flutter_map`** — fully free, no API key required.

### Pin design

| Rarity | Pin color | Extra treatment |
|---|---|---|
| 🌿 Common | Green | Standard pin |
| 🌸 Epic | Pink | Standard pin |
| 💜 Rare | Purple | Soft glow halo |
| 🔥 Legendary | Orange | Bright glow halo |

Tapping a pin surfaces a compact info card showing the plant's name, scientific name, rarity badge, and catch date. The card links through to the full plant detail screen (same as tapping a Dex card).

### Architecture

```
MapScreen
  ├── flutter_map (OSM tile layer)
  ├── MarkerLayer  ←  List<MapCatchMarker>
  │     └── CatchMarkerWidget (rarity-colored pin)
  ├── Info card overlay (tapped pin)
  ├── MapLegendWidget (bottom-left)
  └── Re-center FAB
MapRepository       ←  wraps Floor CaughtPlantDao stream
LocationService     ←  wraps geolocator
MapCatchMarker      ←  display model (maps from CaughtPlant entity)
```

### Wiring checklist (to complete Phase 7)

- [ ] Add `flutter_map`, `latlong2`, `geolocator`, `intl` to `pubspec.yaml` (see `PUBSPEC_ADDITIONS.yaml`)
- [ ] Add `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION` to `AndroidManifest.xml`
- [ ] Add `latitude` + `longitude` columns to `CaughtPlant` Floor entity + migration
- [ ] Record device location at scan time and persist to the new columns
- [ ] Uncomment `MapRepository.watchAll()` body and inject `CaughtPlantDao`
- [ ] Uncomment `LocationService.getCurrentLocation()` body
- [ ] Replace `_dummyMarkers` in `MapScreen` with `MapRepository.watchAll()` stream
- [ ] Replace `_initialCenter` fallback with real device location
- [ ] Wire info card arrow → `PlantDetailScreen(id: marker.plantId)`

---

## System Requirements

| Requirement | Value |
|---|---|
| Minimum Android version | Determined by Flutter's default `minSdkVersion` for the installed SDK (not pinned in `build.gradle.kts` — it delegates to `flutter.minSdkVersion`). Not yet pinned down exactly; run `flutter build apk` and check the merged manifest, or hardcode `minSdk` in `android/app/build.gradle.kts` for a guaranteed number. |
| Target / Compile SDK | Android API 36 (resolved from installed Android SDK 36.1.0 via `flutter.targetSdkVersion` / `flutter.compileSdkVersion`) |
| Flutter SDK | 3.41.6 (stable channel) |
| Dart SDK | `>=3.3.0 <4.0.0` (per `pubspec.yaml`); 3.11.4 installed |
| Java/Kotlin | JDK 17 (`sourceCompatibility` / `kotlinOptions.jvmTarget`) |
| Camera | Required (core scan flow) |
| Storage | Local SQLite via Floor — collection grows with usage |
| Network | Required for identification (Pl@ntNet, Wikipedia, GBIF) and map tiles (OSM); offline state is handled gracefully but scanning and the map need connectivity |
| Location | Optional — map falls back to a default center if GPS is unavailable or denied |

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
* [x] Flicker-free rarity reveal fully loaded before result screen shows
* [x] Rarity color theming across all surfaces
* [x] Improved plant scanning and identification flow
* [x] Added animated loading screens with unique themes for each rarity tier
* [x] Enhanced Dex cards with additional plant information (catch date, location placeholder, ID confidence, XP)
* [x] Dedicated plant detail screen, opened from the Dex, with a tap-to-zoom full-screen photo viewer
* [x] Functional Dex search (name, scientific name, family)
* [x] Rarity filter chips and sort control (newest, A–Z, rarity) on the Dex
* [x] Dex grouped into per-rarity sections, with special gradient styling for Rare/Legendary headers
* [x] Rare and Legendary catches get distinct card treatment — static glow border for Rare, animated shimmer sweep for Legendary
* [x] Performance pass: capped image decode resolution on Dex thumbnails and the detail screen's hero image, converted the Dex grid to a lazily-built `SliverGrid`, isolated expensive card repaints behind `RepaintBoundary`, and moved the scan screen's live frame-quality updates off the main `setState` path so the camera UI no longer rebuilds in full on every analysed frame
* [x] Catch and scan animations
* [x] Performance optimization

### 🚧 Phase 7 — Map *(in progress)*
* [x] Map screen skeleton: real OSM tiles rendering via `flutter_map`
* [x] Static dummy pins with rarity-colored markers and glow treatment for Rare/Legendary
* [x] Tap-to-show info card overlay with plant name, scientific name, rarity badge, and catch date
* [x] `MapCatchMarker` display model (maps cleanly from existing `CaughtPlant` Floor entity)
* [x] `MapRepository` stub (Floor stream wiring commented and ready)
* [x] `LocationService` stub (geolocator wiring commented and ready)
* [x] Map legend widget
* [x] Re-center FAB
* [ ] Record GPS coordinates at scan time and persist to `CaughtPlant` (requires Floor migration)
* [ ] Wire `MapRepository` to live Floor stream
* [ ] Wire `LocationService` to device GPS; center map on current location
* [ ] Connect info card arrow to `PlantDetailScreen`
* [ ] Handle offline gracefully — show cached tile fragments, disable re-center when GPS unavailable

### 🔮 Later
- Profile screen (levels, achievements, streaks)
- Background sync queue for offline catches
- Map clustering for dense collections

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
