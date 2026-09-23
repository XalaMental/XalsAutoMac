-- Options.lua
-- Xal's AutoMac
--
-- Standalone settings window - opened by the minimap button (left-click)
-- or /xam options. Separate from the main /xam panel (Generate/Custom
-- Macro/Suggested Macros), which stays exactly as it is.

local ADDON_NAME, addonTable = ...
addonTable.Options = {}
local Options = addonTable.Options
local Brand = addonTable.BrandStyle

local WIN_W = 340
local LABEL_FONT_SIZE = 14
local DESC_FONT_SIZE = 13
local RIGHT_MARGIN = 16

local window
local lastElement -- the true bottom-most element, for the auto-fit height measurement

-- Where the "you can use a stronger potion now" level-up notice shows.
-- Read by Core.lua's PLAYER_LEVEL_UP handler.
Options.NOTIFY_CHAT = "chat"
Options.NOTIFY_ERROR = "error"
Options.NOTIFY_RAIDWARNING = "raidwarning"

function Options:Get(key, default)
    if type(XalsAutoMacDB) ~= "table" then return default end
    if XalsAutoMacDB[key] == nil then return default end
    return XalsAutoMacDB[key]
end

function Options:Set(key, value)
    if type(XalsAutoMacDB) ~= "table" then return end
    XalsAutoMacDB[key] = value
end

-- Checkbox + 14px label beside it + 13px description underneath. Returns
-- the description FontString so a next row (if any) can anchor below it.
local function AddToggle(parent, anchorTo, yGap, label, description, checked, onToggle)
    local cb = Brand.MakeCheckbox(parent, 20)
    if anchorTo then
        cb:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, yGap)
    else
        -- Plain SAFE_MARGIN, matching the divider/headings/dropdown below
        -- it -- an inconsistent "+6" indent here is what put the dropdown
        -- flush against the border (it was sized for plain SAFE_MARGIN
        -- while actually starting 6px further right).
        cb:SetPoint("TOPLEFT", parent, "TOPLEFT", Brand.SAFE_MARGIN, -70)
    end
    cb:SetChecked(checked)
    cb.OnToggle = onToggle

    local text = Brand.FS(parent, label, Brand.BODY_FONT_PATH, LABEL_FONT_SIZE, nil,
        Brand.GOLD[1], Brand.GOLD[2], Brand.GOLD[3])
    text:SetPoint("LEFT", cb, "RIGHT", 8, 0)
    text:SetPoint("RIGHT", parent, "RIGHT", -RIGHT_MARGIN, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)

    local desc = Brand.FS(parent, description, Brand.BODY_FONT_PATH, DESC_FONT_SIZE, nil,
        0.62, 0.62, 0.62)
    desc:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -4)
    desc:SetPoint("RIGHT", parent, "RIGHT", -RIGHT_MARGIN, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)

    return desc, cb
end

-- Shared hidden FontString used only to measure text -- never shown, just
-- queried for GetStringWidth() so the dropdown button can be sized to its
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

-- A labeled dropdown for one option group -- Brand.MakeDropdown, the
-- current brand-styled widget (not Blizzard's native dropdown template).
local function AddDropdown(parent, anchorAbove, gap, label, description, options, getValue, setValue, defaultLabel)
    local heading = Brand.FS(parent, label, Brand.BODY_FONT_PATH, LABEL_FONT_SIZE, nil,
        Brand.GOLD[1], Brand.GOLD[2], Brand.GOLD[3])
    heading:SetPoint("TOPLEFT", anchorAbove, "BOTTOMLEFT", 0, gap)

    local desc = Brand.FS(parent, description, Brand.BODY_FONT_PATH, DESC_FONT_SIZE, nil,
        0.62, 0.62, 0.62)
    desc:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
    desc:SetPoint("RIGHT", parent, "RIGHT", -RIGHT_MARGIN, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)

    local dropdown = Brand.MakeDropdown(parent, MeasureDropdownWidth(options)) -- sized to its OWN widest option, not a guess
    dropdown:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -6)

    local ddOptions = {}
    for _, opt in ipairs(options) do
        table.insert(ddOptions, { key = opt.value, name = opt.label })
    end
    dropdown:SetOptions(ddOptions)
    dropdown:SetValue(getValue())
    dropdown.OnSelect = setValue

    return dropdown
end

