# Suggested Macros — source research (2026-08-31)

Pulled from Icy Veins' current retail (Patch 12.1) macro guide pages, per class. Wowhead's macro pages are JS-rendered and didn't return usable literal macro text via fetch; Archon has no dedicated macro pages for most classes. Icy Veins covered every class.

This file is the raw research record. The curated subset actually wired into Core.lua's `SUGGESTED_MACROS` table may trim near-duplicates across specs.

## Warrior
- Colossus Smash + Avatar (Arms): `/cast Avatar` `/cast Colossus Smash`
- Colossus Smash + Racials + Trinkets (Arms): `/use Colossus Smash` `/use Blood Fury` `/use Berserking` `/use 13` `/use 14`
- Charge + Victory Rush + Bladestorm cancel (generic): `/cast Charge` `/cast Victory Rush` `/cancelaura Bladestorm`
- Shield Slam + Ignore Pain (Protection): `/cast Ignore Pain` `/cast Shield Slam`
- Intervene/Charge mouseover-conditional (Protection): `/cast [target=mouseover,help,exists,nodead]Intervene;Intervene` `/cast [target=target,harm,exists,nodead]Charge;Charge`
Source: https://www.icy-veins.com/wow/arms-warrior-pve-dps-macros-addons , https://www.icy-veins.com/wow/protection-warrior-pve-tank-macros-addons

## Paladin
- Divine Shield cancelaura (generic): `/stopcasting` `/cast Divine Shield` `/cancelaura [noknown:Final Stand] Divine Shield` `/cancelaura Blessing of Protection` `/cancelaura [known:Blessing of Spellwarding] Blessing of Spellwarding`
- Word of Glory mouseover (generic): `/stopcasting` `/cast [@mouseover, help, nodead] [] Word of Glory`
- Lay on Hands mouseover (generic): `/stopcasting` `/cast [@mouseover,help,nodead] Lay on Hands`
- Blessing of Sacrifice mouseover (generic): `/stopcasting` `/cast [@mouseover,help,nodead] Blessing of Sacrifice`
- Holy Shock mouseover w/ fallback (Holy): `/use [@mouseover,help,nodead][help,nodead][@player] Holy Shock`
Source: https://www.icy-veins.com/wow/protection-paladin-pve-tank-macros-addons , https://www.icy-veins.com/wow/holy-paladin-pve-healing-macros-addons

## Hunter
- Tank Misdirection via TankMD addon click (generic): `/click TankMDButton1`
- Pet reset (generic): `/petpassive` `/petfollow` `/use Dash`
- Kill Command w/ pet safety (BM/Survival): `/petassist` `/petattack` `/cast [@pet,dead] Revive Pet;` `/cast [@pet,noexists,mod:shift] Revive Pet;` `/cast [@pet,noexists] Call Pet 1;` `/cast Kill Command`
- Aspect of the Turtle cancelaura (generic): `/stopcasting` `/stopcasting` `/use Aspect of the Turtle` `/cancelaura Aspect of the Turtle`
- Bestial Wrath w/ stealth-aura cancel (BM): `/cancelaura Shroud of Concealment` `/cancelaura Camouflage` `/use Bestial Wrath`
Source: https://www.icy-veins.com/wow/marksmanship-hunter-pve-dps-macros-addons , https://www.icy-veins.com/wow/beast-mastery-hunter-pve-dps-macros-addons

## Rogue
- Deathmark + trinket (Assassination): `/cast Deathmark` `/use 13`
- Shadow Dance + Secret Technique (Sub/Trickster): `/cast Shadow Dance` `/cast Secret Technique`
- Shadow Dance + Shuriken Storm (Sub/Deathstalker): `/cast Shadow Dance` `/cast Shuriken Storm`
- Coup de Grace + Black Powder (Subtlety): `/cast Coup de Grace` `/cast Black Powder`
- Shadow Blades + trinkets + potion (Subtlety): `/cast Shadow Blades` `/use 13` `/use 14` `/use Light's Potential`
- Mouseover Shadowstep (Subtlety): `/cast [target=mouseover,exists,noharm] Shadowstep`
Source: https://www.icy-veins.com/wow/assassination-rogue-pve-dps-macros-addons , https://www.icy-veins.com/wow/subtlety-rogue-pve-dps-macros-addons

