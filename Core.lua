-- Xal's AutoMac
-- Generates personalized interrupt, leveling-aware healing potion, and
-- DPS potion macros per-character.

local ADDON_NAME, addonTable = ...
local Brand = addonTable.BrandStyle

--------------------------------------------------------------------------
-- Saved Variables
--------------------------------------------------------------------------
XalsAutoMacDB = XalsAutoMacDB or {}

local function GetCharKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    return name .. "-" .. realm
end

local function GetCharDB()
    local key = GetCharKey()
    XalsAutoMacDB[key] = XalsAutoMacDB[key] or {
        nextPotionMinLevel = nil,
    }
    return XalsAutoMacDB[key]
end

--------------------------------------------------------------------------
-- Class interrupt data -- spec-aware. Each class maps to a LIST of
-- entries; an entry with no `specs` field applies to every spec of that
-- class, an entry WITH `specs` (a set of spec IDs) only applies to those
-- specs. Some classes have more than one entry because a spec that lacks
-- the class's usual interrupt has its own alternate instead (e.g. Balance
-- Druid doesn't get Skull Bash, but has Solar Beam). Spell IDs are used
-- directly (locale-independent). All verified live on Wowhead, patch 12.1.
--------------------------------------------------------------------------
-- Spec IDs referenced below (standard, stable retail spec index values):
-- Paladin: Holy 65, Protection 66, Retribution 70
-- Druid: Balance 102, Feral 103, Guardian 104, Restoration 105
-- Monk: Brewmaster 268, Windwalker 269, Mistweaver 270
-- Priest: Discipline 256, Holy 257, Shadow 258
-- Evoker: Devastation 1467, Preservation 1468, Augmentation 1473
local CLASS_INTERRUPTS = {
    DEATHKNIGHT = { { id = 47528, name = "Mind Freeze" } },
    DEMONHUNTER = { { id = 183752, name = "Disrupt" } },
    DRUID = {
        { specs = { [103] = true, [104] = true }, id = 106839, name = "Skull Bash", note = "Bear/Cat form only" },
        { specs = { [102] = true }, id = 78675, name = "Solar Beam", note = "AoE silence over the target's location, not a single-target kick" },
    },
    EVOKER = {
        { specs = { [1473] = true }, id = 351338, name = "Quell", note = "Augmentation only" },
    },
    HUNTER = { { id = 147362, name = "Counter Shot" } },
    MAGE = { { id = 2139, name = "Counterspell" } },
    MONK = {
        { specs = { [268] = true, [269] = true }, id = 116705, name = "Spear Hand Strike", note = "Brewmaster/Windwalker only" },
    },
    PALADIN = {
        { specs = { [66] = true, [70] = true }, id = 96231, name = "Rebuke", note = "Protection/Retribution only" },
    },
    PRIEST = {
        { specs = { [258] = true }, id = 15487, name = "Silence", note = "Shadow talent" },
    },
    ROGUE = { { id = 1766, name = "Kick" } },
    SHAMAN = { { id = 57994, name = "Wind Shear" } },
    WARLOCK = { { id = 19647, name = "Spell Lock", note = "Requires Felhunter pet out" } },
    WARRIOR = { { id = 6552, name = "Pummel" } },
}

-- Returns the interrupt entry for the player's ACTUAL current spec, or nil
-- if this spec has no interrupt at all (e.g. Holy Paladin, Restoration
-- Druid, Mistweaver Monk, Devastation/Preservation Evoker).
local function GetInterruptForCurrentSpec(classToken)
    local entries = CLASS_INTERRUPTS[classToken]
    if not entries then return nil end

    local specIndex = GetSpecialization()
    local specID = specIndex and select(1, GetSpecializationInfo(specIndex))

    for _, entry in ipairs(entries) do
        if not entry.specs or (specID and entry.specs[specID]) then
            return entry
        end
    end
    return nil
end

local RECUPERATE_SPELL_ID = 1231411 -- Universal General-tab "Recuperate" (verified live on Wowhead, patch 12.0.7)

--------------------------------------------------------------------------
-- Class cleanse/dispel data
-- Same locale-independent spell-ID approach as CLASS_INTERRUPTS. Classes
-- with no real friendly dispel (Death Knight, Demon Hunter, Hunter, Mage,
-- Rogue, Warlock, Warrior) are intentionally left out.
--------------------------------------------------------------------------
local CLASS_CLEANSE = {
    PRIEST  = { id = 527,    name = "Purify" }, -- removes Magic + Disease (verified live on Wowhead, patch 12.1)
    PALADIN = { id = 4987,   name = "Cleanse", note = "Holy spec -- Protection/Retribution may need Cleanse Toxins (213644) instead" }, -- removes Poison + Disease + Magic (verified live on Wowhead, patch 12.1)
    SHAMAN  = { id = 77130,  name = "Purify Spirit" }, -- removes Magic + Curse (verified live on Wowhead, patch 12.1)
    DRUID   = { id = 88423,  name = "Nature's Cure" }, -- removes Magic + Curse + Poison (verified live on Wowhead, patch 12.1)
    MONK    = { id = 218164, name = "Detox" }, -- removes Poison + Disease (verified live on Wowhead, patch 12.1)
    EVOKER  = { id = 374251, name = "Cauterizing Flame", note = "Preservation spec" }, -- removes Bleed + Poison + Curse + Disease, heals on removal (verified live on Wowhead, patch 12.1)
}

