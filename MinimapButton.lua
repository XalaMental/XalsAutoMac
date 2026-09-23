-- MinimapButton.lua
-- Xal's AutoMac
--
-- The minimap launcher icon, via LibDataBroker + LibDBIcon - same
-- combination the rest of the family uses. Left-click opens the main
-- /xam panel (the addon's actual primary interface, same as the slash
-- command); right-click opens Options. Full custom-shaped icon, not
-- masked into Blizzard's standard circular border
-- (RemoveButtonBorder/RemoveButtonBackground/SetButtonIcon, LibDBIcon
-- rev 56+).

local ADDON_NAME, addonTable = ...
addonTable.MinimapButton = {}
local MB = addonTable.MinimapButton

local MINIMAP_ICON = "Interface\\AddOns\\XalsAutoMac\\Textures\\MinimapIcon_v1.png"
local MINIMAP_ICON_SIZE = 34

function MB:Register()
    local ldb = LibStub("LibDataBroker-1.1"):NewDataObject("XalsAutoMac", {
        type = "launcher",
        text = "Xal's AutoMac",
        icon = MINIMAP_ICON,
        OnClick = function(_, button)
            if button == "RightButton" then
                addonTable.Options:Open()
            else
                addonTable.ToggleMainPanel()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Xal's AutoMac")
            tooltip:AddLine("|cff999999Left-click|r to open the panel")
            tooltip:AddLine("|cff999999Right-click|r to open Options")
        end,
    })

    XalsAutoMacDB.minimap = XalsAutoMacDB.minimap or { hide = false }
    local icon = LibStub("LibDBIcon-1.0")
    icon:Register("XalsAutoMac", ldb, XalsAutoMacDB.minimap)

    if icon.SetButtonSize then
        icon:SetButtonSize("XalsAutoMac", MINIMAP_ICON_SIZE)
        icon:RemoveButtonBorder("XalsAutoMac")
        icon:RemoveButtonBackground("XalsAutoMac")
        icon:SetButtonIcon("XalsAutoMac", MINIMAP_ICON, MINIMAP_ICON_SIZE, "CENTER", 0, 0)
    end
end

-- Backing the Options checkbox - LibDBIcon's own Show/Hide API, not a
-- manual texture toggle.
function MB:SetShown(shown)
    XalsAutoMacDB.minimap = XalsAutoMacDB.minimap or { hide = false }
    XalsAutoMacDB.minimap.hide = not shown
    local icon = LibStub("LibDBIcon-1.0", true)
    if not icon then return end
    if shown then
        icon:Show("XalsAutoMac")
    else
        icon:Hide("XalsAutoMac")
    end
end

local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("PLAYER_LOGIN")
loadFrame:SetScript("OnEvent", function()
    MB:Register()
end)