local function BuildWindow()
    if window then return window end

    local f = CreateFrame("Frame", "XalsAutoMacOptionsWindow", UIParent)
    tinsert(UISpecialFrames, "XalsAutoMacOptionsWindow")
    f:SetSize(WIN_W, 900) -- placeholder height, corrected on Open() below
    f.contentWidth = WIN_W - Brand.SAFE_MARGIN * 2
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        Options:Set("optionsPos", { point = point, relPoint = relPoint, x = x, y = y })
    end)
    f:SetClampedToScreen(true)

    local pos = Options:Get("optionsPos", nil)
    if pos and pos.point then
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    end

    Brand.ApplyBackground(f)
    Brand.DrawBorder(f, 1) -- flush-edge outer window border, current family standard

    Brand.Title(f, "Xal's AutoMac Options", 20, "TOP", f, "TOP", 0, -Brand.SAFE_MARGIN - 4)

    -- Standing link, present on the What's New splash and the main
    -- Settings page per the family's Discord link standard.
    local discordLink = Brand.MakeDiscordLink(f)
    discordLink:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -20)

    Brand.DrawHeaderDivider(f, Brand.SAFE_MARGIN, 46, WIN_W - Brand.SAFE_MARGIN * 2)

    local minimapDesc = AddToggle(f, nil, 0,
        "Show minimap button",
        "Shows the AutoMac launcher icon on the minimap.",
        Options:Get("showMinimapButton", true),
        function(checked)
            Options:Set("showMinimapButton", checked)
            if addonTable.MinimapButton then
                addonTable.MinimapButton:SetShown(checked)
            end
        end)

    local notifyDD = AddDropdown(f, minimapDesc, -18,
        "Potion level-up notice",
        "When you level past what your current healing potion macro needs, AutoMac lets you know it's time to regenerate it. Choose where that shows up.",
        {
            { value = Options.NOTIFY_CHAT, label = "Chat",
              tip = "Prints in your chat window like a normal message." },
            { value = Options.NOTIFY_ERROR, label = "Error Banner",
              tip = "The small banner text near the top-center of the screen, same as a spell-failure message." },
            { value = Options.NOTIFY_RAIDWARNING, label = "Raid Warning",
              tip = "The big center-screen banner normally used for raid warnings -- hard to miss." },
        },
        function() return Options:Get("potionNotifyMode", Options.NOTIFY_CHAT) end,
        function(value) Options:Set("potionNotifyMode", value) end,
        "Chat")

    local builderBtn = Brand.MakeButton(f, "Macro Builder", f.contentWidth, 22)
    builderBtn:SetPoint("TOPLEFT", notifyDD, "BOTTOMLEFT", 0, -24)
    builderBtn:SetScript("OnClick", function()
        addonTable.MacroBuilder:Open()
    end)

    lastElement = builderBtn
    f:Hide()
    window = f
    return f
end

function Options:Open()
    local f = BuildWindow()
    f:Show()
end

-- Auto-fit height, same technique as Core.lua's main panel: reset to a
-- fixed placeholder before every measurement (otherwise repeated
-- Show/Hide cycles compound drift), then shrink to the real last
-- element's position plus a bottom buffer. Hooked onto Open() itself
-- (runs right after :Show(), so the frame is already laid out).
hooksecurefunc(Options, "Open", function()
    local f = window
    if not f or not lastElement then return end
    f:SetHeight(900)
    local desiredGap = Brand.SAFE_MARGIN * 2
    local actualGap = lastElement:GetBottom() - f:GetBottom()
    f:SetHeight(f:GetHeight() - (actualGap - desiredGap))
end)

function Options:Toggle()
    local f = BuildWindow()
    if f:IsShown() then f:Hide() else f:Show() end
end

--------------------------------------------------------------------------
-- Native AddOns list entry (Escape -> Options -> AddOns -> Xal's AutoMac)
-- -- standing rule for every addon in the family, same pattern as Armoire's
-- SettingsPanel.lua: a small canvas panel with a button that opens the
-- real standalone window, registered via Settings.RegisterCanvasLayoutCategory.
--------------------------------------------------------------------------
local function BuildCanvasPanel()
    local panel = CreateFrame("Frame")
    panel.name = "Xal's AutoMac"

    local title = Brand.FS(panel, panel.name, Brand.BODY_FONT_PATH, 22, nil,
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)

    local blurb = Brand.FS(panel,
        "Generates personalized interrupt, healing potion, DPS potion, and other utility macros for your class and spec.",
        Brand.BODY_FONT_PATH, DESC_FONT_SIZE, nil, Brand.GOLD[1], Brand.GOLD[2], Brand.GOLD[3])
    blurb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    blurb:SetPoint("RIGHT", panel, "RIGHT", -RIGHT_MARGIN, 0)
    blurb:SetJustifyH("LEFT")
    blurb:SetWordWrap(true)

    local openBtn = Brand.MakeButton(panel, "Open Xal's AutoMac Options", 220, 28, function()
        Options:Open()
    end)
    openBtn:SetPoint("TOPLEFT", blurb, "BOTTOMLEFT", 0, -20)

    return panel
end

function Options:Init()
    if self.category then return end
    local panel = BuildCanvasPanel()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        category.ID = panel.name
        Settings.RegisterAddOnCategory(category)
        self.category = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    Options:Init()
end)
