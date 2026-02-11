# FS25 Realistic Animal Names - TODO

This is a **developer-focused, actionable task list** for improving FS25_RealisticAnimalNames.  
Each item includes guidance for AI or human contributors to understand the task, purpose, and priority.

---

## 1. Core Feature Enhancements
- [ ] **Persist Animal Names**
  - Ensure all animal names **save and load correctly** across sessions.
  - Validate **multiplayer sync**: names should be identical for all connected players.
  - Test edge cases: new animals added mid-session, renamed animals, and herd management.

- [ ] **Improve Name Management UI**
  - Add **batch renaming** by herd or animal type.
  - Implement **sorting** by name, type, or age.
  - Add **search/filter functionality** to quickly locate specific animals.
  - Ensure UI is intuitive, consistent, and accessible.

- [ ] **Dynamic Name Display Options**
  - Allow players to adjust **text size, color, and style**.
  - Enable **distance-based visibility**: hide names beyond a configurable distance.
  - Implement **camera angle logic**: optionally hide names when animals are behind obstacles.

---

## 2. Multiplayer & Networking
- [ ] **Optimize Network Synchronization**
  - Ensure minimal latency when updating names across clients.
  - Avoid unnecessary network traffic when no name changes occur.

- [ ] **Conflict Resolution**
  - Handle cases where multiple players attempt to rename the same animal simultaneously.
  - Decide rules for priority (e.g., first player or owner overrides).

- [ ] **Per-Player Visibility**
  - Allow each player to toggle visibility of name tags individually.
  - Ensure that changes are **persistent and multiplayer-safe**.

---

## 3. Mod Compatibility & Integration
- [ ] **Test With Popular Realism Mods**
  - Verify FS25_RealisticAnimalNames does not conflict with mods like Realistic Livestock.
  - Ensure **name tags and UI remain functional** alongside other animal mods.

- [ ] **Expose Mod API**
  - Provide methods for other mods to **read/write animal names** programmatically.
  - Document API functions for developers.

---

## 4. Documentation & UX
- [ ] **Update README.md**
  - Add screenshots, GIFs, and instructions for installation and usage.
  - Provide multiplayer guidance and troubleshooting tips.

- [ ] **Changelog**
  - Maintain clear version history and update notes for every release.

- [ ] **Tooltips / Tutorials**
  - Add in-game guidance for first-time users.
  - Explain keybinds, UI options, and multiplayer behavior.

---

## 5. Community & Support
- [ ] **GitHub Issue Templates**
  - Add templates for bug reports, feature requests, and general feedback.

- [ ] **Name Packs / Contributions**
  - Encourage community-created name packs (farm-specific, themed, or localized).

- [ ] **Showcase / Leaderboard**
  - Consider adding a gallery of interesting or creative animal names for players to explore.

