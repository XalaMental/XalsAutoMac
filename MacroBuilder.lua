-- MacroBuilder.lua
-- Xal's AutoMac
--
-- The "macro for dummies" builder - pick a spell, pick the conditional
-- tags (target/state/dead/combat) from real dropdown menus
-- (Brand.MakeDropdown, the current brand-styled widget, not Blizzard's
-- native dropdown template), see the live macro text build itself. Every
-- section has real, ALWAYS-VISIBLE explanation text, not
-- just a hover tooltip -- someone who doesn't already know macro syntax
-- (the entire point of this tool) has no reason to hover to discover
-- there's more information available.
--
-- Supports multiple CONDITIONS chained together (e.g. "cast SpellA if the
-- target is dead, otherwise cast SpellB") -- each condition is its own
-- clause with its own spell + tags, joined with ";" the way WoW's macro
-- conditionals actually work: the game tries each clause left to right and
-- uses the first one whose tag matches.
--
-- Auto-fits its own height to whatever it actually contains, same
-- measure-then-resize technique Core.lua's main panel uses -- never a
-- guessed fixed height. Since adding/removing a condition changes how
-- much content exists, the whole dynamic section (every clause + the Add
-- button + Preview + Create) is rebuilt from scratch on every change,
-- rather than trying to patch anchors in place -- far less bug-prone than
-- incrementally re-anchoring a variable number of blocks.

local ADDON_NAME, addonTable = ...
addonTable.MacroBuilder = {}
local MacroBuilder = addonTable.MacroBuilder
local Brand = addonTable.BrandStyle

local WIN_W = 340
local window
local intro
local preview
local lastElement -- the true bottom-most element, for the auto-fit measurement
local clauseWidgets = {} -- every dynamically-created widget, hidden+discarded on rebuild

local clauses = { { target = "", harm = "", dead = "", combat = "", spell = "" } }

local TARGET_OPTIONS = {
    { value = "", label = "None", tip = "No target tag -- the macro acts on whatever you have currently targeted." },
    { value = "@player", label = "@player", tip = "Always targets yourself, no matter what you have targeted or moused over." },
    { value = "@target", label = "@target", tip = "Explicitly your current target -- same as no tag, but useful when combining with other conditionals." },
    { value = "@focus", label = "@focus", tip = "Your focus target, set with /focus." },
    { value = "@mouseover", label = "@mouseover", tip = "Whatever unit frame or nameplate your mouse is currently over." },
}

local HARM_OPTIONS = {
    { value = "", label = "Any", tip = "Works regardless of whether the target is friendly or an enemy." },
    { value = "harm", label = "harm", tip = "Only fires if the target is an enemy (harmful target)." },
    { value = "help", label = "help", tip = "Only fires if the target is friendly (helpful target)." },
}

local DEAD_OPTIONS = {
    { value = "", label = "Any", tip = "Works whether the target is alive or dead." },
    { value = "nodead", label = "nodead", tip = "Only fires if the target is alive -- avoids wasting the cast on a corpse." },
    { value = "dead", label = "dead", tip = "Only fires if the target is dead -- useful for combat-rez style spells." },
}

local COMBAT_OPTIONS = {
    { value = "", label = "Any", tip = "Works whether you're in combat or not." },
    { value = "combat", label = "combat", tip = "Only fires while you're in combat." },
    { value = "nocombat", label = "nocombat", tip = "Only fires while you're out of combat." },
}

local function BuildClauseText(clause)
    local parts = {}
    if clause.target ~= "" then table.insert(parts, clause.target) end
    if clause.harm ~= "" then table.insert(parts, clause.harm) end
    if clause.dead ~= "" then table.insert(parts, clause.dead) end
    if clause.combat ~= "" then table.insert(parts, clause.combat) end
    local tag = #parts > 0 and ("[" .. table.concat(parts, ",") .. "] ") or ""
    local spellText = clause.spell ~= "" and clause.spell or "SpellName"
    return tag .. spellText
end

local function UpdatePreview()
    local segments = {}
    for _, clause in ipairs(clauses) do
        table.insert(segments, BuildClauseText(clause))
    end
    preview:SetText("#showtooltip\n/cast " .. table.concat(segments, "; "))
end

-- Shared hidden FontString used only to measure text -- never shown, just
-- queried for GetStringWidth() so each dropdown button is sized to its
-- OWN widest option instead of a guessed fixed width or the full window.
local measureFS = UIParent:CreateFontString(nil, "BACKGROUND")
local DROPDOWN_ARROW_PADDING = 44 -- room for the dropdown arrow + internal button padding
local DROPDOWN_MIN_WIDTH = 90

local function MeasureDropdownWidth(options)
    measureFS:SetFontObject(GameFontHighlightSmall)
    local widest = DROPDOWN_MIN_WIDTH
    for _, opt in ipairs(options) do
        measureFS:SetText(opt.label)
        widest = math.max(widest, measureFS:GetStringWidth() + DROPDOWN_ARROW_PADDING)
    end
    return widest
end

-- A labeled dropdown for one option group on a specific clause -- built on
-- Brand.MakeDropdown, the current brand-styled widget (not Blizzard's
-- native dropdown template). Every created widget is appended to `track`
-- so a rebuild can hide it later.
local function AddDropdown(parent, track, anchorAbove, gap, label, description, options, clause, stateKey, defaultLabel)
    local heading = Brand.FS(parent, label, Brand.BODY_FONT_PATH, 14, nil,
        Brand.GOLD[1], Brand.GOLD[2], Brand.GOLD[3])
    heading:SetPoint("TOPLEFT", anchorAbove, "BOTTOMLEFT", 0, gap)
    table.insert(track, heading)

    local desc = Brand.FS(parent, description, Brand.BODY_FONT_PATH, 13, nil, 0.62, 0.62, 0.62)
    desc:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
    desc:SetPoint("RIGHT", parent, "RIGHT", -Brand.SAFE_MARGIN, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    table.insert(track, desc)

    local dropdown = Brand.MakeDropdown(parent, MeasureDropdownWidth(options)) -- sized to its OWN widest option, not a guess
    dropdown:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -6)

    local ddOptions = {}
    for _, opt in ipairs(options) do
        table.insert(ddOptions, { key = opt.value, name = opt.label })
    end
    dropdown:SetOptions(ddOptions)
    dropdown:SetValue(clause[stateKey])
    dropdown.OnSelect = function(value)
        clause[stateKey] = value
        UpdatePreview()
    end
    table.insert(track, dropdown)

    return dropdown
end

local FitHeight -- forward declaration, defined after BuildWindow
local RebuildDynamic -- forward declaration, defined after BuildWindow

-- One full condition block: header (+ Remove link if more than one clause
-- exists), Spell field, and the four tag dropdowns. Returns the block's
-- own bottom-most widget for the next block/element to anchor below.
local function BuildClauseBlock(f, anchorAbove, index)
    local clause = clauses[index]

    local header = Brand.FS(f, "Condition " .. index, Brand.BODY_FONT_PATH, 15, nil,
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    header:SetPoint("TOPLEFT", anchorAbove, "BOTTOMLEFT", 0, index == 1 and -20 or -26)
    table.insert(clauseWidgets, header)

    if #clauses > 1 then
        local removeBtn = Brand.MakeButton(f, "Remove", 70, 18)
        removeBtn:SetPoint("LEFT", header, "RIGHT", 10, 0)
        removeBtn:SetScript("OnClick", function()
            table.remove(clauses, index)
            RebuildDynamic()
        end)
        table.insert(clauseWidgets, removeBtn)
    end

    local spellDesc = Brand.FS(f, "The exact name of a spell you know, e.g. \"Flash Heal\".",
        Brand.BODY_FONT_PATH, 13, nil, 0.62, 0.62, 0.62)
    spellDesc:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
    spellDesc:SetPoint("RIGHT", f, "RIGHT", -Brand.SAFE_MARGIN, 0)
    spellDesc:SetJustifyH("LEFT")
    spellDesc:SetWordWrap(true)
    table.insert(clauseWidgets, spellDesc)

    local spellField = Brand.MakeEditBox(f, f.contentWidth, 22)
    spellField:SetPoint("TOPLEFT", spellDesc, "BOTTOMLEFT", 0, -6)
    spellField:SetText(clause.spell)
    spellField:SetScript("OnTextChanged", function(self)
        clause.spell = self:GetText()
        UpdatePreview()
    end)
    table.insert(clauseWidgets, spellField)

    local targetDD = AddDropdown(f, clauseWidgets, spellField, -16, "Target",
        "Who or what the macro acts on. Leave this on None to just use whatever you already have targeted.",
        TARGET_OPTIONS, clause, "target", "None")
    local harmDD = AddDropdown(f, clauseWidgets, targetDD, -16, "State (harm / help)",
        "Whether the macro only works on an enemy (harm), only a friendly target (help), or either (Any).",
        HARM_OPTIONS, clause, "harm", "Any")
    local deadDD = AddDropdown(f, clauseWidgets, harmDD, -16, "Dead",
        "Whether the macro only works on a dead target, only a living one, or either (Any).",
        DEAD_OPTIONS, clause, "dead", "Any")
    local combatDD = AddDropdown(f, clauseWidgets, deadDD, -16, "Combat",
        "Whether the macro only works while you're in combat, only out of combat, or either (Any).",
        COMBAT_OPTIONS, clause, "combat", "Any")

    return combatDD
end

local function BuildWindow()
    if window then return window end

    local f = CreateFrame("Frame", "XalsAutoMacBuilderWindow", UIParent)
    tinsert(UISpecialFrames, "XalsAutoMacBuilderWindow")
    f:SetSize(WIN_W, 900) -- placeholder height, corrected by FitHeight()
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        addonTable.Options:Set("macroBuilderPos", { point = point, relPoint = relPoint, x = x, y = y })
    end)
    f:SetClampedToScreen(true)

    local pos = addonTable.Options:Get("macroBuilderPos", nil)
    if pos and pos.point then
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", -200, 0)
    end
    f.contentWidth = WIN_W - Brand.SAFE_MARGIN * 2

    Brand.ApplyBackground(f)
    Brand.DrawBorder(f, 1) -- flush-edge outer window border, current family standard

    Brand.Title(f, "Macro Builder", 20, "TOP", f, "TOP", 0, -Brand.SAFE_MARGIN - 4)
    Brand.DrawHeaderDivider(f, Brand.SAFE_MARGIN, 46, WIN_W - Brand.SAFE_MARGIN * 2)

    intro = Brand.FS(f, "Build a spell macro without needing to know the syntax -- fill in the fields below and the real macro text is built for you. Add more than one condition for an \"if this, else that\" macro, like casting a different spell on a dead target than a living one.",
        Brand.BODY_FONT_PATH, 13, nil, 0.62, 0.62, 0.62)
    intro:SetPoint("TOPLEFT", f, "TOPLEFT", Brand.SAFE_MARGIN, -60)
    intro:SetPoint("RIGHT", f, "RIGHT", -Brand.SAFE_MARGIN, 0)
    intro:SetJustifyH("LEFT")
    intro:SetWordWrap(true)

    f.window = f
    window = f
    f:Hide()
    RebuildDynamic()
    return f
end

-- Rebuilds every clause block plus the Add/Preview/Create footer from
-- scratch. Called on Open() the first time, and again any time a
-- condition is added or removed.
RebuildDynamic = function()
    local f = window
    for _, w in ipairs(clauseWidgets) do w:Hide() end
    clauseWidgets = {}

    local anchor = intro
    for i = 1, #clauses do
        anchor = BuildClauseBlock(f, anchor, i)
    end

    local addDesc = Brand.FS(f,
        "Only need one? Leave it as-is. Add a second condition to make an \"if this, else that\" macro -- the game checks each condition in order, top to bottom, and uses the first one that matches. Example: Condition 1 = Rebirth with the Dead tag, Condition 2 = Regrowth with no tags -- brings a dead ally back if you have one moused over/targeted, otherwise just heals normally.",
        Brand.BODY_FONT_PATH, 13, nil, 0.62, 0.62, 0.62)
    addDesc:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -20)
    addDesc:SetPoint("RIGHT", f, "RIGHT", -Brand.SAFE_MARGIN, 0)
    addDesc:SetJustifyH("LEFT")
    addDesc:SetWordWrap(true)
    table.insert(clauseWidgets, addDesc)

    local addBtn = Brand.MakeButton(f, "+ Add another condition", f.contentWidth, 22)
    addBtn:SetPoint("TOP", addDesc, "BOTTOM", 0, -10)
    addBtn:SetScript("OnClick", function()
        table.insert(clauses, { target = "", harm = "", dead = "", combat = "", spell = "" })
        RebuildDynamic()
    end)
    table.insert(clauseWidgets, addBtn)

    local previewLabel = Brand.FS(f, "Preview", Brand.BODY_FONT_PATH, 14, nil,
        Brand.GOLD[1], Brand.GOLD[2], Brand.GOLD[3])
    previewLabel:SetPoint("TOPLEFT", addBtn, "BOTTOMLEFT", 0, -20)
    table.insert(clauseWidgets, previewLabel)

    preview = Brand.FS(f, "", Brand.BODY_FONT_PATH, 13, nil, 1, 1, 1)
    preview:SetPoint("TOPLEFT", previewLabel, "BOTTOMLEFT", 0, -6)
    preview:SetPoint("RIGHT", f, "RIGHT", -Brand.SAFE_MARGIN, 0)
    preview:SetJustifyH("LEFT")
    preview:SetWordWrap(true)
    table.insert(clauseWidgets, preview)

    -- Chained BELOW preview, not pinned to the frame's own fixed bottom --
    -- a fixed-bottom anchor is what let this button overlap the preview
    -- text once the preview grew past a hardcoded window height.
    local createBtn = Brand.MakeButton(f, "Create", f.contentWidth, 22)
    createBtn:SetPoint("TOP", preview, "BOTTOM", 0, -16)
    createBtn:SetScript("OnClick", function()
        local segments = {}
        for _, clause in ipairs(clauses) do
            if clause.spell ~= "" then table.insert(segments, BuildClauseText(clause)) end
        end
        if #segments == 0 then return end
        local body = "#showtooltip\n/cast " .. table.concat(segments, "; ")
        local name = "XAMBuilt"
        if GetMacroIndexByName(name) and GetMacroIndexByName(name) > 0 then
            EditMacro(GetMacroIndexByName(name), name, "INV_Misc_QuestionMark", body)
        else
            CreateMacro(name, "INV_Misc_QuestionMark", body, true)
        end
    end)
    table.insert(clauseWidgets, createBtn)

    UpdatePreview()
    lastElement = createBtn
    if f:IsShown() then FitHeight() end
end

function MacroBuilder:Open()
    local f = BuildWindow()
    f:Show()
    FitHeight()
end

-- Auto-fit height, same technique as Core.lua's main panel: reset to a
-- fixed placeholder before every measurement (otherwise repeated
-- Show/Hide cycles compound drift), then shrink to the real last
-- element's position plus a bottom buffer.
FitHeight = function()
    local f = window
    if not f or not lastElement then return end
    f:SetHeight(900)
    local desiredGap = Brand.SAFE_MARGIN * 2
    local actualGap = lastElement:GetBottom() - f:GetBottom()
    f:SetHeight(f:GetHeight() - (actualGap - desiredGap))
end