## Priest
- Power Infusion mouseover->focus->self (Holy): `/cast [@mouseover,help,nodead][@focus,help,nodead][] Power Infusion` `/cast [@player] Power Infusion`
- Leap of Faith mouseover (Holy): `/cast [@mouseover,help,nodead][] Leap of Faith`
- Void Torrent/Halo talent-swap (Shadow): `/cast [known:Void Torrent] Void Torrent; Halo`
- Holy Word: Sanctify at cursor (Holy): `/cast [@cursor] Holy Word: Sanctify` `/stopspelltarget`
- Penance offense/defense split pair (Discipline): `/cast [harm] Penance` and separately `/cast [@mouseover,help] Penance`
Source: https://www.icy-veins.com/wow/holy-priest-pve-healing-macros-addons , https://www.icy-veins.com/wow/shadow-priest-pve-dps-macros-addons , https://www.icy-veins.com/wow/discipline-priest-pve-healing-macros-addons

## Death Knight
- Frost burst opener: `/use trinket` `/cast Pillar of Frost` `/cast Raise Dead` `/cast Breath of Sindragosa`
- Gorefiend's Grasp shift/mouseover/self (Blood): `/cast [mod:shift,@focus,exists][@mouseover,exists,nodead][@player] Gorefiend's Grasp`
- Death and Decay cursor/self toggle (Blood): `/cast [@cursor] Death and Decay; [mod:ctrl, @player] Death and Decay`
- Anti-Magic Zone at cursor (Frost/Unholy): `/cast [@cursor] Anti-Magic Zone`
- Re-control ghoul pet (generic): `/target pet` `/script PetDismiss()` `/cast Control Undead`
- Death Grip mouseover (Frost/Unholy): `/cast [target=mouseover,exists] Death Grip; Death Grip`
Source: https://www.icy-veins.com/wow/frost-death-knight-pve-dps-macros-addons , https://www.icy-veins.com/wow/blood-death-knight-pve-tank-macros-addons

## Shaman
- Wind Rush Totem at cursor (generic): `/stopcasting` `/cast [@cursor] Wind Rush Totem`
- Ancestral Swiftness + Lava Burst (Elemental): `/use Ancestral Swiftness` `/cast Lava Burst`
- Surging Totem on Lava Lash (Enhancement): `/cast Lava Lash` `/cast Surging Totem`
- Healing Rain at cursor (Restoration): `/cast [@cursor] Healing Rain`
- Chain Heal mouseover / Flame Shock fallback (Restoration): `/cast [@mouseover,nodead,help] Chain Heal; Flame Shock`
Source: https://www.icy-veins.com/wow/elemental-shaman-pve-dps-macros-addons , https://www.icy-veins.com/wow/enhancement-shaman-pve-dps-macros-addons , https://www.icy-veins.com/wow/restoration-shaman-pve-healing-macros-addons

## Mage
- One-button Combustion (Fire): `/cast Ancestral Call` `/cast Berserking` `/cast Blood Fury` `/cast Combustion` `/use 13` `/use 14` `/use 16`
- One-button Arcane Surge (Arcane): same pattern with Arcane Surge
- Stopcast Blink (generic): `/stopcasting` `/cast Blink`
- One-button Ice Block (generic): `/stopcasting` `/cancelaura Ice Block` `/cast Ice Block`
- Alter Time cancel (generic): `/cancelaura Alter Time`
Source: https://www.icy-veins.com/wow/fire-mage-pve-dps-macros-addons , https://www.icy-veins.com/wow/arcane-mage-pve-dps-macros-addons , https://www.icy-veins.com/wow/frost-mage-pve-dps-macros-addons

## Warlock
- Banish focus/target (generic): `/use [mod:shift,@focus] [] Banish`
- Demonic Circle place/teleport toggle (generic): `/stopcasting` `/use [mod:shift] Demonic Circle(Summon); [nomod] Demonic Circle: Teleport(Teleport)`
- Corruption mouseover (generic): `/use [@mouseover,harm] [harm] Corruption`
- Shadowfury/Howl of Terror talent-aware (generic): `/use [known:Shadowfury,@cursor] Shadowfury; [known:Howl of Terror] Howl of Terror`
- Havoc mouseover cleave (Destruction): `/cast [@mouseover,harm] Havoc; [harm] Havoc`
Source: https://www.icy-veins.com/wow/affliction-warlock-pve-dps-macros-addons , https://www.icy-veins.com/wow/destruction-warlock-pve-dps-macros-addons

## Monk
- Whirling Dragon Punch/Strike of the Windlord shared button (Windwalker): `/stopmacro [channeling:Fists of Fury]` `/stopmacro [channeling:Celestial Conduit]` `/cast [known:152175] Whirling Dragon Punch` `/cast [known:392983] Strike of the Windlord`
- Celestial Brew/Infusion talent-swap (Brewmaster): `/cast [known:Celestial Brew] Celestial Brew` `/cast [known:Celestial Infusion] Celestial Infusion`
- All-in-one Provoke incl. Black Ox Statue (Brewmaster): `/cast [nomod,@mouseover,harm,nodead] Provoke` `/cast [nomod] Provoke` `/targetexact [mod:alt] Black Ox Statue` `/cast [mod:alt] Provoke` `/targetlasttarget [mod:alt,exists]`
- Detox mouseover (Windwalker/Brewmaster): `/cast [@mouseover,help,nodead] Detox;Detox`
Source: https://www.icy-veins.com/wow/windwalker-monk-pve-dps-macros-addons , https://www.icy-veins.com/wow/brewmaster-monk-pve-tank-macros-addons

## Druid
- Rebirth mouseover (generic): `/cast [@mouseover,help]Rebirth;Rebirth`
- No-toggle shapeshift (Bear/Cat/Travel) (generic): `/cast [noform:1] Bear Form` (etc per form)
- Bear Form + Heart of the Wild (Balance): `/cast [nostance:1] Bear Form` `/cast Heart of the Wild`
- Ursol's Vortex -> Typhoon castsequence (Feral): `/castsequence [@cursor] reset=20 Ursol's Vortex, Typhoon`
- Cancel Blessing of Protection + Thrash (Guardian): `/cancelaura Blessing of Protection` `/cast Thrash`
Source: https://www.icy-veins.com/wow/restoration-druid-pve-healing-macros-addons , https://www.icy-veins.com/wow/balance-druid-pve-dps-macros-addons , https://www.icy-veins.com/wow/feral-druid-pve-dps-macros-addons , https://www.icy-veins.com/wow/guardian-druid-pve-tank-macros-addons

