<div align="center">

# 🌿 PlantoDex

**A Pokémon GO-inspired plant collection app for Android.**  
Point your camera at a plant, identify it, and catch it into your growing personal Dex - complete with rarity badges, species info, and a world of flora to discover.

![Status](https://img.shields.io/badge/status-active%20development-brightgreen)
![Phase](https://img.shields.io/badge/phase-5%20Dex%20Screen-blue)
![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white)
![Language](https://img.shields.io/badge/language-Dart-7F52FF?logo=dart&logoColor=white)

</div>

---

## The Idea

Plant ID apps are purely utilitarian: point, identify, done. PlantoDex turns that moment into *discovery*.

| Pokémon GO | PlantoDex |
|---|---|
| Catch wild Pokémon | Scan real plants |
| Pokédex | PlantoDex |
| Rarity tiers | Rarity badges (Common → Legendary) |
| Gym / Map | Map of where you scanned each plant *(planned)* |
| Trainer profile | Profile screen *(planned)* |

Every scan adds to a personal collection instead of disappearing into a search history. A walk becomes a chance to find something new to catch, not just exercise.

---

## Core Loop

```
📷 Scan  →  🔍 Identify  →  ✨ Catch  →  📖 Collect
```

Everything else - the map, the profile, the streaks - is in service of this loop, not a distraction from it.

---

## Tech Stack

| Layer | Library |
|---|---|
| UI | Jetpack Compose |
| Camera | CameraX |
| Networking | Retrofit |
| Local Storage | Room |
| Architecture | Compose Navigation + lifecycle-aware camera binding |

### APIs

| API | Purpose | Status |
|---|---|---|
| PlantNet | Plant identification from photo | ✅ Active |
| Wikipedia | Species descriptions & reference data | ✅ Active |
| ~~Perenual~~ | Plant species information | ❌ Replaced |
| ~~Trefle~~ | Plant species information | ❌ Replaced |

---

## App Structure

Four-tab bottom navigation:

| Tab | Description |
|---|---|
| 📷 **Scan** | Camera capture + identification flow |
| 📖 **Dex** | Grid of caught and discovered plants |
| 🗺️ **Map** | Where each plant was scanned *(planned)* |
| 👤 **Profile** | Levels, achievements, streaks *(planned)* |

---

## Roadmap

### ✅ Phase 1 - Skeleton
- Compose project setup with all dependencies
- 4-screen navigation shell (Scan / Dex / Map / Profile) with bottom nav
- Stub screens with placeholder content

### ✅ Phase 2 - Camera
- CameraX preview + capture on the Scan screen
- Camera permissions and lifecycle binding
- Client-side image resize/compression after capture

### ✅ Phase 3 - API Integration
- Retrofit interfaces for identify and info endpoints
- Loading → result UI flow after capture
- Offline check + "no signal" blocking state

### ✅ Phase 4 - Catch Result + Storage
- Catch result screen (name, scientific name, rarity badge)
- Room database schema for caught plants
- Save successful catches to Room

### 🚧 Phase 5 - Dex Screen *(in progress)*
- [x] Dex grid UI backed by a Room Flow query
- [x] Sections: Recent / Legendary / Undiscovered + locked-card states
- [x] Search over saved plants
- [ ] Performance optimization

### 🔲 Phase 6 - Polish
- [ ] Port rarity color theming from HTML mockup into Compose
- [ ] Catch and scan animations
- [ ] Refined empty/locked states

### 🔮 Later
- Map screen (real implementation)
- Profile screen (levels, achievements, streaks)
- Background sync queue for offline catches

---

## Goals

- **Make learning about plants feel like progress**, not a chore.
- **Borrow what makes collecting games satisfying** - rarity tiers, a Dex to fill, a sense of "what haven't I found yet" - and apply it to something genuinely useful.
- **Encourage going outside and looking closer.** Every walk is a chance to find a new catch.
- **Keep the core loop simple.** Scan → identify → catch → collect.

---

## Status

> This project is under active, iterative development. The roadmap above is the source of truth for current progress; checkboxes are updated as phases complete.
