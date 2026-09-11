-- WhatsNew.lua
-- Xal's AutoMac
--
-- Shows a "what's new" splash automatically the FIRST time a player logs in
-- after the addon has been updated to a new version - never during normal,
-- unchanged play. Compares the addon's real installed version (read from the
-- .toc at runtime) against the last version this player actually saw, and
-- only pops up when they differ.
--
-- WHATS_NEW below gets updated by hand to match CHANGELOG.md every release -
-- stubbed with placeholder content until that file exists.
local addonName, addonTable = ...
addonTable.WhatsNew = {}
local W = addonTable.WhatsNew
local Brand = addonTable.BrandStyle

-- ── Update this block every release to match CHANGELOG.md ──────
W.WHATS_NEW = {
    date = "TBD",
    intro = "Placeholder - fill in once CHANGELOG.md exists for this release.",
    sections = {
        { heading = "New", items = { "Placeholder bullet - update before release." } },
    },
}

-- ── Version check ────────────────────────────────────────────
local function GetInstalledVersion()
    local v
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        v = C_AddOns.GetAddOnMetadata(addonName, "Version")
    elseif _G.GetAddOnMetadata then
        v = _G.GetAddOnMetadata(addonName, "Version")
    end
    if v == "@project-version@" then
        return "dev"
    end
    return v
end

local FW = 400
local MAX_FH = 480

local function BuildFrame(installedVersion)
    local f = CreateFrame("Frame", "XalsAutoMacWhatsNewFrame", UIParent)
    f:SetSize(FW, 300)
    f:SetPoint("CENTER", UIParent, "CENTER", -160, -100)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)

    Brand.ApplyBackground(f)
    Brand.DrawBorder(f)

    local data = W.WHATS_NEW
    Brand.Title(f, "What's New", 22, "TOP", f, "TOP", 0, -20)

    local verLine = Brand.FS(f, "Version " .. installedVersion .. (data.date and ("  ·  " .. data.date) or ""),
        Brand.BODY_FONT_PATH, 12, "", Brand.GOLD[1], Brand.GOLD[2], Brand.GOLD[3])
    verLine:SetPoint("TOP", f, "TOP", 0, -50)
    verLine:SetJustifyH("CENTER")

    Brand.DrawDivider(f, Brand.SAFE_MARGIN, 66, FW - Brand.SAFE_MARGIN * 2)

    local y = 80
    if data.intro and data.intro ~= "" then
        local intro = Brand.FS(f, data.intro, Brand.BODY_FONT_PATH, 12, "", 0.85, 0.85, 0.85)
        intro:SetPoint("TOPLEFT", f, "TOPLEFT", Brand.SAFE_MARGIN, -y)
        intro:SetWidth(FW - Brand.SAFE_MARGIN * 2)
        intro:SetJustifyH("LEFT")
        intro:SetWordWrap(true)
        y = y + (intro:GetStringHeight() or 14) + 14
    end

    for _, section in ipairs(data.sections or {}) do
        local head = Brand.FS(f, section.heading, Brand.BODY_FONT_PATH, 13, "OUTLINE",
            Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
        head:SetPoint("TOPLEFT", f, "TOPLEFT", Brand.SAFE_MARGIN, -y)
        y = y + 20

        for _, item in ipairs(section.items or {}) do
            local bullet = Brand.FS(f, "-  " .. item, Brand.BODY_FONT_PATH, 12, "",
                Brand.GOLD[1], Brand.GOLD[2], Brand.GOLD[3])
            bullet:SetPoint("TOPLEFT", f, "TOPLEFT", Brand.SAFE_MARGIN + 6, -y)
            bullet:SetWidth(FW - Brand.SAFE_MARGIN * 2 - 16)
            bullet:SetJustifyH("LEFT")
            bullet:SetWordWrap(true)
            y = y + (bullet:GetStringHeight() or 14) + 6
        end
        y = y + 10
    end

    local closeBtn = Brand.MakeButton(f, "Got it", 110, 28, function()
        f:Hide()
    end)
    closeBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 18)

    f:SetHeight(math.min(y + 56, MAX_FH))

    return f
end

-- Call this from Core.lua's ADDON_LOADED handler.
function W:CheckAndShow()
    local installed = GetInstalledVersion()
    if not installed then return end

    local db = _G["XalsAutoMacDB"]
    if not db then return end

    if db.lastSeenVersion ~= installed then
        db.lastSeenVersion = installed
        local ok, frame = pcall(BuildFrame, installed)
        if ok and frame then frame:Show() end
    end
end
