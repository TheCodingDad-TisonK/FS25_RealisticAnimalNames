# Changelog - Realistic Animal Names

All notable changes to this mod will be documented in this file.

## [2.0.0.0] - 2025-02-10

### 🎉 Major Rewrite
Complete overhaul of the mod for FS25 with professional structure and modern features.

### ✨ Added
- **Integrated Settings System**
  - All settings now accessible through game's settings menu
  - Four configurable parameters: visibility, distance, height, font size
  - Settings persist between game sessions
  
- **Enhanced UI Dialog**
  - Proper FS25 GUI implementation
  - Clean, professional dialog design
  - Follows FS25 UI standards and profiles
  - Better keyboard navigation
  
- **Distance-Based Features**
  - Names automatically scale based on distance
  - Configurable display distance (5-50m)
  - Performance optimization through distance culling
  
- **Improved Input Handling**
  - Proper FS25 input action registration
  - Customizable keybind through game settings
  - Better input event management
  
- **Advanced Name Management**
  - Store original names for reset functionality
  - Immediate save on name change
  - Per-savegame data isolation
  
- **Better Notifications**
  - Localized notification messages
  - Clear feedback on all actions
  - Informative error messages

### 🔧 Changed
- **Code Structure**
  - Complete rewrite using FS25 best practices
  - Proper OOP implementation with Class system
  - Separated dialog into dedicated class
  - Better code organization and commenting
  
- **File Organization**
  - Created proper directory structure (src/, gui/)
  - Separated concerns (main script, GUI, config)
  - Cleaner mod root directory
  
- **Settings Management**
  - Moved from XML-only to integrated game settings
  - Better default values
  - More intuitive setting names
  
- **Performance**
  - Optimized rendering loop
  - Better camera position caching
  - Reduced unnecessary calculations
  - Distance-based culling

### 🐛 Fixed
- Input action not properly unregistering on exit
- Memory leaks from unreleased resources
- GUI elements not properly initialized
- Animal search inefficiency
- Save/load race conditions
- Multiplayer synchronization issues

### 🌍 Localization
- Enhanced translations for all UI elements
- Added setting descriptions in 10 languages
- Better context-aware text
- Improved notification messages

### 📚 Documentation
- Comprehensive README with all features
- Detailed installation guide
- Troubleshooting section
- Developer documentation
- Code comments throughout

### 🔐 Security
- Proper validation of user input
- Safe file path handling
- Protected against invalid animal references
- Bounds checking on settings

---

## [1.1.0.0] - 2024-11-XX

### Initial FS25 Port
First version ported to Farming Simulator 25.

### Added
- Basic animal naming functionality
- Simple GUI dialog
- Keybind support (K key)
- Floating name tags
- XML save/load
- Multiplayer compatibility

### Known Issues
- Settings not integrated with game settings
- UI doesn't follow FS25 standards
- No distance-based scaling
- Limited configuration options
- Memory management issues

---

## [1.0.0.0] - 2023-XX-XX

### Initial Release (FS22)
Original version for Farming Simulator 22.

### Features
- Custom animal names
- Basic floating tags
- Simple save system
- Single language (English)

---

## Version History Summary

| Version | Date | FS Version | Major Features |
|---------|------|------------|----------------|
| 2.0.0.0 | 2025-02-10 | FS25 | Complete rewrite, settings integration, enhanced UI |
| 1.1.0.0 | 2024-11-XX | FS25 | Initial FS25 port |
| 1.0.0.0 | 2023-XX-XX | FS22 | Original release |

---

## Upgrade Guide

### From 1.1.0.0 to 2.0.0.0

**Breaking Changes:**
- File structure changed - backup your old version
- Savegame format updated (old saves will not load names)

**Migration Steps:**
1. Note down any important animal names
2. Remove old version from mods folder
3. Install new version
4. Load your savegame
5. Re-enter animal names (old ones won't transfer)

**New Features to Try:**
- Adjust settings in Settings menu
- Change keybind to your preference
- Experiment with different display distances
- Try the new distance scaling

---

## Future Plans

### Planned for 2.1.0.0
- [ ] Bulk naming tool for multiple animals
- [ ] Name templates/presets
- [ ] Import/export name lists
- [ ] Random name generator
- [ ] Animal type-specific naming

### Under Consideration
- [ ] Color customization for name tags
- [ ] Different fonts/styles
- [ ] Name badges/icons
- [ ] Statistics tracking
- [ ] Integration with animal info screens
- [ ] Voice command support (if API available)

### Community Requests
Submit feature requests through:
- ModHub comments
- FS25 forums
- Direct feedback to author

---

## Deprecation Notices

### Version 1.x
All 1.x versions are now deprecated and unsupported. Please upgrade to 2.0.0.0 or later for:
- Bug fixes
- Performance improvements
- New features
- FS25 compatibility

---

## Credits

**Contributors:**
- Main Developer: TisonK

---

**Note:** This mod follows semantic versioning (MAJOR.MINOR.PATCH.BUILD)
- MAJOR: Incompatible API changes
- MINOR: New functionality (backwards compatible)
- PATCH: Bug fixes (backwards compatible)
- BUILD: FS25 internal version tracking