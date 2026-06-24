# 🌿 PlantoDex

**PlantoDex** is a Pokémon GO-inspired Android app for plants. Scan a plant with your camera, let the API identify it, and "catch" it into your personal Dex, complete with rarity badges, species info, and a growing collection to discover.

> ✅ **Status:** Core features through **Phase 5** are complete. Currently focused on optimization, refinement, and preparing for future features.

---

## Concept

| Pokémon GO         | PlantoDex                                     |
| ------------------ | --------------------------------------------- |
| Catch wild Pokémon | Scan real plants                              |
| Pokédex            | PlantoDex                                     |
| Rarity tiers       | Rarity badges (common → legendary)            |
| Gym / Map          | Map of where you scanned each plant (planned) |
| Trainer profile    | Profile screen (planned)                      |

Point your camera at a plant, snap a photo, and the app identifies the species and pulls up care info, turning plant ID into a collectible, game-like experience.

---

## Tech Stack

* **UI:** Jetpack Compose
* **Camera:** CameraX
* **Networking:** Retrofit
* **Local Storage:** Room
* **Architecture:** Standard Android app (Compose navigation, lifecycle-aware camera binding)

---

## APIs

| API          | Purpose                                             | Status     |
| ------------ | --------------------------------------------------- | ---------- |
| PlantNet     | Plant identification from photo                     | ✅ Current  |
| ~~Perenual~~ | Plant species information                           | ❌ Replaced |
| ~~Trefle~~   | Plant species information                           | ❌ Replaced |
| Wikipedia    | Plant information, descriptions, and reference data | ✅ Current  |

### API Evolution

1. PlantNet + ~~Perenual~~
2. PlantNet + ~~Trefle~~
3. PlantNet + Wikipedia *(current implementation)*

---

## App Structure

Four-tab bottom navigation shell:

* **Scan**: Camera capture + identification flow
* **Dex**: Grid of caught/discovered plants
* **Map**: *(planned)* Shows where each plant was scanned/caught, pinned on a map
* **Profile**: *(planned)* Levels, achievements, streaks

---

## Roadmap

### Phase 1 — Skeleton

* [x] Create Compose project in Android Studio and add required dependencies
* [x] Build the 4-screen navigation shell (Scan / Dex / Map / Profile)
* [x] Create placeholder screens and navigation flow

### Phase 2 — Camera

* [x] Implement CameraX preview and image capture
* [x] Handle camera permissions and lifecycle binding
* [x] Add client-side image resize/compression

### Phase 3 — API Integration

* [x] Integrate PlantNet for plant identification
* [x] Integrate plant information APIs
* [x] Build loading → result flow after capture
* [x] Add offline detection and no-signal handling

### Phase 4 — Catch Result + Storage

* [x] Build catch result screen
* [x] Set up Room database schema
* [x] Save successful catches locally

### Phase 5 — Dex Screen

* [x] Build Dex grid UI backed by Room
* [x] Add plant collection browsing
* [x] Add search functionality
* [x] Implement discovered/caught plant tracking

### Phase 6 — Polish *(Current Focus)*

* [ ] Performance optimization
* [ ] UI refinement and visual polish
* [ ] Catch/scan animations
* [ ] Rarity-based color theming improvements
* [ ] Improved empty and locked states
* [ ] Code cleanup and architecture refinement

---

## Future Features

### Map Screen

* View scan locations on an interactive map
* Track where plants were discovered

### Profile Screen

* Trainer-style profile
* Levels and progression
* Achievements and milestones
* Scan streaks

### Possible Future Enhancements

* Background sync queue for offline catches
* Seasonal plant events
* Collection statistics
* Achievement system
* Community features

---

## Goals & Motivation

Plant ID apps tend to be purely utilitarian: point, identify, done. PlantoDex exists to make that moment feel like *discovery* instead of a lookup:

* **Make learning about plants feel like progress**, not a chore. Every scan adds to a personal collection instead of disappearing into a search history.
* **Borrow what makes collecting games satisfying**: rarity tiers, a Dex to fill out, a sense of "what haven't I found yet," and apply that to something genuinely useful (knowing what's growing around you).
* **Encourage going outside and looking closer.** A walk becomes a chance to find something new to catch, not just exercise.
* **Keep the core loop simple.** Scan → identify → catch → collect. Everything else (map, profile, streaks) exists to support that loop.

This is a personal project exploring the intersection of plant identification and game-inspired collection mechanics.

---

## Notes

This project is under active development. Core functionality through Phase 5 has been completed, and current work is focused on optimization, polishing the user experience, and preparing future features.
