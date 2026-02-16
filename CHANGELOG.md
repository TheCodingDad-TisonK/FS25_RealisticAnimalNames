# Changelog - Realistic Animal Names

All notable changes to this mod will be documented in this file.

## [2.2.0.0] - 2025-02-27

### ✨ Added
- **Enhanced Multiplayer Synchronization**
  - Full network event system with timeout handling
  - Sync completion confirmation for clients
  - Improved conflict resolution
  - Better error recovery on network issues

- **UTF-8 Character Support**
  - Full international character support in animal names
  - Proper UTF-8 length validation
  - Safe multibyte character truncation
  - Emoji support 🐄🐷🐔

- **UI Improvements**
  - Character counter with color feedback
  - Better keyboard navigation
  - Improved focus management
  - Disabled button states for better UX

- **API Enhancements**
  - New `getNameByNodeId()` for mod integration
  - Better documentation for developers
  - Event hooks for name changes

- **Localization Expansion**
  - Added Hungarian (hu) support
  - Added Dutch (nl) support
  - Added Romanian (ro) support
  - Total: 13 supported languages

### 🔧 Improved
- **Network Architecture**
  - Dedicated network event types
  - Better error handling in multiplayer
  - Sync timeout protection
  - Reduced network traffic

- **Performance**
  - Optimized cluster iteration
  - Better caching of animal positions
  - Frame-sliced rendering improvements
  - Reduced memory allocations

- **Save/Load System**
  - XML schema updated for better compatibility
  - Version tracking in save files
  - Fallback for old save formats
  - More robust error handling

### 🐛 Fixed
- Rare race condition in multiplayer name sync
- Memory leak when animals were sold
- UTF-8 truncation cutting characters incorrectly
- Input action not always unregistering on exit
- Settings not applying immediately in some cases
- Dialog focus issues on some systems

### 📚 Documentation
- Updated README with new features
- Added troubleshooting for multiplayer
- Better code comments throughout
- API documentation for mod developers

---

## [2.1.0.0] - 2025-02-10

### ✨ Added
- Full multiplayer synchronization
- Server-authoritative save system
- Client sync on join
- Conflict resolution
- Network event system

### 🔧 Improved
- Distance-based culling
- Frame-sliced rendering (50 animals/frame)
- Position and distance caching
- Debounced save operations
- Memory leak fixes

### 🐛 Fixed
- Multiplayer desync issues
- Animal cleanup on removal
- Input action registration

---

## [2.0.0.0] - 2025-02-10

### 🎉 Major Rewrite
Complete overhaul of the mod for FS25 with professional structure and modern features.

### ✨ Added
- Integrated Settings System
- Enhanced UI Dialog
- Distance-Based Features
- Improved Input Handling
- Advanced Name Management
- Better Notifications

### 🔧 Changed
- Complete rewrite using FS25 best practices
- Proper OOP implementation
- Separated dialog into dedicated class
- Better code organization

### 🐛 Fixed
- Input action unregistering
- Memory leaks
- Save/load race conditions
- Multiplayer synchronization

---

## Version History Summary

| Version | Date | FS Version | Major Features |
|---------|------|------------|----------------|
| 2.2.0.0 | 2025-02-27 | FS25 | Enhanced MP, UTF-8, UI improvements |
| 2.1.0.0 | 2025-02-10 | FS25 | Multiplayer sync, performance |
| 2.0.0.0 | 2025-02-10 | FS25 | Complete rewrite, settings integration |
| 1.1.0.0 | 2024-11-XX | FS25 | Initial FS25 port |
| 1.0.0.0 | 2023-XX-XX | FS22 | Original release |