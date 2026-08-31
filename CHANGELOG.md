# Xal's AutoMac - Changelog

## 1.0.1 - August 31, 2026

---

Right on the heels of 1.0.0, I caught that the release workflow was missing a manual-run safety net the rest of my addons already carry - if a tag lands in the exact same push that first adds the release workflow file, GitHub can miss it and the release just quietly never fires. Nothing changes for you in-game with this one; it's me closing that gap so this addon's releases are as solid as everything else in the family.

### 🔧 Fixed
- Added a manual run option to the release workflow so a release can be started by hand if a tag ever arrives before GitHub's registered the workflow, instead of silently never firing.

## 1.0.0 - August 31, 2026

---

I got tired of hand-writing the same handful of macros on every character - interrupt, healing potion, DPS potion, cleanse - and rebuilding them from scratch every time I switched specs or leveled up into a better potion. So this addon just does it for you: click a button, it writes the right macro for your class and spec, and hands it straight to Blizzard's own macro editor so you save/cancel/delete it exactly like you always have. Thanks for being part of the Xal family.

### 🆕 New
- **Interrupt** - generates a working interrupt macro for every class/spec that has one; greyed out with an explanation if your current spec doesn't.
- **Healing Potion** - automatically picks your best available healing potion for your level, plus your Healthstone and Recuperate.
- **DPS Potion** - automatically picks your best available combat potion for your level.
- **Cleanse / Mass Dispel** - generated for every class/spec that actually has one.
- **Custom Macro** - type or pick any spell you know and build your own mouseover, target, or cast-by-name macro.
- Opens Blizzard's real macro editor right alongside the addon's own panel, styled to match, so it feels like one window instead of a copy of Blizzard's UI.

### ⚙️ Under the hood
- First release - full release automation (CurseForge packaging, Discord announcements) set up alongside the addon itself.
