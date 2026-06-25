<div align="center">

# 🌿 PlantoDex
**A Pokémon GO-inspired plant collection app for Android.**  
Point your camera at a plant, identify it, and catch it into your growing personal Dex — complete with rarity badges, species info, and a world of flora to discover.

![Status](https://img.shields.io/badge/status-active%20development-brightgreen)
![Phase](https://img.shields.io/badge/phase-6%20Polish-blue)
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
| Gym / Map | Map of where you scanned each plant *(planned)* |
| Trainer profile | Profile screen *(planned)* |

Every scan adds to a personal collection instead of disappearing into a search history. A walk becomes a chance to find something new to catch.

---

## Core Loop

```
📷 Scan  →  🔍 Identify  →  ✨ Catch  →  📖 Collect
```

Everything else — the map, the profile, the streaks — is in service of this loop, not a distraction from it.

---

## Tech Stack

| Layer | Library |
|---|---|
| UI | Flutter |
| Camera | image_picker / camera |
| Networking | http |
| Local Storage | Drift (SQLite) |
| Architecture | Provider + Repository pattern |

### APIs

| API | Purpose | Status |
|---|---|---|
| Pl@ntNet | Plant identification from photo | ✅ Active |
| Wikipedia | Species descriptions & reference data | ✅ Active |
| GBIF | Occurrence-based rarity classification | ✅ Active |
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
| 📖 **Dex** | Personal collection album, sorted by rarity |
| 🗺️ **Map** | Where each plant was scanned *(planned)* |
| 👤 **Profile** | Levels, achievements, streaks *(planned)* |

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
- Drift database schema for caught plants
- Save successful catches to local DB

### ✅ Phase 5 — Dex Screen
- Flat album grid backed by a Drift stream query
- Cards sorted by rarity tier then most recently caught
- Rarity pill on every card, determined by GBIF at catch time
- Delete with confirmation dialog

### 🚧 Phase 6 — Polish *(in progress)*
* [x] GBIF-based dynamic rarity (no hardcoded lists)
* [x] Flicker-free rarity reveal fully loaded before result screen shows
* [x] Rarity color theming across all surfaces
* [x] Improved plant scanning and identification flow
* [x] Added animated loading screens with unique themes for each rarity tier
* [x] Enhanced Dex cards with additional plant information
* [ ] Catch and scan animations
* [ ] Search over saved plants
* [ ] Performance optimization


### 🔮 Later
- Map screen (real implementation)
- Profile screen (levels, achievements, streaks)
- Background sync queue for offline catches

---

## Goals

- **Make learning about plants feel like progress**, not a chore.
- **Borrow what makes collecting games satisfying** — rarity tiers, a Dex to fill, a sense of "what haven't I found yet" — and apply it to something genuinely useful.
- **Encourage going outside and looking closer.** Every walk is a chance to find a new catch.
- **Keep the core loop simple.** Scan → identify → catch → collect.

---

## Status

> This project is under active, iterative development. The roadmap above is the source of truth for current progress; checkboxes are updated as phases complete.

---

Made with ☕ and probably too much love for tiny ui details.
