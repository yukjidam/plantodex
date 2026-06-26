<div align="center">

# 🌿 PlantoDex
**A Pokémon GO-inspired plant collection app for Android.**  
Point your camera at a plant, identify it, and catch it into your growing personal Dex — complete with rarity badges, species info, and a live map of every plant you've ever found.

![Status](https://img.shields.io/badge/status-active%20development-brightgreen)
![Phase](https://img.shields.io/badge/phase-9%20Home-blue)
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
| Trainer profile | Profile screen — levels, badges, streaks |

Every scan adds to a personal collection instead of disappearing into a search history. A walk becomes a chance to find something new to catch.

---

## Core Loop

```
📷 Scan  →  🔍 Identify  →  ✨ Catch  →  📖 Collect  →  🗺️ Explore
```

Everything else — the profile, the streaks, the home dashboard — is in service of this loop, not a distraction from it.

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

Five-tab bottom navigation:

| Tab | Description |
|---|---|
| 🏠 **Home** | Session dashboard — daily quest, last catch, collection snapshot, streak, recent spots |
| 📖 **Dex** | Personal collection album, sorted and grouped by rarity |
| 📷 **Scan** | Camera capture + identification flow (center FAB-style tab) |
| 🗺️ **Map** | Where each plant was scanned — rarity-colored pins, tap to view detail |
| 👤 **Profile** | Levels, achievements (badges), streaks |

---

## Home Screen

The Home tab is the session-level dashboard — it answers "what's happening right now" rather than duplicating the lifetime stats on Profile. It opens with a time-of-day greeting and contextual nature hint, then surfaces the cards most relevant to the current session.

### Cards

| Card | Description |
|---|---|
| **Today at a Glance** | Three stat pills: catches today, XP earned today, total plants |
| **Daily Quest** | One rotating goal (rarity target, scan count, family challenge, etc.) with a progress bar and Go Scan shortcut. Resets at midnight, awards bonus XP on completion |
| **Last Catch Trophy** | Hero photo card of the most recent caught plant — name, scientific name, rarity badge, place name, and time elapsed |
| **Collection Snapshot** | Stacked rarity bar + per-rarity counts + most-caught family insight |
| **Next Badge Nudge** | The single closest-to-unlocking badge with a live progress bar |
| **Recent Spots** | 2–3 place name chips of recent scan locations, tappable to open Map centered on that spot |

### Daily Quest pool

Quests rotate daily from a fixed pool, seeded by the day of year so every user sees the same quest on a given day:

| # | Quest | Reward |
|---|---|---|
| 1 | Catch any plant today | +20 XP |
| 2 | Catch 3 plants today | +40 XP |
| 3 | Catch 5 plants today | +70 XP |
| 4 | Catch 1 Epic or higher plant | +50 XP |
| 5 | Catch 1 Rare or higher plant | +80 XP |
| 6 | Find a Legendary plant | +150 XP |
| 7 | Catch a plant from a new family | +60 XP |
| 8 | Catch 2 plants from the same family | +40 XP |
| 9 | Catch a plant you've never caught before (new species) | +50 XP |
| 10 | Catch a plant in a new location | +60 XP |
| 11 | Catch plants in 2 different locations today | +70 XP |
| 12 | Catch 3 plants before noon | +50 XP |
| 13 | Make your first catch of the day | +20 XP |
| 14 | Catch an Orchid family plant | +45 XP |
| 15 | Catch a fern (Polypodiaceae / Pteridaceae / Aspleniaceae) | +45 XP |

### Architecture

```
HomeScreen
  ├── SliverToBoxAdapter  ←  header (title + streak pill)
  ├── _TodayRow           ←  3 stat pills (today catches / XP / total)
  ├── _DailyQuestCard     ←  rotating quest + progress bar + Go Scan CTA
  ├── _LastCatchTrophy    ←  hero photo + rarity badge + place name
  ├── _CollectionSnapshot ←  stacked rarity bar + counts + top family
  ├── _NextBadgeNudge     ←  closest locked badge + progress bar
  └── _RecentSpots        ←  recent place name chips → Map deeplink
```

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

## Profile Feature

The Profile tab is the "trainer card" for the app — XP, levels, badges, and catch streaks, all computed live from the same Floor `CaughtPlant` stream that powers the Dex and Map.

### XP & Levels

Every catch awards XP based on rarity (Common 10 / Epic 30 / Rare 60 / Legendary 150). Total XP maps to a 10-tier level ladder with its own title, from **Seedling** (Lv.1) up to **Legendary Warden** (Lv.10).

### Reward System

Badge unlocks trigger a one-time bonus XP award (20–250 XP depending on the badge). Earning the 7-Day or 30-Day Streak badge grants a **1.5× XP multiplier** for 7 days, shown as a live chip on the header. All reward state is persisted via `shared_preferences`.

### Badges

A fixed set of badge definitions (collection milestones, rarity milestones, streak milestones, and "discovery" badges like Orchid/Fern/World/Explorer) are evaluated live against current stats. Newly unlocked badges play a **flip card reveal animation** and trigger a **slide-in toast** with flavor text and the bonus XP amount. A "next badge" nudge card below the carousel shows the closest-to-unlocking locked badge with its progress bar.

### Profile Flair

The avatar border upgrades as badge count grows: plain green (0–4) → vine border with leaf accents (5–9) → gold glow ring (10+). The display name is user-editable (tap to rename, persisted locally). The header subtitle is dynamic, reflecting current streak, legendary count, or total catches.

### Streaks

Current and best streaks are derived from the set of distinct catch-days, with a 7-dot week view and a 10-week activity heatmap.

### Architecture

```
ProfileScreen
  ├── _ProfileStats.fromCatches()   ←  derived from Floor CaughtPlantDao stream
  ├── _processBadgeRewards()        ←  bonus XP + multiplier + toast on new unlocks
  ├── Trainer card
  │     ├── _FlairAvatar (plain / vine / gold tier border)
  │     ├── Editable display name (tap → AlertDialog → SharedPreferences)
  │     ├── Dynamic subtitle (streak / legendary count / catch summary)
  │     ├── Level title pill + optional 🔥 Week Warrior pill
  │     └── XP progress bar + optional 1.5× multiplier chip
  ├── Collection stat pills + rarity breakdown chips
  ├── Badges carousel  ←  List<BadgeDefinition> evaluated against _ProfileStats
  │     └── _BadgeCard (flip reveal animation on first unlock)
  ├── _NextBadgeNudge  ←  closest locked milestone badge + progress bar
  ├── Streak card  ←  current/best streak + _WeekDots
  ├── Activity heatmap  ←  last 10 weeks, color-intensity scaled to catch density
  └── _BadgeUnlockToast  ←  slide-in overlay with flavor text + bonus XP chip
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

### ✅ Phase 8 — Profile
* [x] Heatmap-style activity calendar (last 10 weeks) with color intensity scaled to daily catch density
* [x] Badge progress indicators for milestone badges (e.g. "67/100" for Centurion, "4/7" for 7-Day Streak)
* [x] "Most-caught family" insight chip on the trainer card
* [x] Tap-to-open badge detail bottom sheet with hint text, tier label, and progress bar
* [x] "New badge" indicator — newly unlocked badges flagged with a NEW pill until tapped
* [x] "Trainer since" date chip on the trainer card, based on earliest catch
* [x] Avatar picker — selectable emoji avatars, some gated behind specific badge unlocks
* [x] **Reward system** — per-badge bonus XP (20–250 XP) awarded once on first unlock, persisted via `shared_preferences`
* [x] **Badge flip reveal animation** — newly unlocked badges play a Y-axis card flip (back face → front face) using dual independent transforms so text is never in the mirrored zone
* [x] **Badge unlock toast** — slide-in overlay at top of screen with badge name, flavor text, and `+N XP` chip; auto-dismisses after 3.5 s
* [x] **XP multiplier** — streak_7 and streak_30 badges grant 1.5× XP for 7 days; shown as a `🔥 1.5× XP` chip next to the XP pill; expiry persisted to prefs
* [x] **"Next badge" nudge card** — shows the single closest-to-unlocking locked milestone badge with live progress bar and remaining count, tappable to open its detail sheet
* [x] **Profile flair tiers** — avatar border upgrades based on total unlocked badge count: plain (0–4) → vine with 🍃 leaf accents (5–9) → gold glow ring (10+)
* [x] **Editable display name** — tap-to-rename dialog (24-char limit), persisted to `shared_preferences`; shows inline ✏️ hint icon
* [x] **Dynamic header subtitle** — reacts to current streak, legendary count, and total catches instead of a static string
* [x] **Week Warrior title pill** — `🔥 Week Warrior` pill appears alongside the level title when streak_7 or streak_30 is earned
* [x] **Ancient Tree avatar** — `🌳` avatar unlocked by the Centurion badge (100 catches)
* [x] All profile data derived live from the Floor `CaughtPlant` stream — zero separate unlock-tracking tables

### 🚧 Phase 9 — Home Screen
* [x] 5-tab bottom nav restructure: Home · Dex · Scan · Map · Profile
* [x] Scan tab rendered as a raised green circle FAB in the center of the nav bar
* [x] Home screen scaffold with `surface` background + `surface2` cards matching Profile design language
* [x] Plain `SafeArea` header with `spaceMono` title and streak pill — no `SliverAppBar`, consistent with Profile
* [x] `_TodayRow` — three stat pills (catches today / XP today / total plants)
* [x] `_DailyQuestCard` — rotating daily quest with progress bar, reset timer, reward XP, and Go Scan CTA
* [x] `_LastCatchTrophy` — hero photo card with gradient overlay, rarity badge, place name, time elapsed
* [x] `_CollectionSnapshot` — stacked rarity bar + per-rarity counts + top family insight
* [x] `_NextBadgeNudge` — closest locked badge with live progress bar
* [x] `_RecentSpots` — recent place name rows with Map deeplink chevrons
* [ ] Wire all cards to live `CaughtPlant` Floor stream
* [ ] Daily quest engine — day-seeded rotation, progress tracking, midnight reset, `shared_preferences` persistence
* [ ] Last catch trophy wired to real photo + place name
* [ ] Recent spots wired to real GPS/geocoding data
* [ ] Go Scan CTA navigates to Scan tab

### 🔮 Later
- **Seasonal badges** — time-gated achievements (e.g. 🎃 Harvest Moon: catch 5 plants in October) for urgency and FOMO
- **Shareable trainer card** — render level/title/top badges as an exportable image
- Settings screen (theme, data export, clear collection)
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