## Demon Hunter
- Consume Magic focus dispel (generic): `/cast [@focus,harm,nodead][] Consume Magic`
- Metamorphosis at cursor (Havoc): `/stopcasting` `/cast [@cursor] Metamorphosis`
- Demon Spikes on Fracture (Vengeance): `/cast Demon Spikes` `/cast Fracture`
- Immolation Aura + Infernal Strike (Vengeance): `/cast Immolation Aura` `/cast [@player] Infernal Strike`
- Mouseover Torment/taunt (Vengeance): `/cast [@mouseover,harm,nodead][]Torment`
Source: https://www.icy-veins.com/wow/vengeance-demon-hunter-pve-tank-macros-addons , https://www.icy-veins.com/wow/havoc-demon-hunter-pve-dps-macros-addons

## Evoker
- Cauterizing Flame mouseover (generic): `/cast [@mouseover, help, nodead] [] Cauterizing Flame`
- Rescue mouseover (generic): `/cast [@mouseover, help, nodead] [] Rescue`
- Fire Breath + trinket (Devastation): `/use [mod:shift] 13` `/cast Fire Breath`
- Black Attunement + Eruption (Augmentation): `/cast [nostance:1] Black Attunement` `/cast Eruption`
- Cancel Tip the Scales (Augmentation): `/cast Tip the Scales` `/cancelaura Tip the Scales`
- Emerald Blossom mouseover (Preservation): `/cast [@mouseover, help, nodead] [] Emerald Blossom`
Source: https://www.icy-veins.com/wow/devastation-evoker-pve-dps-macros-addons , https://www.icy-veins.com/wow/augmentation-evoker-pve-dps-macros-addons , https://www.icy-veins.com/wow/preservation-evoker-pve-healing-macros-addons
