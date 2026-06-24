# 🌿 PlantoDex

**PlantoDex** is a Pokémon GO-inspired Android app for plants. Scan a plant with your camera, let the API identify it, and "catch" it into your personal Dex, complete with rarity badges, species info, and a growing collection to discover.

> 🚧 **Status:** In active development, currently in **Phase 5 (Dex Screen)**, optimizing the Dex Screen and local database.

---

## Concept

| Pokémon GO | PlantoDex |
|---|---|
| Catch wild Pokémon | Scan real plants |
| Pokédex | PlantoDex |
| Rarity tiers | Rarity badges (common → legendary) |
| Gym / Map | Map of where you scanned each plant (planned) |
| Trainer profile | Profile screen (planned) |

Point your camera at a plant, snap a photo, and the app identifies the species and pulls up care info, turning plant ID into a collectible, game-like experience.

---

## Tech Stack

- **UI:** Jetpack Compose
- **Camera:** CameraX
- **Networking:** Retrofit
- **Local storage:** Room
- **Architecture:** Standard Android app (Compose navigation, lifecycle-aware camera binding)

## APIs

| API          | Purpose                                             | Status     |
| ------------ | --------------------------------------------------- | ---------- |
| PlantNet     | Plant identification from photo                     | ✅ Current  |
| ~~Perenual~~ | Plant species information                           | ❌ Replaced |
| ~~Trefle~~   | Plant species information                           | ❌ Replaced |
| Wikipedia    | Plant information, descriptions, and reference data | ✅ Current  |

---

## App Structure

Four-tab bottom navigation shell:

- **Scan**: camera capture + identification flow
- **Dex**: grid of caught/discovered plants
- **Map**: *(planned)* shows where each plant was scanned/caught, pinned on a map
- **Profile**: *(planned)* levels, achievements, streaks

---

## Roadmap

### Phase 1 — Skeleton
- [x] Create Compose project in Android Studio, add all dependencies above
- [x] Build the 4-screen navigation shell (Scan / Dex / Map / Profile) with bottom nav, matching the mockup's tabs
- [x] Stub each screen with placeholder content so navigation is fully wired before any real feature work

### Phase 2 — Camera
- [x] Implement CameraX preview + capture on the Scan screen
- [x] Handle camera permissions and lifecycle binding
- [x] Add client-side image resize/compression after capture

### Phase 3 — API Integration 
- [x] Define Retrofit interfaces for the 3 endpoints (confirm → identify → info)
- [x] Build the loading → result UI flow after capture
- [x] Add the offline check + "no signal" blocking state before allowing a scan

### Phase 4 — Catch Result + Storage 
- [x] Build the "catch" result screen (name, scientific name, rarity badge) from the API response
- [x] Set up Room database and schema for caught plants
- [x] Save successful catches to Room

### Phase 5 — Dex Screen 🚧 *(in progress, currently optimizing)*
- [x] Build the Dex grid UI, backed by a Room Flow query
- [x] Add sections (Recent / Legendary / Undiscovered) and locked-card states
- [x] Add search over saved plants

### Phase 6 — Polish
- [ ] Port the rarity color theming from the HTML mockup's CSS variables into Compose
- [ ] Add catch/scan animations
- [ ] Refine empty/locked states

### Later / Not Day-One
- Map screen (real implementation)
- Profile screen (levels, achievements, streaks)
- Background sync queue for offline catches, if it turns out to be needed

---

## Goals & Motivation

Plant ID apps tend to be purely utilitarian: point, identify, done. PlantoDex exists to make that moment feel like *discovery* instead of a lookup:

- **Make learning about plants feel like progress**, not a chore. Every scan adds to a personal collection instead of disappearing into a search history.
- **Borrow what makes collecting games satisfying**: rarity tiers, a Dex to fill out, a sense of "what haven't I found yet," and apply that to something genuinely useful (knowing what's growing around you).
- **Encourage going outside and looking closer.** A walk becomes a chance to find something new to catch, not just exercise.
- **Keep the core loop simple.** Scan → identify → catch → collect. Everything else (map, profile, streaks) is in service of that loop, not a distraction from it.

This is a personal project to explore that idea — part plant-ID tool, part lightweight collecting game.

---

## Notes

This project is under active, iterative development. The roadmap above is the source of truth for current progress; check boxes are updated as phases complete.