local HEALTHSTONE_ITEM_ID = 5512 -- fixed ID regardless of rank/level, independent cooldown from potions since patch 8.0.1

local CLASS_MASS_DISPEL = {
    PRIEST = { id = 32375, name = "Mass Dispel" }, -- verified live on Wowhead, patch 12.1
}

--------------------------------------------------------------------------
-- Macro body builder -- interrupt
-- One fixed pattern, no style choice: interrupt whatever's on focus if you
-- have one, otherwise set focus to your current target, swap to the
-- nearest enemy, interrupt that, then swap back to your focus target.
--------------------------------------------------------------------------
-- /cast takes the spell's NAME, never a raw numeric spell ID -- WoW treats
-- a bare number after /cast as a literal (nonexistent) spell name and the
-- line just silently no-ops. Every builder below resolves the ID to its
-- real name first. (Item IDs are different -- /use DOES accept "item:12345"
-- directly, so the potion/healthstone lines are untouched.)
local function SpellName(spellID)
    local info = C_Spell.GetSpellInfo(spellID)
    return info and info.name or tostring(spellID)
end

local function BuildInterruptMacro(spellID)
    local name = SpellName(spellID)
    return table.concat({
        "#showtooltip",
        "/cast [@focus,exists,nodead,harm] " .. name,
        "/stopmacro [@focus,exists,nodead,harm]",
        "/focus target",
        "/cleartarget",
        "/targetenemy",
        "/cast " .. name,
        "/target focus",
        "/clearfocus",
        "/startattack",
    }, "\n")
end

--------------------------------------------------------------------------
-- Macro body builder -- friendly-target (cleanse/dispel)
-- Mouse over an ally to hit them; with no mouseover, falls to your current
-- target (whether or not it's friendly -- an invalid target just no-ops
-- that press rather than defaulting to self). No targeting-style choice
-- here, unlike the interrupt macro -- this is the one pattern basically
-- everyone actually wants for a friendly dispel/cleanse.
--------------------------------------------------------------------------
local function BuildFriendlyTargetMacro(spellID)
    return table.concat({
        "#showtooltip",
        "/cast [@mouseover,help,nodead][@target,nodead] " .. SpellName(spellID),
    }, "\n")
end

--------------------------------------------------------------------------
-- Custom macros -- any spell you actually know, by name, instead of a
-- curated ID list. Harmful/helpful is auto-detected per spell (C_Spell.
-- IsSpellHarmful) so the mouseover macro targets correctly either way.
--------------------------------------------------------------------------
local function BuildCustomMouseoverMacro(spellID)
    local harmful = C_Spell.IsSpellHarmful(spellID)
    local name = SpellName(spellID)
    if harmful then
        return table.concat({
            "#showtooltip",
            "/cast [@mouseover,harm,nodead][harm,nodead] " .. name,
        }, "\n")
    else
        return table.concat({
            "#showtooltip",
            "/cast [@mouseover,help,nodead][@target,nodead] " .. name,
        }, "\n")
    end
end

local function BuildCustomTargetMacro(spellID)
    return table.concat({
        "#showtooltip",
        "/cast " .. SpellName(spellID),
    }, "\n")
end

local function BuildTargetByNameMacro(npcName)
    return table.concat({
        "#showtooltip",
        "/targetexact " .. npcName,
    }, "\n")
end

-- Scans the player's own spellbook (General bank only -- not pet spells)
-- for known spell names, live via the current C_SpellBook namespace.
-- Returns an array of { name = ..., id = ... }.
local function GetKnownSpells()
    local spells = {}
    local seen = {}
    for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(i)
        if skillLineInfo then
            local offset, numSlots = skillLineInfo.itemIndexOffset, skillLineInfo.numSpellBookItems
            for slot = offset + 1, offset + numSlots do
                local name = C_SpellBook.GetSpellBookItemName(slot, Enum.SpellBookSpellBank.Player)
                local itemType, actionID = C_SpellBook.GetSpellBookItemType(slot, Enum.SpellBookSpellBank.Player)
                if name and itemType == Enum.SpellBookItemType.Spell and not seen[name] then
                    seen[name] = true
                    table.insert(spells, { name = name, id = actionID })
                end
            end
        end
    end
    return spells
end

