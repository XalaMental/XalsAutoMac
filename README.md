<a href="https://discord.gg/9SwrQDJeCe"><img src="https://img.shields.io/badge/JOIN%20THE%20DISCORD-5865F2?style=for-the-badge&logo=discord&logoColor=white&logoSize=auto" height="80" alt="Join the Discord"></a>

Questions, bug reports, and feature ideas — this is the fastest way to reach me.

---

Generates personalized interrupt, leveling-aware healing potion, and DPS potion macros at the click of a button.

---

## 🤔 What is Xal's AutoMac?

AutoMac builds your utility macros for you, so you don't have to hand-write them or hunt down spell/item IDs. Open the panel with `/xam`, pick your interrupt targeting style, and click a button — AutoMac reads your class and level, then generates a ready-to-drag interrupt macro, a healing potion macro that always fires your strongest usable potion, and a DPS potion macro, all built from spell/item IDs so they work correctly no matter what language your client is set to.

---

## ⚡ Key features

- **Class-aware interrupt macro** — auto-detects your class's real interrupt spell and builds it into a macro with your choice of targeting style: Focus + Mouseover (no tabbing), Focus-swap, or Target only. Saved per character.
- **Leveling-aware healing potion macro** — ranks every healing potion you're currently high enough level to use, best to worst, so one keypress always fires your strongest available potion. Appends the universal Recuperate ability for out-of-combat healing.
- **Level-up notifications** — get pinged in chat the moment you level past your current potion tier, so you know it's time to regenerate the macro for the next one.
- **DPS potion macro** — queues Fleeting Light's Potential first, falling back to Light's Potential if you don't have a fleeting one up.
- **Locale-independent** — every macro is built from spell/item IDs, never names, so nothing breaks if your game client isn't in English.
- **Create All** — regenerate every macro at once with a single click.

---

## ⌨️ Slash commands

| Command | What it does |
|---|---|
| `/xam` | Opens/closes the AutoMac panel |
| `/xals` | Same as `/xam` |

---

## 🚧 In the works

Nothing on the roadmap yet — suggestions welcome on [Discord](https://discord.gg/9SwrQDJeCe).

---

## 🖼️ Screenshots

<!-- Drop your screenshots into the Gallery, or embed them here in the editor -->

---

## 🔗 More Xal's addons

- **[Xal's Quest Compass](https://www.curseforge.com/wow/addons/xals-quest-compass)** — Auto-detects quests ready to turn in, sorts them by distance, and one-click navigates you to each.
- **[Xal's Xpedited Routes](https://www.curseforge.com/wow/addons/xals-xpedited-routes)** — Gathering node tracker and route optimizer with an on-screen compass.
- **[Xal's Craft Courier](https://www.curseforge.com/wow/addons/xals-craft-courier)** — Streamlines sending and receiving crafting orders through the mail.
- **[Xal's Roster Roundup](https://www.curseforge.com/wow/addons/xals-roster-roundup)** — Guild roster tools and tracking.
- **[Xal's Compendium](https://www.curseforge.com/wow/addons/xals-compendium)** — A daily/weekly tracker for staying on top of your to-dos.

---

## 💬 Support & credits

Questions or ideas? Join the [Discord](https://discord.gg/9SwrQDJeCe).

All Rights Reserved — see LICENSE.md.

**Known issue (not an addon bug):** a Midnight pre-patch stat-squish bug is currently causing the classic tiered healing potions (Minor through Major) to under-heal. The macro's item IDs are correct — this is a live Blizzard-side issue expected to be patched.