-- Attaches a live-filtering suggestion dropdown to an EditBox. Ported from
-- Xal's Roster Roundup's GuildPanel.lua AttachAutocomplete (same component,
-- generalized) -- the caller supplies getCandidates(text) -> array of
-- strings, and onSelect(text) fires when a row is clicked. onTextChanged(text),
-- if given, fires on every keystroke (used to drive a live character counter).
local ROW_H = 20
local function AttachAutocomplete(editBox, panelFrame, getCandidates, onSelect, onTextChanged)
    local listFrame = CreateFrame("Frame", nil, editBox, "BackdropTemplate")
    listFrame:SetPoint("LEFT", editBox, "LEFT", 0, 0)
    listFrame:SetPoint("RIGHT", editBox, "RIGHT", 0, 0)
    listFrame:SetFrameStrata("TOOLTIP")
    Brand.ApplyBackground(listFrame)
    Brand.DrawBorder(listFrame, 0)
    listFrame:Hide()

    local rowBtns = {}
    local function UpdateList()
        local text = editBox:GetText()
        if text == "" then
            listFrame:Hide()
            return
        end
        local candidates = getCandidates(text)
        if #candidates == 0 then
            listFrame:Hide()
            return
        end
        for i, name in ipairs(candidates) do
            local row = rowBtns[i]
            if not row then
                row = CreateFrame("Button", nil, listFrame)
                row:SetHeight(ROW_H)
                row:SetPoint("LEFT", listFrame, "LEFT", 4, 0)
                row:SetPoint("RIGHT", listFrame, "RIGHT", -4, 0)
                local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                label:SetPoint("LEFT", row, "LEFT", 6, 0)
                label:SetJustifyH("LEFT")
                row.label = label
                row:SetScript("OnMouseDown", function(self)
                    editBox:SetText(self.label:GetText())
                    editBox:ClearFocus()
                    listFrame:Hide()
                    onSelect(self.label:GetText())
                end)
                rowBtns[i] = row
            end
            if i == 1 then
                row:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, 0)
            else
                row:SetPoint("TOPLEFT", rowBtns[i - 1], "BOTTOMLEFT", 0, 0)
            end
            row.label:SetText(name)
            row:Show()
        end
        for i = #candidates + 1, #rowBtns do
            rowBtns[i]:Hide()
        end

        -- Opens downward if there's room within the panel's own border,
        -- otherwise flips upward -- this frame draws on TOOLTIP strata (so
        -- it can render over the panel's content), which also means it was
        -- rendering straight through/past the bottom border with no buffer
        -- when a field sits near the bottom of the panel and had no room
        -- below it. Flipping direction keeps it inside the frame instead.
        local neededHeight = ROW_H * #candidates
        listFrame:ClearAllPoints()
        listFrame:SetPoint("LEFT", editBox, "LEFT", 0, 0)
        listFrame:SetPoint("RIGHT", editBox, "RIGHT", 0, 0)
        local spaceBelow = editBox:GetBottom() - panelFrame:GetBottom() - Brand.SAFE_MARGIN
        if spaceBelow >= neededHeight then
            listFrame:SetPoint("TOP", editBox, "BOTTOM", 0, -2)
        else
            listFrame:SetPoint("BOTTOM", editBox, "TOP", 0, 2)
        end
        listFrame:SetHeight(neededHeight)
        listFrame:Show()
    end

    editBox:SetScript("OnTextChanged", function(self)
        UpdateList()
        if onTextChanged then onTextChanged(self:GetText()) end
    end)
    editBox:SetScript("OnEditFocusLost", function()
        C_Timer.After(0, function()
            if not listFrame:IsMouseOver() then
                listFrame:Hide()
            end
        end)
    end)
end

--------------------------------------------------------------------------
-- Known-item databases
-- Both lists are curated (verified live, non-beta/PTR item IDs) rather
-- than auto-detected from bags. This matters because the game's item
-- API can't tell a healing potion apart from a stat/DPS potion by
-- itself -- both share the same Consumable > Potion subclass -- so
-- blindly scanning bags for "any potion" risks mixing them into the
-- wrong macro. Level requirement and item level are still pulled live
-- from the game client at runtime, so only the IDs below need to be
-- correct; the numbers stay accurate as Blizzard changes them.
--------------------------------------------------------------------------

-- Healing potions.
-- NOTE: the classic tiered healing potions below are currently affected
-- by a Midnight pre-patch stat-squish bug and heal for far less than
-- intended. IDs are correct; actual healing may be weak until Blizzard
-- fixes it. Remove any entry below if you'd rather the macro skip it.
local KNOWN_HEALING_POTIONS = {
    { id = 118 },    -- Minor Healing Potion
    { id = 858 },    -- Lesser Healing Potion
    { id = 929 },    -- Healing Potion
    { id = 1710 },   -- Greater Healing Potion
    { id = 3928 },   -- Superior Healing Potion
    { id = 13446 },  -- Major Healing Potion
    { id = 241305 }, -- Silvermoon Health Potion (Midnight Alchemy, requires level 81, live ID)
}

-- DPS (primary stat) potions, listed in the priority order the macro
-- tries them: the Fleeting (cauldron-conjured, free) version first,
-- then your own personal potion as a fallback if you don't have a
-- fleeting one up. Matches the community-standard "use best available"
-- pattern shared on Wago for these two items.
local KNOWN_DPS_POTIONS = {
    { id = 245898 }, -- Fleeting Light's Potential
    { id = 241309 }, -- Light's Potential
}

-- Loads live item data (name/ilvl/quality/minLevel) for a curated ID
-- list. Returns a table keyed by itemID once every item has loaded.
local function LoadKnownItems(idList, callback)
    local byId = {}
    local pending = #idList
    if pending == 0 then
        callback(byId)
        return
    end
    for _, entry in ipairs(idList) do
        local item = Item:CreateFromItemID(entry.id)
        item:ContinueOnItemLoad(function()
            local name, _, quality, ilvl, minLevel = GetItemInfo(entry.id)
            byId[entry.id] = {
                id = entry.id,
                ilvl = ilvl or 0,
                quality = quality or 0,
                minLevel = minLevel or 0,
                name = name or ("item:" .. entry.id),
            }
            pending = pending - 1
            if pending == 0 then
                callback(byId)
            end
        end)
    end
end

local MAX_POTIONS_IN_MACRO = 4

-- Ranks known healing potions into "usable now" vs. "next tier you're
-- not high enough level for yet", and builds the macro body.
local function RankUsableHealingPotions(byId)
    local playerLevel = UnitLevel("player")
    local usable = {}
    local nextTier = nil

    for _, entry in ipairs(KNOWN_HEALING_POTIONS) do
        local r = byId[entry.id]
        if r then
            if r.minLevel <= playerLevel then
                table.insert(usable, r)
            elseif not nextTier or r.minLevel < nextTier.minLevel then
                nextTier = r
            end
        end
    end

    table.sort(usable, function(a, b)
        if a.minLevel ~= b.minLevel then return a.minLevel > b.minLevel end
        if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
        return a.quality > b.quality
    end)

    return usable, nextTier
end

-- Healthstone (independent cooldown from potions since patch 8.0.1, always
-- safe to stack) + the ranked potion list + Recuperate, all in one macro --
-- no separate "Oh Crap Heal" macro, this IS the healing macro.
local function BuildHealingPotionMacro(byId)
    local usable, nextTier = RankUsableHealingPotions(byId)

    local lines = { "#showtooltip" }
    table.insert(lines, "/use item:" .. HEALTHSTONE_ITEM_ID)
    for i = 1, math.min(MAX_POTIONS_IN_MACRO, #usable) do
        table.insert(lines, "/use [combat] item:" .. usable[i].id)
    end
    -- Recuperate is a universal General-tab ability every class has (no
    -- training required), so it's always safe to append here.
    table.insert(lines, "/cast [nocombat] " .. SpellName(RECUPERATE_SPELL_ID))

    return table.concat(lines, "\n"), usable, nextTier
end

-- Builds the DPS potion macro in fixed priority order (fleeting first),
-- only including entries you're currently high enough level to use.
local function BuildDPSPotionMacro(byId)
    local playerLevel = UnitLevel("player")
    local lines = { "#showtooltip" }
    local included = {}

    for _, entry in ipairs(KNOWN_DPS_POTIONS) do
        local r = byId[entry.id]
        if r and r.minLevel <= playerLevel then
            table.insert(lines, "/use [combat] item:" .. entry.id)
            table.insert(included, r)
        end
    end

    return table.concat(lines, "\n"), included
end

--------------------------------------------------------------------------
-- Macro creation / update helper
--------------------------------------------------------------------------
local function CreateOrUpdateMacro(name, icon, body)
    local index = GetMacroIndexByName(name)
    if index and index > 0 then
        EditMacro(index, name, icon, body)
        return true
    else
        local newIndex = CreateMacro(name, icon, body, true) -- perCharacter = true
        if not newIndex then
            return false, "Macro limit reached (character macros). Delete an old macro and try again."
        end
        return true
    end
end

--------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------
local frame = CreateFrame("Frame", "XalsAutoMacFrame", UIParent)
local FRAME_WIDTH = 380
-- Placeholder height only -- invisible, the frame stays Hidden() until the
-- player opens it. Real height is measured off the actual last element's
-- position once everything below is built (see the auto-fit block at the
-- end of this file), never guessed as a fixed number again.
frame:SetSize(FRAME_WIDTH, 900)
frame:SetFrameStrata("DIALOG")
Brand.ApplyBackground(frame)
Brand.ApplyBackgroundImage(frame)
Brand.DrawBorder(frame)
frame:SetPoint("CENTER", UIParent, "CENTER", 60, 220) -- placeholder until MacroFrame opens and repositions this, see below
frame:SetToplevel(true)
frame:Hide()

frame.title = Brand.Title(frame, "Xal's AutoMac", 22, "TOP", frame, "TOP", 0, -20)
Brand.DrawDivider(frame, Brand.SAFE_MARGIN, 46, FRAME_WIDTH - Brand.SAFE_MARGIN * 2)

local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
statusText:SetPoint("TOP", frame, "TOP", 0, -58)
statusText:SetWidth(300)
statusText:SetJustifyH("CENTER")

local _, classToken = UnitClass("player")
local interruptData = GetInterruptForCurrentSpec(classToken)
local charDB = GetCharDB()

local function SetStatus(text, isError)
    statusText:SetText(text)
    if isError then
        statusText:SetTextColor(1, 0.35, 0.35)
    else
        statusText:SetTextColor(0.6, 1, 0.6)
    end
end

--------------------------------------------------------------------------
-- Blizzard's real macro window -- always open alongside ours, physically
-- attached (our frame's left border sits directly against its right
-- border), not opened separately by a click. Verified against ElvUI's own
-- live Blizzard_MacroUI skin (Interface\AddOns\ElvUI\Game\Mainline\Skins\
-- Macro.lua) for the real widget names, and against the actual FrameXML
-- source for MacroFrameMixin:SelectMacro's index math.
--------------------------------------------------------------------------
-- Our frame's left border overlaps MacroFrame's right border by exactly
-- one line-thickness, so the two 2px borders draw on top of each other
-- and read as a single minimal seam instead of stacking into a 4px gap.
local function PositionNextToMacroFrame()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", MacroFrame, "TOPRIGHT", -Brand.LINE_THICKNESS, 0)
end

-- Reskin + hook up the one-time stuff. Deliberately does NOT run at file
-- load -- Blizzard_MacroUI (which is where MacroFrame/MacroFrameText/etc.
-- actually get defined) is a load-on-demand module, not guaranteed loaded
-- yet when this addon's own file executes. Only called from inside
-- OpenAttachedToMacroFrame, after that load has already been forced.
-- Prints a visible error instead of pcall silently swallowing it. A silent
-- failure here means the reskin/select just doesn't happen with zero
-- explanation -- this addon can't be tested without seeing what actually
-- broke, so surface it instead of hiding it.
local function TryOrReport(label, fn)
    local ok, err = pcall(fn)
    if not ok then
        print("|cffff5555Xal's AutoMac|r " .. label .. " failed: " .. tostring(err))
    end
    return ok
end

local macroFrameSkinned = false
local function ReskinMacroFrame()
    if macroFrameSkinned then return end
    macroFrameSkinned = true
    TryOrReport("resize (more buffer, same content size)", function()
        -- SetSize, not SetScale -- everything inside (icon grid, buttons,
        -- text) keeps its real size and its fixed TOPLEFT-relative offset,
        -- the extra room just becomes empty buffer along the right/bottom
        -- instead of blowing up the content itself.
        MacroFrame:SetSize(398, 494)
    end)
    TryOrReport("reposition content off the edges", function()
        -- Growing the frame alone doesn't touch these -- every one of these
        -- is anchored with a small fixed offset straight off MacroFrame's
        -- own TOPLEFT/BOTTOMLEFT/BOTTOMRIGHT corner (confirmed against the
        -- real Blizzard_MacroUI.xml source), so resizing just moves the
        -- opposite corner outward and leaves these still glued to the edge.
        -- Shifting each one in by a real inset is the only way to actually
        -- get buffer on the left/top/bottom. Widgets anchored to ANOTHER
        -- one of these (the selected-macro name/edit button/scroll frame/
        -- save/cancel buttons, Tab2) are left alone -- they follow their
        -- parent anchor automatically.
        local INSET = 20
        MacroHorizontalBarLeft:SetPoint("TOPLEFT", MacroFrame, "TOPLEFT", 2 + INSET, -210 - INSET)
        MacroFrameSelectedMacroBackground:SetPoint("TOPLEFT", MacroFrame, "TOPLEFT", 5 + INSET, -218 - INSET)
        MacroFrame.MacroSelector:SetPoint("TOPLEFT", MacroFrame, "TOPLEFT", 12 + INSET, -66 - INSET)
        MacroFrameTextBackground:SetPoint("TOPLEFT", MacroFrame, "TOPLEFT", 6 + INSET, -289 - INSET)
        MacroFrameTab1:SetPoint("TOPLEFT", MacroFrame, "TOPLEFT", 51 + INSET, -28 - INSET)
        MacroFrameCharLimitText:SetPoint("BOTTOM", MacroFrame, "BOTTOM", -15, 30 + INSET)
        MacroDeleteButton:SetPoint("BOTTOMLEFT", MacroFrame, "BOTTOMLEFT", 4 + INSET, 4 + INSET)
        MacroNewButton:SetPoint("BOTTOMRIGHT", MacroFrame, "BOTTOMRIGHT", -82 - INSET, 4 + INSET)
        MacroExitButton:SetPoint("BOTTOMRIGHT", MacroFrame, "BOTTOMRIGHT", -5 - INSET, 4 + INSET)
    end)
    TryOrReport("background/border", function()
        Brand.ApplyBackground(MacroFrame)
        Brand.ApplyBackgroundImage(MacroFrame)
        Brand.DrawBorder(MacroFrame)
    end)
    TryOrReport("body text font", function()
        MacroFrameText:SetFont(Brand.BODY_FONT_PATH, 13, "")
    end)
    TryOrReport("button fonts", function()
        for _, widget in ipairs({
            MacroSaveButton, MacroCancelButton, MacroDeleteButton,
            MacroNewButton, MacroExitButton, MacroEditButton,
        }) do
            local fs = widget.GetFontString and widget:GetFontString()
            if fs then
                fs:SetFont(Brand.BODY_FONT_PATH, 13, "")
                fs:SetTextColor(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
            end
        end
    end)
    TryOrReport("tab fonts", function()
        for _, tab in ipairs({ MacroFrameTab1, MacroFrameTab2 }) do
            local fs = tab.Text or (tab.GetFontString and tab:GetFontString())
            if fs then
                fs:SetFont(Brand.BODY_FONT_PATH, 13, "")
                fs:SetTextColor(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
            end
        end
    end)
    TryOrReport("close/drag hooks", function()
        -- Closing Blizzard's real window (its own native close button)
        -- closes ours too -- there's no close button on our own frame, by
        -- design.
        hooksecurefunc(MacroFrame, "Hide", function() frame:Hide() end)
        -- If the player drags Blizzard's window after both are open, keep
        -- ours attached to it rather than leaving it behind.
        MacroFrame:HookScript("OnDragStop", function()
            if frame:IsShown() then PositionNextToMacroFrame() end
        end)
    end)
end

-- index here is relative to whichever tab is selected (starts at 1 for the
-- first macro in that tab), NOT the raw macro slot -- confirmed straight
-- from MacroFrameMixin:SelectMacro's real body: it converts via
-- GetMacroDataIndex(index), which adds macroBase (MAX_ACCOUNT_MACROS for
-- the Character tab). GetMacroIndexByName returns the raw slot, so this
-- subtracts that same base back out rather than a hardcoded "120".
local function SelectMacroInBlizzardFrame(name)
    local rawIndex = GetMacroIndexByName(name)
    if not rawIndex or rawIndex <= 0 then
        print("|cffff5555Xal's AutoMac|r couldn't find a saved macro named '" .. name .. "' to select.")
        return
    end
    local relativeIndex = rawIndex - Constants.MacroConsts.MAX_ACCOUNT_MACROS
    TryOrReport("select macro '" .. name .. "'", function()
        MacroFrame:SelectMacro(relativeIndex, true)
    end)
end

-- Opens Blizzard's real macro frame on the Character tab, reskins it
-- (once), and attaches ours to it. Runs every time our frame shows.
-- Force-loads Blizzard_MacroUI first rather than assuming ShowMacroFrame()
-- alone guarantees it -- MacroFrame and everything else this file touches
-- only exist as globals once that load-on-demand module is actually in.
local function OpenAttachedToMacroFrame()
    if not MacroFrame then
        C_AddOns.LoadAddOn("Blizzard_MacroUI")
    end
    ShowMacroFrame()
    TryOrReport("switch to Character tab", function()
        PanelTemplates_SetTab(MacroFrame, 2)
        MacroFrame:SetCharacterMacros()
        MacroFrame:Update()
    end)
    ReskinMacroFrame()
    PositionNextToMacroFrame()
end

frame:SetScript("OnShow", OpenAttachedToMacroFrame)

-- The catalog of every possible macro this addon manages. Interrupt is
-- ALWAYS in this list (never omitted) -- it just renders disabled/greyed
-- when this spec has none, so the player sees why instead of it silently
-- not being there.
local slotDefs = {}
table.insert(slotDefs, { label = "Interrupt", name = "XAMKick", icon = "ability_kick",
    disabled = not interruptData,
    note = interruptData and interruptData.note or "No interrupt for your current spec",
    build = function() return interruptData and BuildInterruptMacro(interruptData.id) end })
table.insert(slotDefs, { label = "Healing", name = "XAMPotion", icon = "inv_potion_93", async = true,
    build = function(cb)
        LoadKnownItems(KNOWN_HEALING_POTIONS, function(byId)
            local body, usable, nextTier = BuildHealingPotionMacro(byId)
            if #usable == 0 then
                SetStatus("Not high enough level for any known healing potion yet.", true)
                return
            end
            charDB.nextPotionMinLevel = nextTier and nextTier.minLevel or nil
            cb(body)
        end)
    end })
table.insert(slotDefs, { label = "DPS Potion", name = "XAMDPS", icon = "inv_alchemy_elixir_04", async = true,
    build = function(cb)
        LoadKnownItems(KNOWN_DPS_POTIONS, function(byId)
            local body, included = BuildDPSPotionMacro(byId)
            if #included == 0 then
                SetStatus("Not high enough level for any known DPS potion yet.", true)
                return
            end
            cb(body)
        end)
    end })
local cleanseData = CLASS_CLEANSE[classToken]
if cleanseData then
    table.insert(slotDefs, { label = "Cleanse", name = "XAMCleanse", icon = "spell_holy_purify",
        build = function() return BuildFriendlyTargetMacro(cleanseData.id) end })
end
local massDispelData = CLASS_MASS_DISPEL[classToken]
if massDispelData then
    table.insert(slotDefs, { label = "Mass Dispel", name = "XAMMassDispel", icon = "spell_arcane_massdispel",
        build = function() return BuildFriendlyTargetMacro(massDispelData.id) end })
end

--------------------------------------------------------------------------
-- Generate -- one text-link button per macro type. Click one: build the
-- body, write it via CreateOrUpdateMacro (unchanged, existing helper),
-- then select that exact macro in Blizzard's real window so its content
-- shows there for review -- Save/Cancel from here on are Blizzard's own.
--------------------------------------------------------------------------
local generateLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
generateLabel:SetPoint("TOP", statusText, "BOTTOM", 0, -18)
generateLabel:SetText("Generate")

local lastSlotBtn
for _, def in ipairs(slotDefs) do
    local btn = Brand.MakeButton(frame, def.label, FRAME_WIDTH - Brand.SAFE_MARGIN * 2 - 20, 22)
    if lastSlotBtn then
        btn:SetPoint("TOP", lastSlotBtn, "BOTTOM", 0, -4)
    else
        btn:SetPoint("TOP", generateLabel, "BOTTOM", 0, -10)
    end
    if def.disabled then
        -- Mouse stays enabled so hover/tooltip still works -- only the
        -- click action is withheld (no OnClick wired below). Disabling
        -- mouse entirely would also block OnEnter/OnLeave, killing the
        -- tooltip that explains why it's greyed out.
        btn.label:SetTextColor(0.45, 0.45, 0.45)
    else
        btn:SetScript("OnClick", function()
            print("|cff55ff55Xal's AutoMac|r '" .. def.label .. "' clicked.")
            local function Finish(body)
                TryOrReport("generate '" .. def.name .. "'", function()
                    local ok, err = CreateOrUpdateMacro(def.name, def.icon, body)
                    if ok then
                        SetStatus("'" .. def.name .. "' ready -- review it in the window on the left.")
                        SelectMacroInBlizzardFrame(def.name)
                    else
                        SetStatus(err, true)
                    end
                end)
            end
            TryOrReport("build '" .. def.name .. "'", function()
                if def.async then
                    SetStatus("Looking up...")
                    def.build(Finish)
                else
                    Finish(def.build())
                end
            end)
        end)
    end
    -- One combined OnEnter: disabled buttons stay grey instead of
    -- brightening to white on hover (overriding Brand.MakeButton's default
    -- hover behavior), and either kind shows a tooltip if it has a note.
    if def.disabled or def.note then
        btn:SetScript("OnEnter", function(self)
            if def.disabled then
                btn.label:SetTextColor(0.45, 0.45, 0.45)
            end
            if def.note then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(def.note)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function()
            if def.disabled then
                btn.label:SetTextColor(0.45, 0.45, 0.45)
            end
            GameTooltip:Hide()
        end)
    end
    lastSlotBtn = btn
end

--------------------------------------------------------------------------
-- Custom Macro -- unchanged logic, just laid out in the single column now.
--------------------------------------------------------------------------
local customDivider = frame:CreateTexture(nil, "ARTWORK")
customDivider:SetColorTexture(0.16, 0.12, 0.05, 1)
customDivider:SetHeight(Brand.LINE_THICKNESS)
customDivider:SetPoint("TOPLEFT", lastSlotBtn, "BOTTOMLEFT", 0, -14)
customDivider:SetPoint("TOPRIGHT", lastSlotBtn, "BOTTOMRIGHT", 0, -14)

local customLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
customLabel:SetPoint("TOP", customDivider, "BOTTOM", 0, -10)
customLabel:SetText("Custom Macro")

-- Real inline rows -- a text-link BUTTON on the left, a field on the
-- right. Type/select in the field, then click the button to create that
-- row's macro -- the button is the trigger, not Enter in the field.
local ROW_LABEL_W = 68
local ROW_GAP = 8
local ROW_FIELD_W = 220
-- Rows are centered as a block: label+gap+field together, not chained off
-- customLabel's own left edge (which is text-width-dependent since
-- customLabel is itself centered under the divider, not left-aligned).
local ROW_BLOCK_X = -(ROW_LABEL_W + ROW_GAP + ROW_FIELD_W) / 2
local function CustomRow(labelText, anchorTo, yOffset)
    local label = Brand.MakeButton(frame, labelText, ROW_LABEL_W, 22)

    local field = Brand.MakeEditBox(frame, ROW_FIELD_W, 22)

    if anchorTo then
        label:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, yOffset)
    else
        label:SetPoint("TOPLEFT", customLabel, "TOP", ROW_BLOCK_X, yOffset)
    end
    field:SetPoint("LEFT", label, "RIGHT", ROW_GAP, 0)

    return label, field
end

local mouseoverLabel, mouseoverField = CustomRow("Mouseover", nil, -28)
local targetLabel, targetField = CustomRow("@Target", mouseoverLabel, -18)
local nameLabel, nameField = CustomRow("By Name", targetLabel, -18)

-- Centered on the frame (not left-anchored to the row block) and given an
-- explicit width, so customHint below it can chain off a predictable,
-- already-centered TOP/BOTTOM anchor instead of an auto-width fontstring
-- whose horizontal center isn't knowable in advance.
local customCounter = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
-- nameLabel's own "BOTTOM" anchor point is ITS bottom-center, not the row
-- block's center -- offset by (ROW_GAP+ROW_FIELD_W)/2 to actually land on
-- the block's true center (verified algebraically: block center sits at
-- ROW_BLOCK_X + total/2 = 0 by construction; nameLabel's own center sits
-- at ROW_BLOCK_X + ROW_LABEL_W/2; the difference reduces to this).
customCounter:SetPoint("TOP", nameLabel, "BOTTOM", (ROW_GAP + ROW_FIELD_W) / 2, -10)
customCounter:SetWidth(FRAME_WIDTH - Brand.SAFE_MARGIN * 2 - 20)
customCounter:SetJustifyH("CENTER")
customCounter:SetTextColor(Brand.GOLD[1], Brand.GOLD[2], Brand.GOLD[3])
customCounter:SetText("")

local customHint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
customHint:SetPoint("TOP", customCounter, "BOTTOM", 0, -4)
customHint:SetWidth(FRAME_WIDTH - Brand.SAFE_MARGIN * 2 - 20)
customHint:SetWordWrap(true)
customHint:SetJustifyH("CENTER")
customHint:SetText("Type or select a spell/name, then click the button to its left")

-- selectedSpellID[field] tracks the resolved spell ID for whichever spell
-- field the player last picked an autocomplete suggestion in (mouseoverField
-- or targetField) -- nameField never gets an entry, it's free text.
local selectedSpellID = {}
local activeField -- whichever field the player is currently typing in, drives the shared counter

local function UpdateCounter(field)
    if field ~= activeField then return end
    local text = field:GetText()
    local body
    if field == nameField then
        body = text ~= "" and BuildTargetByNameMacro(text) or "#showtooltip\n/targetexact "
    else
        local spellID = selectedSpellID[field] or 123456
        body = field == mouseoverField and BuildCustomMouseoverMacro(spellID) or BuildCustomTargetMacro(spellID)
    end
    customCounter:SetText(#body .. " of 255 characters used")
    customCounter:SetTextColor(unpack(#body > 255 and { 1, 0.35, 0.35 } or Brand.GOLD))
end

local function CreateFromField(field, mode)
  TryOrReport("build custom macro (" .. mode .. ")", function()
    local text = field:GetText()
    if text == "" then
        SetStatus("Type something first.", true)
        return
    end
    if mode == "name" then
        local body = BuildTargetByNameMacro(text)
        local ok, err = CreateOrUpdateMacro("XAMCustomName", "ability_hunter_snipershot", body)
        if ok then
            SetStatus("'XAMCustomName' ready -- review it in the window on the left.")
            SelectMacroInBlizzardFrame("XAMCustomName")
        else
            SetStatus(err, true)
        end
        return
    end

    local spellID = selectedSpellID[field]
    if not spellID then
        local spell = C_Spell.GetSpellInfo(text)
        spellID = spell and spell.spellID
    end
    if not spellID then
        SetStatus("Don't know a spell by that name -- pick one from the list.", true)
        return
    end

    if mode == "mouseover" then
        local body = BuildCustomMouseoverMacro(spellID)
        local ok, err = CreateOrUpdateMacro("XAMCustomMouseover", "inv_misc_questionmark", body)
        if ok then
            SetStatus("'XAMCustomMouseover' ready -- review it in the window on the left.")
            SelectMacroInBlizzardFrame("XAMCustomMouseover")
        else
            SetStatus(err, true)
        end
    else
        local body = BuildCustomTargetMacro(spellID)
        local ok, err = CreateOrUpdateMacro("XAMCustomTarget", "inv_misc_questionmark", body)
        if ok then
            SetStatus("'XAMCustomTarget' ready -- review it in the window on the left.")
            SelectMacroInBlizzardFrame("XAMCustomTarget")
        else
            SetStatus(err, true)
        end
    end
  end)
end

for _, entry in ipairs({
    { field = mouseoverField, label = mouseoverLabel, mode = "mouseover", spellLookup = true },
    { field = targetField, label = targetLabel, mode = "target", spellLookup = true },
    { field = nameField, label = nameLabel, mode = "name", spellLookup = false },
}) do
    local field, label, mode, spellLookup = entry.field, entry.label, entry.mode, entry.spellLookup

    field:SetScript("OnEditFocusGained", function()
        activeField = field
        UpdateCounter(field)
    end)
    label:SetScript("OnClick", function()
        CreateFromField(field, mode)
        field:ClearFocus()
    end)

    if spellLookup then
        AttachAutocomplete(field, frame, function(text)
            local out = {}
            for _, spell in ipairs(GetKnownSpells()) do
                if spell.name:lower():sub(1, #text) == text:lower() then
                    table.insert(out, spell.name)
                    if #out >= 8 then break end
                end
            end
            return out
        end, function(name)
            local spell = C_Spell.GetSpellInfo(name)
            selectedSpellID[field] = spell and spell.spellID
            UpdateCounter(field)
        end, function()
            selectedSpellID[field] = nil
            UpdateCounter(field)
        end)
    else
        field:SetScript("OnTextChanged", function() UpdateCounter(field) end)
    end
end
activeField = mouseoverField

-- Auto-fit the frame to whatever actually got built above -- no guessed
-- constant, no per-class special-casing. customHint is the true last
-- element regardless of how many class-specific buttons exist above it.
-- Same measure-then-resize technique WhatsNew.lua already used correctly.
--
-- Runs on OnShow, not inline at file-load time -- GetTop()/GetBottom() are
-- not reliable on a frame that's still hidden and has never actually been
-- laid out by the renderer yet (this whole file executes with frame:Hide()
-- already called above), so measuring here instead of at load time is what
-- actually gets a real number back.
frame:HookScript("OnShow", function()
    -- Reset to the same fixed baseline EVERY time before measuring. Without
    -- this, adjusting the CURRENT height by a delta compounds on every
    -- close/reopen (Hide/Show cycle from /xam) -- each pass measures from
    -- an already-wrong height and drifts further off, which is why this
    -- kept getting worse the more the panel was toggled rather than
    -- staying fixed after the first correct measurement.
    frame:SetHeight(900)
    local desiredGap = Brand.SAFE_MARGIN * 2 -- clear space below the last element, above the border
    local actualGap = customHint:GetBottom() - frame:GetBottom()
    local contentFitHeight = frame:GetHeight() - (actualGap - desiredGap)
    -- Match Blizzard's real window height so the two panels line up as one
    -- bundled unit instead of our own bottom edge sitting higher or lower
    -- than theirs -- but never go SHORTER than what the content actually
    -- needs, so the bottom buffer above still holds even if Blizzard's
    -- window is shorter than our content some day.
    local macroFrameHeight = MacroFrame and MacroFrame:GetHeight() or 0
    frame:SetHeight(math.max(contentFitHeight, macroFrameHeight))
end)

--------------------------------------------------------------------------
-- Level-up notification
-- Fires when you level up (or log in) and checks whether you've now
-- crossed the level requirement of a healing potion that was too
-- high-level to use during your last scan.
--------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    local db = GetCharDB()
    if db.nextPotionMinLevel then
        local level = UnitLevel("player")
        if level >= db.nextPotionMinLevel then
            print("|cff33ff99Xal's AutoMac|r: You can use a stronger potion now! Type /xam and click 'Healing'.")
            if UIErrorsFrame then
                UIErrorsFrame:AddMessage("A stronger potion is available -- update your potion macro!", 1, 0.8, 0)
            end
            db.nextPotionMinLevel = nil -- next scan will set a fresh threshold
        end
    end
end)

--------------------------------------------------------------------------
-- Slash command
--------------------------------------------------------------------------
SLASH_XALSAUTOMAC1 = "/xam"
SLASH_XALSAUTOMAC2 = "/xals"
SlashCmdList["XALSAUTOMAC"] = function()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
    if loadedAddonName == ADDON_NAME then
        print("|cff33ff99Xal's AutoMac|r loaded. Type |cffffffff/xam|r to open.")
        if addonTable.WhatsNew then
            addonTable.WhatsNew:CheckAndShow()
        end
    end
end)
