-- Jar's G13 Action Bars for WoW 12.1.5
-- Custom action bar layout for Logitech G13 gaming keypad

-- Saved variables
JarsG13BarsDB = JarsG13BarsDB or {}
JarsG13BarsCharDB = JarsG13BarsCharDB or {}

-- Libraries
local LibKeyBound = LibStub and LibStub("LibKeyBound-1.0", true)

-- Configuration
local PRIMARY_SIZE = 80      -- 100% size for 3x2 grid
local SIDE_SIZE = 52         -- 66% of primary (0.66 * 80 = 52.8 ≈ 52)
local BOTTOM_SIZE = 40       -- 50% of primary (doubled from 20)
local PADDING = 6            -- Padding between buttons
local SNAP_DISTANCE = 20     -- Distance to snap to center

-- Profile system
local MAX_LAYOUTS = 100
local currentLayoutName = nil
local activeProfile = {}

-- Focus bar profile system (independent of main G13 profiles)
local MAX_FOCUS_LAYOUTS = 100
local NUM_FOCUS_BARS = 2
local currentFocusLayoutName = { nil, nil }
local activeFocusProfile = { {}, {} }

-- Frame references
local mainFrame
local buttons = {}
local UIHider -- Hidden frame for hiding Blizzard bars
local focusRowFrame = {}
local focusRowButtons = { {}, {} }

-- queue secure stuff til combat ends
local pendingSafe = {}
local function RunWhenSafe(key, fn)
    if InCombatLockdown() then
        pendingSafe[key] = fn
    else
        pendingSafe[key] = nil
        fn()
    end
end

local function FlushSafeQueue()
    for key, fn in pairs(pendingSafe) do
        pendingSafe[key] = nil
        fn()
    end
end

-- Secure state driver for combat-safe action bar page swapping.
-- Uses WoW's restricted environment so page changes work even in combat.
local stateDriverFrame

-- possess/override/vehicle resolved in the snippet, same as Bartender4
local function GetPageDriverString()
    local pm = activeProfile.pageMap or {}
    local b5 = pm.b5 or 11
    return "[overridebar][vehicleui][possessbar][shapeshift] possess; " ..
        "[bonusbar:5] " .. (b5 == 11 and "dragon" or b5) .. "; " ..
        "[bonusbar:4] " .. (pm.b4 or 10) .. "; " ..
        "[bonusbar:3] " .. (pm.b3 or 9) .. "; " ..
        "[bonusbar:2] " .. (pm.b2 or 8) .. "; " ..
        "[bonusbar:1] " .. (pm.b1 or 7) .. "; " ..
        "[bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; 1"
end

local function SetupSecurePageDriver()
    stateDriverFrame = CreateFrame("Frame", "JG13_StateDriver", UIParent, "SecureHandlerStateTemplate")

    -- Register frame refs so the restricted snippet can access buttons 1-12
    for i = 1, 12 do
        stateDriverFrame:SetFrameRef("button" .. i, buttons[i])
    end

    -- Restricted Lua snippet executed on every state change (works in combat)
    stateDriverFrame:SetAttribute("_onstate-page", [[
        local page = newstate
        if newstate == "possess" or newstate == "dragon" then
            if HasVehicleActionBar() then
                page = GetVehicleBarIndex()
            elseif HasOverrideActionBar() then
                page = GetOverrideBarIndex()
            elseif HasTempShapeshiftActionBar() then
                page = GetTempShapeshiftBarIndex()
            elseif HasBonusActionBar() then
                page = GetBonusBarIndex()
            else
                page = 12
            end
        end
        page = tonumber(page) or 1

        for i = 1, 12 do
            local button = self:GetFrameRef("button" .. i)
            if button then
                button:SetAttribute("action", (page - 1) * 12 + i)
            end
        end
    ]])

    RegisterStateDriver(stateDriverFrame, "page", GetPageDriverString())
end

local function RefreshStateDriver()
    RunWhenSafe("driver", function()
        if not stateDriverFrame then return end
        UnregisterStateDriver(stateDriverFrame, "page")
        RegisterStateDriver(stateDriverFrame, "page", GetPageDriverString())
    end)
end

-- Create a default profile with all look/feel settings
local function CreateDefaultProfile()
    return {
        positionY = -400,
        bgOpacity = 0.3,
        showKeybinds = true,
        scale = 1.0,
        layoutMode = "G13",
        frameAlpha = 1.0,
        hideOnMouseOut = false,
        pageMap = { b1=7, b2=8, b3=9, b4=10, b5=11 },
        hideBars = {
            MainMenuBar = true,
            MainActionBar = true,
            MultiBarBottomLeft = true,
            MultiBarBottomRight = true,
            MultiBarRight = true,
            MultiBarLeft = true,
            MultiBar5 = true,
            MultiBar6 = true,
            MultiBar7 = true,
        },
    }
end

-- Deep copy a profile table
local function CopyProfile(src)
    local copy = {
        positionY = src.positionY or -400,
        bgOpacity = src.bgOpacity or 0.3,
        showKeybinds = src.showKeybinds ~= false,
        scale = src.scale or 1.0,
        layoutMode = src.layoutMode or "G13",
        frameAlpha = src.frameAlpha or 1.0,
        hideOnMouseOut = src.hideOnMouseOut or false,
        hideBars = {},
        pageMap = {},
    }
    if src.hideBars then
        for k, v in pairs(src.hideBars) do
            copy.hideBars[k] = v
        end
    end
    local defPageMap = { b1=7, b2=8, b3=9, b4=10, b5=11 }
    if src.pageMap then
        for k, v in pairs(src.pageMap) do copy.pageMap[k] = v end
    end
    for k, v in pairs(defPageMap) do
        if copy.pageMap[k] == nil then copy.pageMap[k] = v end
    end
    return copy
end

-- Get current spec ID (returns 0 if not available)
local function GetCurrentSpecID()
    local spec = C_SpecializationInfo.GetSpecialization()
    if spec then
        return C_SpecializationInfo.GetSpecializationInfo(spec) or 0
    end
    return 0
end

-- Get current spec name
local function GetCurrentSpecName()
    local spec = C_SpecializationInfo.GetSpecialization()
    if spec then
        local _, name = C_SpecializationInfo.GetSpecializationInfo(spec)
        return name or "Unknown"
    end
    return "Unknown"
end

-- Forward declarations for profile UI refresh
local RefreshConfigUI
local RefreshFocusConfigUI = {}

-- Count saved layouts
local function CountLayouts()
    local count = 0
    for _ in pairs(JarsG13BarsDB.layouts) do
        count = count + 1
    end
    return count
end

-- Get sorted layout names
local function GetSortedLayoutNames()
    local names = {}
    for name in pairs(JarsG13BarsDB.layouts) do
        tinsert(names, name)
    end
    table.sort(names)
    return names
end

-- Apply the active profile to the live UI
local ApplyG13Layout     -- forward declaration (defined below)
local ApplyKeyzenLayout  -- forward declaration (defined below)
local HideDefaultBars    -- forward declaration (defined below)

local function ApplyLayoutMode()
    RunWhenSafe("layout", function()
        if not mainFrame then return end
        if activeProfile.layoutMode == "Keyzen" then
            ApplyKeyzenLayout(mainFrame)
        else
            ApplyG13Layout(mainFrame)
        end
    end)
end

-- fade check, throttled so its not every frame
local function MouseOutOnUpdate(self, elapsed)
    self.fadeElapsed = (self.fadeElapsed or 0) + elapsed
    if self.fadeElapsed < 0.1 then return end
    self.fadeElapsed = 0
    if self:IsMouseOver() then
        self:SetAlpha(activeProfile.frameAlpha or 1.0)
    else
        self:SetAlpha(0)
    end
end

local function SetMouseOutFade(frame)
    if activeProfile.hideOnMouseOut then
        frame:SetAlpha(0)
        frame:SetScript("OnUpdate", MouseOutOnUpdate)
    else
        frame:SetAlpha(activeProfile.frameAlpha or 1.0)
        frame:SetScript("OnUpdate", nil)
    end
end

local function ApplyActiveProfile()
    if not mainFrame then return end

    -- Background opacity
    if mainFrame.bg then
        mainFrame.bg:SetColorTexture(0, 0, 0, activeProfile.bgOpacity or 0.3)
    end

    -- Frame alpha + hide on mouse out
    SetMouseOutFade(mainFrame)

    RunWhenSafe("profile", function()
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("TOP", UIParent, "TOP", 0, activeProfile.positionY or -400)
        mainFrame:SetScale(activeProfile.scale or 1.0)
    end)

    ApplyLayoutMode()
    RefreshStateDriver()
end

-- Persist the current in-memory profile back to SavedVariables
local function PersistActiveProfile()
    if currentLayoutName and JarsG13BarsDB.layouts[currentLayoutName] then
        JarsG13BarsDB.layouts[currentLayoutName] = CopyProfile(activeProfile)
    else
        -- no named layout, keep it as the unnamed current one
        JarsG13BarsDB.currentProfile = CopyProfile(activeProfile)
    end
end

-- Save current active profile as a named layout
local function SaveLayout(name)
    if not name or name == "" then
        print("|cff00ff00Jar's G13 Bars|r: Please enter a layout name.")
        return false
    end

    if CountLayouts() >= MAX_LAYOUTS and not JarsG13BarsDB.layouts[name] then
        print("|cff00ff00Jar's G13 Bars|r: Maximum " .. MAX_LAYOUTS .. " layouts reached.")
        return false
    end

    JarsG13BarsDB.layouts[name] = CopyProfile(activeProfile)
    currentLayoutName = name
    JarsG13BarsDB.lastActiveLayout = name

    local specID = GetCurrentSpecID()
    if specID and specID > 0 then
        JarsG13BarsDB.specAssociations[specID] = name
    end

    print("|cff00ff00Jar's G13 Bars|r: Layout '" .. name .. "' saved" ..
        (specID and specID > 0 and (" for " .. GetCurrentSpecName()) or "") .. ".")
    if RefreshConfigUI then RefreshConfigUI() end
    return true
end

-- Load a named layout into activeProfile
local function LoadLayout(name)
    if not name or not JarsG13BarsDB.layouts[name] then
        print("|cff00ff00Jar's G13 Bars|r: Layout '" .. (name or "nil") .. "' not found.")
        return false
    end

    activeProfile = CopyProfile(JarsG13BarsDB.layouts[name])
    currentLayoutName = name
    JarsG13BarsDB.lastActiveLayout = name

    local specID = GetCurrentSpecID()
    if specID and specID > 0 then
        JarsG13BarsDB.specAssociations[specID] = name
    end

    print("|cff00ff00Jar's G13 Bars|r: Layout '" .. name .. "' loaded" ..
        (specID and specID > 0 and (" for " .. GetCurrentSpecName()) or "") .. ".")
    ApplyActiveProfile()
    HideDefaultBars()
    if RefreshConfigUI then RefreshConfigUI() end
    return true
end

-- Load the layout associated with the current spec
local function LoadSpecLayout()
    local specID = GetCurrentSpecID()
    if specID and specID > 0 then
        local layoutName = JarsG13BarsDB.specAssociations[specID]
        if layoutName and JarsG13BarsDB.layouts[layoutName] then
            activeProfile = CopyProfile(JarsG13BarsDB.layouts[layoutName])
            currentLayoutName = layoutName
            print("|cff00ff00Jar's G13 Bars|r: Loaded layout '" .. layoutName .. "' for " .. GetCurrentSpecName() .. ".")
            return
        end
    end

    -- No spec association found - try to restore last active layout
    local lastLayout = JarsG13BarsDB.lastActiveLayout
    if lastLayout and JarsG13BarsDB.layouts[lastLayout] then
        activeProfile = CopyProfile(JarsG13BarsDB.layouts[lastLayout])
        currentLayoutName = lastLayout
        print("|cff00ff00Jar's G13 Bars|r: Restored layout '" .. lastLayout .. "'.")
        return
    end

    -- No layout found - use the unnamed one or defaults
    if JarsG13BarsDB.currentProfile then
        activeProfile = CopyProfile(JarsG13BarsDB.currentProfile)
    else
        activeProfile = CreateDefaultProfile()
    end
    currentLayoutName = nil
end

-- Delete a named layout
local function DeleteLayout(name)
    if not name or not JarsG13BarsDB.layouts[name] then
        return false
    end

    JarsG13BarsDB.layouts[name] = nil

    for specID, layoutName in pairs(JarsG13BarsDB.specAssociations) do
        if layoutName == name then
            JarsG13BarsDB.specAssociations[specID] = nil
        end
    end

    if currentLayoutName == name then
        currentLayoutName = nil
    end

    if JarsG13BarsDB.lastActiveLayout == name then
        JarsG13BarsDB.lastActiveLayout = nil
    end

    print("|cff00ff00Jar's G13 Bars|r: Layout '" .. name .. "' deleted.")
    if RefreshConfigUI then RefreshConfigUI() end
    return true
end

-- ============================================================
-- FOCUS BAR PROFILE SYSTEM (independent of main G13 profiles)
-- ============================================================

local function CreateDefaultFocusProfile()
    return {
        enabled = false,
        slots = {},
        buttonSize = 40,
        padding = 4,
        posX = 0,
        posY = -200,
        bgOpacity = 0.3,
        locked = true,
        nonInteractive = false,
        combatOnly = false,
        orientation = "horizontal",
    }
end

local function CopyFocusProfile(src)
    local copy = {
        enabled = src.enabled or false,
        buttonSize = src.buttonSize or 40,
        padding = src.padding or 4,
        posX = src.posX or 0,
        posY = src.posY or -200,
        bgOpacity = src.bgOpacity or 0.3,
        locked = src.locked ~= false,
        nonInteractive = src.nonInteractive or false,
        combatOnly = src.combatOnly or false,
        orientation = src.orientation or "horizontal",
        slots = {},
    }
    if src.slots then
        for _, s in ipairs(src.slots) do
            table.insert(copy.slots, s)
        end
    end
    return copy
end

local function GetFocusDBTables(barIndex)
    if barIndex == 2 then
        return JarsG13BarsCharDB.focus2Layouts,
               JarsG13BarsCharDB.focus2SpecAssociations,
               "focus2LastActiveLayout",
               "focus2CurrentProfile"
    end
    return JarsG13BarsCharDB.focusLayouts,
           JarsG13BarsCharDB.focusSpecAssociations,
           "focusLastActiveLayout",
           "focusCurrentProfile"
end

local function CountFocusLayouts(barIndex)
    local layouts = GetFocusDBTables(barIndex)
    local count = 0
    for _ in pairs(layouts) do
        count = count + 1
    end
    return count
end

local function GetSortedFocusLayoutNames(barIndex)
    local layouts = GetFocusDBTables(barIndex)
    local names = {}
    for name in pairs(layouts) do
        tinsert(names, name)
    end
    table.sort(names)
    return names
end

local function PersistActiveFocusProfile(barIndex)
    local layouts, _, _, currentKey = GetFocusDBTables(barIndex)
    local name = currentFocusLayoutName[barIndex]
    if name and layouts[name] then
        layouts[name] = CopyFocusProfile(activeFocusProfile[barIndex])
    else
        JarsG13BarsCharDB[currentKey] = CopyFocusProfile(activeFocusProfile[barIndex])
    end
end

-- Forward declare BuildFocusRow (defined later)
local BuildFocusRow

local function SaveFocusLayout(barIndex, name)
    if not name or name == "" then
        print("|cff00ff00Jar's G13 Bars|r: Please enter a focus layout name.")
        return false
    end
    local layouts, specAssoc, lastActiveKey = GetFocusDBTables(barIndex)
    if CountFocusLayouts(barIndex) >= MAX_FOCUS_LAYOUTS and not layouts[name] then
        print("|cff00ff00Jar's G13 Bars|r: Maximum " .. MAX_FOCUS_LAYOUTS .. " focus layouts reached.")
        return false
    end

    layouts[name] = CopyFocusProfile(activeFocusProfile[barIndex])
    currentFocusLayoutName[barIndex] = name
    JarsG13BarsCharDB[lastActiveKey] = name

    local specID = GetCurrentSpecID()
    if specID and specID > 0 then
        specAssoc[specID] = name
    end

    print("|cff00ff00Jar's G13 Bars|r: Focus " .. barIndex .. " layout '" .. name .. "' saved" ..
        (specID and specID > 0 and (" for " .. GetCurrentSpecName()) or "") .. ".")
    if RefreshFocusConfigUI[barIndex] then RefreshFocusConfigUI[barIndex]() end
    return true
end

local function LoadFocusLayout(barIndex, name)
    local layouts, specAssoc, lastActiveKey = GetFocusDBTables(barIndex)
    if not name or not layouts[name] then
        print("|cff00ff00Jar's G13 Bars|r: Focus " .. barIndex .. " layout '" .. (name or "nil") .. "' not found.")
        return false
    end

    activeFocusProfile[barIndex] = CopyFocusProfile(layouts[name])
    currentFocusLayoutName[barIndex] = name
    JarsG13BarsCharDB[lastActiveKey] = name

    local specID = GetCurrentSpecID()
    if specID and specID > 0 then
        specAssoc[specID] = name
    end

    print("|cff00ff00Jar's G13 Bars|r: Focus " .. barIndex .. " layout '" .. name .. "' loaded" ..
        (specID and specID > 0 and (" for " .. GetCurrentSpecName()) or "") .. ".")
    if BuildFocusRow then BuildFocusRow(barIndex) end
    if RefreshFocusConfigUI[barIndex] then RefreshFocusConfigUI[barIndex](true) end
    return true
end

local function LoadFocusSpecLayout(barIndex)
    local layouts, specAssoc, lastActiveKey, currentKey = GetFocusDBTables(barIndex)
    local specID = GetCurrentSpecID()
    if specID and specID > 0 then
        local layoutName = specAssoc[specID]
        if layoutName and layouts[layoutName] then
            activeFocusProfile[barIndex] = CopyFocusProfile(layouts[layoutName])
            currentFocusLayoutName[barIndex] = layoutName
            print("|cff00ff00Jar's G13 Bars|r: Loaded focus " .. barIndex .. " layout '" .. layoutName .. "' for " .. GetCurrentSpecName() .. ".")
            return
        end
    end

    local lastLayout = JarsG13BarsCharDB[lastActiveKey]
    if lastLayout and layouts[lastLayout] then
        activeFocusProfile[barIndex] = CopyFocusProfile(layouts[lastLayout])
        currentFocusLayoutName[barIndex] = lastLayout
        return
    end

    if JarsG13BarsCharDB[currentKey] then
        activeFocusProfile[barIndex] = CopyFocusProfile(JarsG13BarsCharDB[currentKey])
    else
        activeFocusProfile[barIndex] = CreateDefaultFocusProfile()
    end
    currentFocusLayoutName[barIndex] = nil
end

local function DeleteFocusLayout(barIndex, name)
    local layouts, specAssoc, lastActiveKey = GetFocusDBTables(barIndex)
    if not name or not layouts[name] then
        return false
    end

    layouts[name] = nil

    for specID, layoutName in pairs(specAssoc) do
        if layoutName == name then
            specAssoc[specID] = nil
        end
    end

    if currentFocusLayoutName[barIndex] == name then
        currentFocusLayoutName[barIndex] = nil
    end
    if JarsG13BarsCharDB[lastActiveKey] == name then
        JarsG13BarsCharDB[lastActiveKey] = nil
    end

    print("|cff00ff00Jar's G13 Bars|r: Focus " .. barIndex .. " layout '" .. name .. "' deleted.")
    if RefreshFocusConfigUI[barIndex] then RefreshFocusConfigUI[barIndex]() end
    return true
end

-- Initialize saved variables (migrate from flat to profile-based structure)
local function InitDB()
    if not JarsG13BarsDB then
        JarsG13BarsDB = {}
    end

    -- Initialize profile tables
    if not JarsG13BarsDB.layouts then
        JarsG13BarsDB.layouts = {}
    end
    if not JarsG13BarsDB.specAssociations then
        JarsG13BarsDB.specAssociations = {}
    end
    if not JarsG13BarsDB.lastActiveLayout then
        JarsG13BarsDB.lastActiveLayout = nil
    end

    -- Initialize focus bar profile tables
    if not JarsG13BarsCharDB.focusLayouts then
        JarsG13BarsCharDB.focusLayouts = {}
    end
    if not JarsG13BarsCharDB.focusSpecAssociations then
        JarsG13BarsCharDB.focusSpecAssociations = {}
    end
    -- Focus bar 2
    if not JarsG13BarsCharDB.focus2Layouts then
        JarsG13BarsCharDB.focus2Layouts = {}
    end
    if not JarsG13BarsCharDB.focus2SpecAssociations then
        JarsG13BarsCharDB.focus2SpecAssociations = {}
    end

    -- Initialize per-character focus row data (legacy, kept for migration)
    if not JarsG13BarsCharDB.focusRows then
        JarsG13BarsCharDB.focusRows = {}
    end

    -- Migrate old per-char focus row configs to the new focus profile system
    if JarsG13BarsCharDB.focusRows then
        local migrated = false
        for specID, cfg in pairs(JarsG13BarsCharDB.focusRows) do
            if type(cfg) == "table" and not JarsG13BarsCharDB.focusLayouts["Default"] then
                JarsG13BarsCharDB.focusLayouts["Default"] = {
                    enabled = cfg.enabled or false,
                    slots = {},
                    buttonSize = cfg.buttonSize or 40,
                    padding = cfg.padding or 4,
                    posX = cfg.posX or 0,
                    posY = cfg.posY or -200,
                    bgOpacity = cfg.bgOpacity or 0.3,
                    locked = cfg.locked ~= false,
                    nonInteractive = cfg.nonInteractive or false,
                    combatOnly = cfg.combatOnly or false,
                }
                if cfg.slots then
                    for _, s in ipairs(cfg.slots) do
                        table.insert(JarsG13BarsCharDB.focusLayouts["Default"].slots, s)
                    end
                end
                JarsG13BarsCharDB.focusSpecAssociations[specID] = "Default"
                migrated = true
            end
        end
        if migrated then
            JarsG13BarsCharDB.focusRows = {}
            print("|cff00ff00Jar's G13 Bars|r: Focus bar settings migrated to profile 'Default'.")
        end
    end

    -- Migrate from old flat structure to profile-based
    if JarsG13BarsDB.position or JarsG13BarsDB.bgOpacity or JarsG13BarsDB.scale then
        local migrated = CreateDefaultProfile()

        if JarsG13BarsDB.position and JarsG13BarsDB.position.y then
            migrated.positionY = JarsG13BarsDB.position.y
        end
        if JarsG13BarsDB.bgOpacity then migrated.bgOpacity = JarsG13BarsDB.bgOpacity end
        if JarsG13BarsDB.showKeybinds ~= nil then migrated.showKeybinds = JarsG13BarsDB.showKeybinds end
        if JarsG13BarsDB.scale then migrated.scale = JarsG13BarsDB.scale end
        if JarsG13BarsDB.layoutMode then migrated.layoutMode = JarsG13BarsDB.layoutMode end
        if JarsG13BarsDB.frameAlpha then migrated.frameAlpha = JarsG13BarsDB.frameAlpha end
        if JarsG13BarsDB.hideOnMouseOut ~= nil then migrated.hideOnMouseOut = JarsG13BarsDB.hideOnMouseOut end
        if JarsG13BarsDB.hideBars then
            migrated.hideBars = {}
            for k, v in pairs(JarsG13BarsDB.hideBars) do
                migrated.hideBars[k] = v
            end
        end

        -- Save as "Default" layout
        JarsG13BarsDB.layouts["Default"] = migrated

        -- Clean up old flat keys
        JarsG13BarsDB.position = nil
        JarsG13BarsDB.bgOpacity = nil
        JarsG13BarsDB.showKeybinds = nil
        JarsG13BarsDB.scale = nil
        JarsG13BarsDB.layoutMode = nil
        JarsG13BarsDB.frameAlpha = nil
        JarsG13BarsDB.hideOnMouseOut = nil
        JarsG13BarsDB.hideBars = nil

        print("|cff00ff00Jar's G13 Bars|r: Settings migrated to layout 'Default'.")
    end
end

-- Hide default action bars, Bartender4 HideBlizzard style. only once
local hiddenParts = {}

-- clear a key w/o leaving taint on it
local function PurgeKey(t, k)
    t[k] = nil
    local c = 42
    repeat
        if t[c] == nil then
            t[c] = nil
        end
        c = c + 1
    until issecurevariable(t, k)
end

local function HideActionBarFrame(frame, clearEvents)
    if not frame then return end
    if clearEvents then
        frame:UnregisterAllEvents()
    end
    -- EditMode bits
    if frame.system then
        PurgeKey(frame, "isShownExternal")
    end
    if frame.HideBase then
        frame:HideBase()
    else
        frame:Hide()
    end
    frame:SetParent(UIHider)
end

local function HideActionButton(button)
    if not button then return end
    button:Hide()
    button:UnregisterAllEvents()
    button:SetAttribute("statehidden", true)
    button.bar = nil
end

HideDefaultBars = function()
    RunWhenSafe("hidebars", function()
        if not UIHider then
            UIHider = CreateFrame("Frame")
            UIHider:Hide()
        end

        -- Bar 2 (slots 61-72) always goes, JG13 buttons 13-24 replace it
        if not hiddenParts.bar2 then
            HideActionBarFrame(MultiBarBottomLeft, true)
            for i = 1, 12 do
                HideActionButton(_G["MultiBarBottomLeftButton" .. i])
            end
            hiddenParts.bar2 = true
        end

        if activeProfile.hideBars and activeProfile.hideBars.MainActionBar then
            if not hiddenParts.main then
                HideActionBarFrame(MainMenuBar, false)   -- <= 11.2.5
                HideActionBarFrame(MainActionBar, false) -- >= 12.0
                for i = 1, 12 do
                    HideActionButton(_G["ActionButton" .. i])
                end
                if MainMenuBar then
                    MainMenuBar:UnregisterEvent("PLAYER_REGEN_ENABLED")
                    MainMenuBar:UnregisterEvent("PLAYER_REGEN_DISABLED")
                    MainMenuBar:UnregisterEvent("ACTIONBAR_SHOWGRID")
                    MainMenuBar:UnregisterEvent("ACTIONBAR_HIDEGRID")
                end
                hiddenParts.main = true
            end
        elseif hiddenParts.main and not hiddenParts.warned then
            -- cant un-hide cleanly, needs a reload
            print("|cff00ff00Jar's G13 Bars|r: Blizzard main bar comes back after a /reload.")
            hiddenParts.warned = true
        end
    end)
end

-- one binding command per button: ACTIONBUTTONn for 1-12, MULTIACTIONBAR1BUTTONn for 13-24
local function GetButtonBindCommand(index)
    if index <= 12 then
        return "ACTIONBUTTON" .. index
    end
    return "MULTIACTIONBAR1BUTTON" .. (index - 12)
end

local function UpdateButtonHotkey(button)
    if not button.HotKey or not button.bindCommand then return end
    local key = activeProfile.showKeybinds and GetBindingKey(button.bindCommand)
    local text = key and GetBindingText(key, 1) or ""
    if text ~= "" and text:byte() > 31 then
        button.HotKey:SetText(text)
        button.HotKey:Show()
    else
        button.HotKey:SetText("")
        button.HotKey:Hide()
    end
end

-- Function to update keybind visibility
local function UpdateKeybinds()
    for i = 1, 24 do
        if buttons[i] then UpdateButtonHotkey(buttons[i]) end
    end
end

-- old versions bound 13-24 as CLICK bindings, move those over
local function MigrateClickBindings()
    local changed = false
    for i = 13, 24 do
        for _, mouse in ipairs({ "LeftButton", "Keybind" }) do
            local click = "CLICK JG13_Button" .. i .. ":" .. mouse
            local key = GetBindingKey(click)
            while key do
                SetBinding(key, GetButtonBindCommand(i))
                changed = true
                key = GetBindingKey(click)
            end
        end
    end
    if changed then
        SaveBindings(GetCurrentBindingSet())
    end
end

-- Function to setup override bindings
local inReassignBindings = false
local function UpdateOverrideBindings()
    if not mainFrame then return end
    RunWhenSafe("bindings", function()
        if inReassignBindings then return end
        inReassignBindings = true

        MigrateClickBindings()
        ClearOverrideBindings(mainFrame)
        for i = 1, 24 do
            local button = buttons[i]
            local command = GetButtonBindCommand(i)
            for k = 1, select("#", GetBindingKey(command)) do
                local key = select(k, GetBindingKey(command))
                if key and key ~= "" then
                    -- Use "Keybind" as the mouse button for keybind clicks
                    SetOverrideBindingClick(mainFrame, false, key, button:GetName(), "Keybind")
                end
            end
        end

        inReassignBindings = false
    end)
end

-- Create a single action button
local function CreateActionButton(parent, index, size)
    local button = CreateFrame("CheckButton", "JG13_Button" .. index, parent, "ActionBarButtonTemplate")
    button:SetSize(size, size)
    button.baseAction = index  -- Store the base action for reference
    button.bindCommand = GetButtonBindCommand(index)

    -- Setup action button
    button:SetAttribute("type", "action")
    button:RegisterForClicks("AnyUp")

    if index <= 12 then
        -- Buttons 1-12: Mirror Blizzard's main action bar (ActionButton1-12)
        -- The hook will sync these to match Blizzard's dynamic paging
        button:SetAttribute("action", index)
    else
        -- Buttons 13-24: Mirror ActionBar 2 (MultiBarBottomLeft, slots 61-72)
        -- local multiBarAction = 72 + (index - 12)
        local multiBarAction = 60 + (index - 12)
        button:SetAttribute("action", multiBarAction)
    end
    button:SetAttribute("commandName", button.bindCommand)

    -- blizz UpdateHotkeys looks up ACTIONBUTTON<id>, put our label back after it
    if button.UpdateHotkeys then
        hooksecurefunc(button, "UpdateHotkeys", UpdateButtonHotkey)
    end
    
    -- Ensure the button's hit rectangle matches its size
    button:SetHitRectInsets(0, 0, 0, 0)
    
    -- Hide all background/border elements and resize borders that show
    if button.Border then 
        button.Border:ClearAllPoints()
        button.Border:SetAllPoints(button)
    end
    if button.IconBorder then
        button.IconBorder:ClearAllPoints()
        button.IconBorder:SetAllPoints(button)
    end
    if button.NormalTexture then 
        button.NormalTexture:ClearAllPoints()
        button.NormalTexture:SetAllPoints(button)
        button.NormalTexture:SetTexCoord(0, 1, 0, 1)
        -- Make it fully transparent but keep it to define the button boundary
        button.NormalTexture:SetVertexColor(1, 1, 1, 0)
    end
    if button.FloatingBG then button.FloatingBG:Hide() end
    if button.SlotArt then button.SlotArt:Hide() end
    if button.SlotBackground then button.SlotBackground:Hide() end
    if button.IconMask then button.IconMask:Hide() end
    if button.Flash then
        button.Flash:ClearAllPoints()
        button.Flash:SetAllPoints(button)
    end
    if button.NewActionTexture then
        button.NewActionTexture:ClearAllPoints()
        button.NewActionTexture:SetAllPoints(button)
    end
    if button.SpellHighlightTexture then
        button.SpellHighlightTexture:ClearAllPoints()
        button.SpellHighlightTexture:SetAllPoints(button)
    end
    if button.CheckedTexture then
        button.CheckedTexture:ClearAllPoints()
        button.CheckedTexture:SetAllPoints(button)
    end
    
    -- Set highlight texture to cover entire button
    local highlight = button:GetHighlightTexture()
    if highlight then
        highlight:ClearAllPoints()
        highlight:SetAllPoints(button)
        highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        highlight:SetTexCoord(0, 1, 0, 1)
        highlight:SetBlendMode("ADD")
    end
    
    -- Set pushed texture to cover entire button - create custom one
    button:SetPushedTexture("Interface\\Buttons\\WHITE8X8")
    local pushed = button:GetPushedTexture()
    if pushed then
        pushed:ClearAllPoints()
        pushed:SetAllPoints(button)
        pushed:SetVertexColor(0, 0, 0, 0.5)  -- Semi-transparent black overlay
        pushed:SetDrawLayer("OVERLAY", 1)
    end
    
    -- Icon - fill entire button with no insets
    if button.icon then
        button.icon:SetTexCoord(0, 1, 0, 1)
        button.icon:ClearAllPoints()
        button.icon:SetAllPoints(button)
        button.icon:SetDrawLayer("BACKGROUND", 0)
    end
    
    -- Cooldown - fill entire button
    if not button.cooldown then
        button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    end
    button.cooldown:ClearAllPoints()
    button.cooldown:SetAllPoints(button)
    button.cooldown:SetDrawEdge(false)
    
    -- Count text - MASSIVE and center-justified
    if button.Count then
        button.Count:ClearAllPoints()
        button.Count:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.Count:SetJustifyH("CENTER")
        button.Count:SetJustifyV("MIDDLE")
        button.Count:SetWordWrap(false)
        button.Count:SetWidth(0)  -- No width restriction
        button.Count:SetHeight(0) -- No height restriction
        local fontFace, _, fontFlags = button.Count:GetFont()
        -- Use default font if current font is not available
        if not fontFace or fontFace == "" then
            fontFace = "Fonts\\FRIZQT__.TTF"
            fontFlags = "OUTLINE"
        end
        button.Count:SetFont(fontFace, math.max(24, size * 0.7), fontFlags or "OUTLINE")
    end
    
    -- Hotkey text - Keep small
    if button.HotKey then
        local fontFace, _, fontFlags = button.HotKey:GetFont()
        -- Use default font if current font is not available
        if not fontFace or fontFace == "" then
            fontFace = "Fonts\\FRIZQT__.TTF"
            fontFlags = "OUTLINE"
        end
        button.HotKey:SetFont(fontFace, math.max(8, size * 0.2), fontFlags)
    end
    
    -- Name text (macro/spell name)
    if button.Name then
        local fontFace, _, fontFlags = button.Name:GetFont()
        if not fontFace or fontFace == "" then
            fontFace = "Fonts\\FRIZQT__.TTF"
            fontFlags = "OUTLINE"
        end
        button.Name:SetFont(fontFace, math.max(8, size * 0.15), fontFlags)
    end
    
    -- LibKeyBound support for keybinding
    button.GetBindingAction = function(self)
        return self.bindCommand
    end

    button.GetHotkey = function(self)
        local key = GetBindingKey(self.bindCommand)
        if key then
            return GetBindingText(key, 1)
        end
        return ""
    end
    
    button.GetActionName = function(self)
        if self.baseAction and self.baseAction <= 12 then
            return "Action Button " .. self.baseAction
        elseif self.baseAction and self.baseAction <= 24 then
            return "Bar 2 Button " .. (self.baseAction - 12)
        end
        return "Button " .. (self.baseAction or "?")
    end
    
    button.SetKey = function(self, key)
        local action = self:GetBindingAction()
        if action then
            local result = SetBinding(key, action)
            if result then
                UpdateKeybinds()
                C_Timer.After(0, UpdateOverrideBindings)
            end
            return result
        end
        return false
    end
    
    button.GetBindings = function(self)
        local bindings = {}
        local action = self:GetBindingAction()
        if action then
            for i = 1, select("#", GetBindingKey(action)) do
                local key = select(i, GetBindingKey(action))
                if key and key ~= "" then
                    tinsert(bindings, key)
                end
            end
        end
        return unpack(bindings)
    end
    
    button.ClearBindings = function(self)
        local action = self:GetBindingAction()
        if action then
            while GetBindingKey(action) do
                SetBinding(GetBindingKey(action), nil)
            end
            UpdateKeybinds()
        end
    end
    
    -- Hook OnEnter for LibKeyBound
    button:HookScript("OnEnter", function(self)
        if LibKeyBound and LibKeyBound:IsShown() then
            LibKeyBound:Set(self)
        end
    end)
    
    return button
end

--------------------------------------------------------------------------------
-- Focus Row System
--------------------------------------------------------------------------------

local function GetFocusRowConfig(barIndex)
    return activeFocusProfile[barIndex]
end

local function GetOrCreateFocusRowConfig(barIndex)
    if not activeFocusProfile[barIndex] or not activeFocusProfile[barIndex].slots then
        activeFocusProfile[barIndex] = CreateDefaultFocusProfile()
    end
    return activeFocusProfile[barIndex]
end

local focusBtnCounter = 0
local focusBtnPool = {}  -- recycled focus button frames
local focusRebuildTimer = { nil, nil }  -- debounce handle for BuildFocusRow per bar

-- One-time visual setup for a freshly created focus button
local function InitFocusButtonVisuals(btn)
    if btn.Border then btn.Border:ClearAllPoints(); btn.Border:SetAllPoints(btn) end
    if btn.IconBorder then btn.IconBorder:ClearAllPoints(); btn.IconBorder:SetAllPoints(btn) end
    if btn.NormalTexture then
        btn.NormalTexture:ClearAllPoints()
        btn.NormalTexture:SetAllPoints(btn)
        btn.NormalTexture:SetTexCoord(0, 1, 0, 1)
        btn.NormalTexture:SetVertexColor(1, 1, 1, 0)
    end
    if btn.FloatingBG then btn.FloatingBG:Hide() end
    if btn.SlotArt then btn.SlotArt:Hide() end
    if btn.SlotBackground then btn.SlotBackground:Hide() end
    if btn.IconMask then btn.IconMask:Hide() end
    if btn.Flash then btn.Flash:ClearAllPoints(); btn.Flash:SetAllPoints(btn) end
    if btn.NewActionTexture then btn.NewActionTexture:ClearAllPoints(); btn.NewActionTexture:SetAllPoints(btn) end
    if btn.SpellHighlightTexture then btn.SpellHighlightTexture:ClearAllPoints(); btn.SpellHighlightTexture:SetAllPoints(btn) end
    if btn.CheckedTexture then btn.CheckedTexture:ClearAllPoints(); btn.CheckedTexture:SetAllPoints(btn) end

    local highlight = btn:GetHighlightTexture()
    if highlight then
        highlight:ClearAllPoints()
        highlight:SetAllPoints(btn)
        highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        highlight:SetTexCoord(0, 1, 0, 1)
        highlight:SetBlendMode("ADD")
    end

    btn:SetPushedTexture("Interface\\Buttons\\WHITE8X8")
    local pushed = btn:GetPushedTexture()
    if pushed then
        pushed:ClearAllPoints()
        pushed:SetAllPoints(btn)
        pushed:SetVertexColor(0, 0, 0, 0.5)
        pushed:SetDrawLayer("OVERLAY", 1)
    end

    if btn.icon then
        btn.icon:SetTexCoord(0, 1, 0, 1)
        btn.icon:ClearAllPoints()
        btn.icon:SetAllPoints(btn)
        btn.icon:SetDrawLayer("BACKGROUND", 0)
    end

    if not btn.cooldown then
        btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    end
    btn.cooldown:ClearAllPoints()
    btn.cooldown:SetAllPoints(btn)
    btn.cooldown:SetDrawEdge(false)
end

-- Recycle a button back into the pool
local focusPoolParent = CreateFrame("Frame")
focusPoolParent:Hide()

local function ReleaseFocusButton(btn)
    btn:Hide()
    -- btn:UnregisterAllEvents()
    -- btn:SetParent(nil)
    btn:SetParent(focusPoolParent)
    btn:ClearAllPoints()
    btn:EnableMouse(true)
    table.insert(focusBtnPool, btn)
end

-- Get a focus button from the pool or create a new one
local function AcquireFocusButton(parent, slotID, size)
    local btn = table.remove(focusBtnPool)
    if not btn then
        -- No pooled button available — create a new one
        focusBtnCounter = focusBtnCounter + 1
        btn = CreateFrame("CheckButton", "JG13_FocusBtn" .. focusBtnCounter, parent, "ActionBarButtonTemplate")
        btn:RegisterForClicks("AnyUp")
        btn:SetHitRectInsets(0, 0, 0, 0)
        InitFocusButtonVisuals(btn)
    else
        -- Recycled — re-parent and re-register events
        btn:SetParent(parent)
    end

    btn:SetSize(size, size)
    btn:SetAttribute("type", "action")
    btn:SetAttribute("action", slotID)

    -- Scale fonts to current size
    if btn.Count then
        btn.Count:ClearAllPoints()
        btn.Count:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.Count:SetJustifyH("CENTER")
        btn.Count:SetJustifyV("MIDDLE")
        btn.Count:SetWordWrap(false)
        btn.Count:SetWidth(0)
        btn.Count:SetHeight(0)
        local fontFace, _, fontFlags = btn.Count:GetFont()
        if not fontFace or fontFace == "" then
            fontFace = "Fonts\\FRIZQT__.TTF"
            fontFlags = "OUTLINE"
        end
        btn.Count:SetFont(fontFace, math.max(24, size * 0.7), fontFlags or "OUTLINE")
    end

    if btn.HotKey then
        local fontFace, _, fontFlags = btn.HotKey:GetFont()
        if not fontFace or fontFace == "" then
            fontFace = "Fonts\\FRIZQT__.TTF"
            fontFlags = "OUTLINE"
        end
        btn.HotKey:SetFont(fontFace, math.max(8, size * 0.2), fontFlags)
    end

    if btn.Name then
        local fontFace, _, fontFlags = btn.Name:GetFont()
        if not fontFace or fontFace == "" then
            fontFace = "Fonts\\FRIZQT__.TTF"
            fontFlags = "OUTLINE"
        end
        btn.Name:SetFont(fontFace, math.max(8, size * 0.15), fontFlags)
    end

    btn:Show()
    return btn
end

-- focus row frame is built once per bar and reused
local function GetFocusRowFrame(barIndex)
    if focusRowFrame[barIndex] then return focusRowFrame[barIndex] end

    local f = CreateFrame("Frame", "JG13_FocusRow" .. barIndex, UIParent)
    focusRowFrame[barIndex] = f
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not activeFocusProfile[barIndex].locked and not InCombatLockdown() then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local _, _, _, x, y = self:GetPoint(1)
        activeFocusProfile[barIndex].posX = x
        activeFocusProfile[barIndex].posY = y
        PersistActiveFocusProfile(barIndex)
        self.UpdateCoordLabel()
    end)

    -- Background
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()

    -- Unlock border indicator
    local unlockBorder = f:CreateTexture(nil, "OVERLAY", nil, 7)
    unlockBorder:SetPoint("TOPLEFT", -2, 2)
    unlockBorder:SetPoint("BOTTOMRIGHT", 2, -2)
    unlockBorder:SetColorTexture(0, 1, 0, 0.3)
    f.unlockBorder = unlockBorder

    -- Nudge buttons + coords, only shown when unlocked
    local coordLabel = f:CreateFontString(nil, "OVERLAY")
    coordLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    coordLabel:SetTextColor(0, 1, 0)
    coordLabel:SetPoint("TOP", f, "BOTTOM", 0, -2)
    f.coordLabel = coordLabel
    f.UpdateCoordLabel = function()
        coordLabel:SetText(string.format("%.0f, %.0f", activeFocusProfile[barIndex].posX or 0, activeFocusProfile[barIndex].posY or 0))
    end

    local function MakeNudgeBtn(label, dx, dy, anchorPoint, relPoint, offX, offY)
        local nb = CreateFrame("Button", nil, f)
        nb:SetSize(16, 16)
        nb:SetPoint(anchorPoint, f, relPoint, offX, offY)
        local nbt = nb:CreateFontString(nil, "OVERLAY")
        nbt:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        nbt:SetTextColor(0, 1, 0)
        nbt:SetPoint("CENTER")
        nbt:SetText(label)
        nb:SetScript("OnClick", function()
            activeFocusProfile[barIndex].posX = (activeFocusProfile[barIndex].posX or 0) + dx
            activeFocusProfile[barIndex].posY = (activeFocusProfile[barIndex].posY or 0) + dy
            PersistActiveFocusProfile(barIndex)
            f.UpdateCoordLabel()
            RunWhenSafe("focusmove" .. barIndex, function()
                f:ClearAllPoints()
                f:SetPoint("CENTER", UIParent, "CENTER", activeFocusProfile[barIndex].posX, activeFocusProfile[barIndex].posY)
            end)
        end)
        return nb
    end
    f.nudges = {
        MakeNudgeBtn("^",  0,  1, "BOTTOM", "TOP",    0,  2),
        MakeNudgeBtn("v",  0, -1, "TOP",    "BOTTOM", 0, -2),
        MakeNudgeBtn("<", -1,  0, "RIGHT",  "LEFT",  -2,  0),
        MakeNudgeBtn(">",  1,  0, "LEFT",   "RIGHT",  2,  0),
    }

    f:Hide()
    return f
end

BuildFocusRow = function(barIndex)
    RunWhenSafe("focus" .. barIndex, function()
        for _, btn in ipairs(focusRowButtons[barIndex]) do
            ReleaseFocusButton(btn)
        end
        wipe(focusRowButtons[barIndex])

        local f = GetFocusRowFrame(barIndex)
        local cfg = GetFocusRowConfig(barIndex)
        if not cfg or not cfg.enabled or #cfg.slots == 0 then
            UnregisterStateDriver(f, "visibility")
            f:Hide()
            return
        end

        local size = cfg.buttonSize or 40
        local padding = cfg.padding or 4
        local count = #cfg.slots
        local orientation = cfg.orientation or "horizontal"
        local isVertical = (orientation == "vertical")

        local frameW, frameH
        if isVertical then
            frameW = size + 8
            frameH = (size * count) + (padding * (count - 1)) + 8
        else
            frameW = (size * count) + (padding * (count - 1)) + 8
            frameH = size + 8
        end

        f:SetSize(frameW, frameH)
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", cfg.posX or 0, cfg.posY or -200)
        f:EnableMouse(not cfg.locked)
        f.bg:SetColorTexture(0, 0, 0, cfg.bgOpacity or 0.3)
        f.unlockBorder:SetShown(not cfg.locked)
        f.coordLabel:SetShown(not cfg.locked)
        f.UpdateCoordLabel()
        for _, nb in ipairs(f.nudges) do
            nb:SetShown(not cfg.locked)
        end

        -- Create buttons
        for i, slotID in ipairs(cfg.slots) do
            local btn = AcquireFocusButton(f, slotID, size)
            if isVertical then
                btn:SetPoint("TOP", f, "TOP", 0, -(4 + (i - 1) * (size + padding)))
            else
                btn:SetPoint("LEFT", f, "LEFT", 4 + (i - 1) * (size + padding), 0)
            end
            -- Non-interactive: disable mouse on buttons so they're display-only
            if cfg.nonInteractive then
                btn:EnableMouse(false)
            end
            focusRowButtons[barIndex][i] = btn
        end

        -- Combat-only visibility, secure driver so it works in combat
        if cfg.combatOnly then
            RegisterStateDriver(f, "visibility", "[combat] show; hide")
        else
            UnregisterStateDriver(f, "visibility")
            f:Show()
        end
    end)
end

-- Debounced version of BuildFocusRow for slider callbacks.
-- Coalesces rapid-fire calls (e.g. dragging a slider) into a single rebuild.
local function BuildFocusRowDebounced(barIndex)
    if focusRebuildTimer[barIndex] then focusRebuildTimer[barIndex]:Cancel() end
    focusRebuildTimer[barIndex] = C_Timer.NewTimer(0.05, function()
        focusRebuildTimer[barIndex] = nil
        BuildFocusRow(barIndex)
    end)
end

-- Layout positioning functions
ApplyG13Layout = function(frame)
    -- Original G13 layout
    local buttonIndex
    local primaryOffsetX = SIDE_SIZE * 2 + PADDING * 2
    local rightOffsetX = primaryOffsetX + (PRIMARY_SIZE * 3 + PADDING * 2) + PADDING
    local bottomOffsetY = -(PRIMARY_SIZE * 2 + PADDING)
    local bottomWidth = BOTTOM_SIZE * 6 + PADDING * 5
    local bottomOffsetX = primaryOffsetX + ((PRIMARY_SIZE * 3 + PADDING * 2) / 2) - (bottomWidth / 2)
    
    -- LEFT SIDE: buttons 13-18 (2x3 grid, medium)
    buttonIndex = 1
    for row = 0, 2 do
        for col = 0, 1 do
            local btn = buttons[12 + buttonIndex]
            if btn then
                btn:ClearAllPoints()
                btn:SetSize(SIDE_SIZE, SIDE_SIZE)
                local xPos = col * (SIDE_SIZE + PADDING)
                local yPos = -row * (SIDE_SIZE + PADDING)
                btn:SetPoint("TOPLEFT", frame, "TOPLEFT", xPos, yPos)
            end
            buttonIndex = buttonIndex + 1
        end
    end
    
    -- CENTER: buttons 1-6 (3x2 grid, large)
    buttonIndex = 1
    for row = 0, 1 do
        for col = 0, 2 do
            local btn = buttons[buttonIndex]
            if btn then
                btn:ClearAllPoints()
                btn:SetSize(PRIMARY_SIZE, PRIMARY_SIZE)
                local xPos = primaryOffsetX + col * (PRIMARY_SIZE + PADDING)
                local yPos = -row * (PRIMARY_SIZE + PADDING)
                btn:SetPoint("TOPLEFT", frame, "TOPLEFT", xPos, yPos)
            end
            buttonIndex = buttonIndex + 1
        end
    end
    
    -- RIGHT SIDE: buttons 19-24 (2x3 grid, medium)
    buttonIndex = 7
    for row = 0, 2 do
        for col = 0, 1 do
            local btn = buttons[12 + buttonIndex]
            if btn then
                btn:ClearAllPoints()
                btn:SetSize(SIDE_SIZE, SIDE_SIZE)
                local xPos = rightOffsetX + col * (SIDE_SIZE + PADDING)
                local yPos = -row * (SIDE_SIZE + PADDING)
                btn:SetPoint("TOPLEFT", frame, "TOPLEFT", xPos, yPos)
            end
            buttonIndex = buttonIndex + 1
        end
    end
    
    -- BOTTOM: buttons 7-12 (6x1 grid, small)
    buttonIndex = 7
    for col = 0, 5 do
        local btn = buttons[buttonIndex]
        if btn then
            btn:ClearAllPoints()
            btn:SetSize(BOTTOM_SIZE, BOTTOM_SIZE)
            local xPos = bottomOffsetX + col * (BOTTOM_SIZE + PADDING)
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", xPos, bottomOffsetY)
        end
        buttonIndex = buttonIndex + 1
    end
end

ApplyKeyzenLayout = function(frame)
    -- Keyzen keyboard-style layout
    -- Large buttons (01-06) are the fixed center anchor
    local largeOffsetX = SIDE_SIZE * 2 + PADDING * 3
    local largeOffsetY = -(BOTTOM_SIZE + PADDING + SIDE_SIZE + PADDING)
    
    -- Large buttons: 01-06 (3x2 grid) - THE ANCHOR
    local buttonIndex = 1
    for row = 0, 1 do
        for col = 0, 2 do
            local btn = buttons[buttonIndex]
            if btn then
                btn:ClearAllPoints()
                btn:SetSize(PRIMARY_SIZE, PRIMARY_SIZE)
                local xPos = largeOffsetX + col * (PRIMARY_SIZE + PADDING)
                local yPos = largeOffsetY - row * (PRIMARY_SIZE + PADDING)
                btn:SetPoint("TOPLEFT", frame, "TOPLEFT", xPos, yPos)
            end
            buttonIndex = buttonIndex + 1
        end
    end
    
    -- Small buttons at top: 07, 08, 09 (centered above large buttons)
    local smallTopOffsetX = largeOffsetX + (PRIMARY_SIZE * 3 + PADDING * 2) / 2 - (BOTTOM_SIZE * 3 + PADDING * 2) / 2
    local smallTopOffsetY = 0
    for i = 0, 2 do
        local btn = buttons[7 + i]
        if btn then
            btn:ClearAllPoints()
            btn:SetSize(BOTTOM_SIZE, BOTTOM_SIZE)
            local xPos = smallTopOffsetX + i * (BOTTOM_SIZE + PADDING)
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", xPos, smallTopOffsetY)
        end
    end
    
    -- Medium buttons row 2: 13, 15, 20, 22, 24 (evenly spaced with 20 centered above 02)
    local medRow2Y = -(BOTTOM_SIZE + PADDING)
    -- Button 20 centered above button 02 (which is at largeOffsetX + PRIMARY_SIZE + PADDING)
    local btn20X = largeOffsetX + PRIMARY_SIZE + PADDING
    -- Calculate spacing for even distribution
    local rowSpacing = SIDE_SIZE + PADDING
    
    buttons[20]:ClearAllPoints()
    buttons[20]:SetSize(SIDE_SIZE, SIDE_SIZE)
    buttons[20]:SetPoint("TOPLEFT", frame, "TOPLEFT", btn20X, medRow2Y)
    
    buttons[17]:ClearAllPoints()
    buttons[17]:SetSize(SIDE_SIZE, SIDE_SIZE)
    buttons[17]:SetPoint("TOPLEFT", frame, "TOPLEFT", btn20X - rowSpacing, medRow2Y)
    
    buttons[13]:ClearAllPoints()
    buttons[13]:SetSize(SIDE_SIZE, SIDE_SIZE)
    buttons[13]:SetPoint("TOPLEFT", frame, "TOPLEFT", btn20X - rowSpacing * 2, medRow2Y)
    
    buttons[22]:ClearAllPoints()
    buttons[22]:SetSize(SIDE_SIZE, SIDE_SIZE)
    buttons[22]:SetPoint("TOPLEFT", frame, "TOPLEFT", btn20X + rowSpacing, medRow2Y)
    
    buttons[24]:ClearAllPoints()
    buttons[24]:SetSize(SIDE_SIZE, SIDE_SIZE)
    buttons[24]:SetPoint("TOPLEFT", frame, "TOPLEFT", btn20X + rowSpacing * 2, medRow2Y)
    
    -- Medium button row 3 (aligned with L01-L03): 14 (left), 19 (right)
    buttons[14]:ClearAllPoints()
    buttons[14]:SetSize(SIDE_SIZE, SIDE_SIZE)
    buttons[14]:SetPoint("TOPLEFT", frame, "TOPLEFT", largeOffsetX - SIDE_SIZE - PADDING, largeOffsetY)
    
    buttons[19]:ClearAllPoints()
    buttons[19]:SetSize(SIDE_SIZE, SIDE_SIZE)
    buttons[19]:SetPoint("TOPLEFT", frame, "TOPLEFT", largeOffsetX + (PRIMARY_SIZE + PADDING) * 3, largeOffsetY)
    
    -- Medium row 4 (aligned with L04-L06): 23, 16 (left), 21 (right)
    -- Move up by half button width to close the gap
    local medRow4Y = largeOffsetY - (PRIMARY_SIZE + PADDING) + SIDE_SIZE/2
    buttons[23]:ClearAllPoints()
    buttons[23]:SetSize(SIDE_SIZE, SIDE_SIZE)
    buttons[23]:SetPoint("TOPLEFT", frame, "TOPLEFT", largeOffsetX - SIDE_SIZE * 2 - PADDING * 2, medRow4Y)
    
    buttons[16]:ClearAllPoints()
    buttons[16]:SetSize(SIDE_SIZE, SIDE_SIZE)
    buttons[16]:SetPoint("TOPLEFT", frame, "TOPLEFT", largeOffsetX - SIDE_SIZE - PADDING, medRow4Y)
    
    buttons[21]:ClearAllPoints()
    buttons[21]:SetSize(SIDE_SIZE, SIDE_SIZE)
    buttons[21]:SetPoint("TOPLEFT", frame, "TOPLEFT", largeOffsetX + (PRIMARY_SIZE + PADDING) * 3, medRow4Y)
    
    -- Bottom row: 15, 18 (left), 10, 11, 12 (small, below button 5)
    -- Move up by full button length to close the gap
    local bottomRowY = medRow4Y - SIDE_SIZE - PADDING
    buttons[15]:ClearAllPoints()
    buttons[15]:SetSize(SIDE_SIZE, SIDE_SIZE)
    buttons[15]:SetPoint("TOPLEFT", frame, "TOPLEFT", largeOffsetX - SIDE_SIZE * 2 - PADDING * 2, bottomRowY)
    
    buttons[18]:ClearAllPoints()
    buttons[18]:SetSize(SIDE_SIZE, SIDE_SIZE)
    buttons[18]:SetPoint("TOPLEFT", frame, "TOPLEFT", largeOffsetX - SIDE_SIZE - PADDING, bottomRowY)
    
    -- Small buttons 10, 11, 12 below button 5, with button 11 centered under button 5
    local smallBottomOffsetX = largeOffsetX + PRIMARY_SIZE + PADDING + PRIMARY_SIZE/2 - BOTTOM_SIZE - PADDING - BOTTOM_SIZE/2
    local smallBottomOffsetY = largeOffsetY - PRIMARY_SIZE * 2 - PADDING * 2
    for i = 0, 2 do
        local btn = buttons[10 + i]
        if btn then
            btn:ClearAllPoints()
            btn:SetSize(BOTTOM_SIZE, BOTTOM_SIZE)
            local xPos = smallBottomOffsetX + i * (BOTTOM_SIZE + PADDING)
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", xPos, smallBottomOffsetY)
        end
    end
end

-- Create the main frame with all buttons
local function CreateMainFrame()
    local frame = CreateFrame("Frame", "JG13_MainFrame", UIParent)
    frame:SetMovable(false)
    frame:EnableMouse(false)

    -- Calculate frame size
    local primaryWidth = (PRIMARY_SIZE * 3) + (PADDING * 2)
    local primaryHeight = (PRIMARY_SIZE * 2) + PADDING
    local sideWidth = (SIDE_SIZE * 2) + PADDING
    local bottomWidth = (BOTTOM_SIZE * 6) + (PADDING * 5)
    local bottomHeight = BOTTOM_SIZE

    local totalWidth = sideWidth + PADDING + primaryWidth + PADDING + sideWidth
    local totalHeight = primaryHeight + PADDING + bottomHeight

    frame:SetSize(totalWidth, totalHeight)

    -- Set scale from active profile
    frame:SetScale(activeProfile.scale or 1.0)

    -- Set position from active profile
    frame:ClearAllPoints()
    frame:SetPoint("TOP", UIParent, "TOP", 0, activeProfile.positionY or -400)

    -- Background (for visibility during setup)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, activeProfile.bgOpacity or 0.3)

    -- Create all buttons first (without positioning)
    for i = 1, 24 do
        buttons[i] = CreateActionButton(frame, i, PRIMARY_SIZE)
    end

    -- Apply layout based on active profile
    if activeProfile.layoutMode == "Keyzen" then
        ApplyKeyzenLayout(frame)
    else
        ApplyG13Layout(frame)
    end

    -- Setup secure state driver for combat-safe page swapping
    SetupSecurePageDriver()

    -- Apply overall frame alpha and hide-on-mouse-out from active profile
    SetMouseOutFade(frame)

    return frame
end

-- Update all buttons - refresh keybinds (page swaps handled by secure state driver)
local function UpdateButtons()
    UpdateKeybinds()
end

-- Forward declaration for CreateConfigWindow
local CreateConfigWindow

-- Event handler
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
eventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
eventFrame:RegisterEvent("ACTIONBAR_UPDATE_STATE")
eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
eventFrame:RegisterEvent("SPELL_UPDATE_USABLE")
eventFrame:RegisterEvent("SPELL_UPDATE_ICON")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTER_COMBAT")
eventFrame:RegisterEvent("PLAYER_LEAVE_COMBAT")
eventFrame:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
eventFrame:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
eventFrame:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
-- eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("UPDATE_BINDINGS")

local firstEnterWorld = true

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "JarsG13Bars" then
            InitDB()
            LoadSpecLayout()
            for i = 1, NUM_FOCUS_BARS do LoadFocusSpecLayout(i) end
            HideDefaultBars()
            mainFrame = CreateMainFrame()

            CreateConfigWindow()
            for i = 1, NUM_FOCUS_BARS do BuildFocusRow(i) end

            -- Setup override bindings and update keybinds after a delay to ensure buttons are ready
            C_Timer.After(1, function()
                UpdateOverrideBindings()
                UpdateKeybinds()
            end)

            print("|cff00ff00Jar's G13 Action Bars|r loaded. Type |cff00ffff/jg13|r to configure.")
            print("|cff00ff00Jar's G13|r: Buttons 1-12 mirror Action Bar 1, buttons 13-24 mirror Action Bar 2.")

            self:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, function()
            UpdateButtons()
            -- spec shows up by now, only need this once tho
            if firstEnterWorld and GetCurrentSpecID() > 0 then
                firstEnterWorld = false
                for i = 1, NUM_FOCUS_BARS do
                    LoadFocusSpecLayout(i)
                    BuildFocusRow(i)
                end
                if RefreshConfigUI then RefreshConfigUI() end
                for i = 1, NUM_FOCUS_BARS do
                    if RefreshFocusConfigUI[i] then RefreshFocusConfigUI[i](true) end
                end
            end
        end)

    elseif event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" then
        LoadSpecLayout()
        for i = 1, NUM_FOCUS_BARS do LoadFocusSpecLayout(i) end
        ApplyActiveProfile()
        HideDefaultBars()
        UpdateKeybinds()
        for i = 1, NUM_FOCUS_BARS do BuildFocusRow(i) end
        if RefreshConfigUI then RefreshConfigUI() end
        for i = 1, NUM_FOCUS_BARS do
            if RefreshFocusConfigUI[i] then RefreshFocusConfigUI[i](true) end
        end

    elseif event == "UPDATE_BINDINGS" then
        UpdateOverrideBindings()
        UpdateKeybinds()

    elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" or
           event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" or
           event == "UPDATE_OVERRIDE_ACTIONBAR" or event == "SPELL_UPDATE_ICON" or
           event == "UPDATE_SHAPESHIFT_FORM" or event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        UpdateButtons()

    elseif event == "PLAYER_REGEN_ENABLED" then
        FlushSafeQueue()
        UpdateKeybinds()

    elseif event == "ACTIONBAR_UPDATE_COOLDOWN" or
           event == "ACTIONBAR_UPDATE_USABLE" or event == "SPELL_UPDATE_USABLE" or
           event == "ACTIONBAR_UPDATE_STATE" or event == "SPELL_UPDATE_CHARGES" or
           event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTER_COMBAT" or
           event == "PLAYER_LEAVE_COMBAT" then
        -- ActionBarButtonTemplate handles these automatically - no action needed
    end
end)

-- Function to update main frame position
local function UpdateFramePosition(yOffset)
    if mainFrame then
        activeProfile.positionY = yOffset
        PersistActiveProfile()
        RunWhenSafe("profile", function()
            mainFrame:ClearAllPoints()
            mainFrame:SetPoint("TOP", UIParent, "TOP", 0, activeProfile.positionY or -400)
            mainFrame:SetScale(activeProfile.scale or 1.0)
        end)
    end
end

-- Function to update background opacity
local function UpdateBackgroundOpacity(opacity)
    if mainFrame and mainFrame.bg then
        mainFrame.bg:SetColorTexture(0, 0, 0, opacity)
        activeProfile.bgOpacity = opacity
        PersistActiveProfile()
    end
end

-- Function to update frame scale
local function UpdateScale(scale)
    if mainFrame then
        activeProfile.scale = scale
        PersistActiveProfile()
        RunWhenSafe("profile", function()
            mainFrame:ClearAllPoints()
            mainFrame:SetPoint("TOP", UIParent, "TOP", 0, activeProfile.positionY or -400)
            mainFrame:SetScale(activeProfile.scale or 1.0)
        end)
    end
end

-- Function to update overall frame alpha
local function UpdateFrameAlpha(alpha)
    if mainFrame then
        activeProfile.frameAlpha = alpha
        if not activeProfile.hideOnMouseOut then
            mainFrame:SetAlpha(alpha)
        end
        PersistActiveProfile()
    end
end

-- Function to apply hide-on-mouse-out behavior
local function ApplyHideOnMouseOut(enabled)
    if not mainFrame then return end
    activeProfile.hideOnMouseOut = enabled
    SetMouseOutFade(mainFrame)
    PersistActiveProfile()
end

-- Create config window
local configFrame
local focusConfigFrame = {}
local CreateFocusConfigWindow

-- Modern UI color palette
local UI = {
    bg        = { 0.10, 0.10, 0.12, 0.95 },
    header    = { 0.13, 0.13, 0.16, 1 },
    accent    = { 1.0,  0.55, 0.0,  1 },      -- orange accent
    accentDim = { 0.70, 0.35, 0.0,  1 },
    text      = { 0.90, 0.90, 0.90, 1 },
    textDim   = { 0.55, 0.55, 0.58, 1 },
    section   = { 0.16, 0.16, 0.19, 1 },
    border    = { 0.22, 0.22, 0.26, 1 },
    sliderBg  = { 0.18, 0.18, 0.22, 1 },
    sliderFill= { 1.0,  0.55, 0.0,  0.6 },
    btnNormal = { 0.18, 0.18, 0.22, 1 },
    btnHover  = { 0.24, 0.24, 0.28, 1 },
    btnPress  = { 0.14, 0.14, 0.17, 1 },
    checkOn   = { 1.0,  0.55, 0.0,  1 },
    checkOff  = { 0.22, 0.22, 0.26, 1 },
}

-- Helper: create a flat, modern slider
local function CreateModernSlider(parent, name, labelText, minVal, maxVal, curVal, step, width, formatFunc, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, 42)

    -- Label (left)
    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    label:SetTextColor(UI.text[1], UI.text[2], UI.text[3])
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(labelText)

    -- Value readout (right)
    local valueText = container:CreateFontString(nil, "OVERLAY")
    valueText:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    valueText:SetTextColor(UI.accent[1], UI.accent[2], UI.accent[3])
    valueText:SetPoint("TOPRIGHT", 0, 0)

    -- Track background
    local trackBg = container:CreateTexture(nil, "BACKGROUND")
    trackBg:SetHeight(4)
    trackBg:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -10)
    trackBg:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    trackBg:SetColorTexture(UI.sliderBg[1], UI.sliderBg[2], UI.sliderBg[3], UI.sliderBg[4])

    -- Filled portion of the track
    local trackFill = container:CreateTexture(nil, "ARTWORK")
    trackFill:SetHeight(4)
    trackFill:SetPoint("LEFT", trackBg, "LEFT")
    trackFill:SetColorTexture(UI.sliderFill[1], UI.sliderFill[2], UI.sliderFill[3], UI.sliderFill[4])

    -- Actual slider (invisible native thumb, overlaid)
    local slider = CreateFrame("Slider", name, container, "MinimalSliderTemplate")
    slider:SetPoint("TOPLEFT", trackBg, "TOPLEFT", 0, 6)
    slider:SetPoint("BOTTOMRIGHT", trackBg, "BOTTOMRIGHT", 0, -6)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValue(curVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    -- Custom thumb texture
    local thumb = slider:GetThumbTexture() or slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(14, 14)
    thumb:SetColorTexture(UI.accent[1], UI.accent[2], UI.accent[3], 1)
    slider:SetThumbTexture(thumb)

    -- Remove default slider background if present
    if slider.NineSlice then slider.NineSlice:Hide() end
    if slider.Background then slider.Background:Hide() end

    local function updateFill(val)
        local pct = (val - minVal) / (maxVal - minVal)
        trackFill:SetWidth(math.max(1, pct * trackBg:GetWidth()))
    end

    local function formatValue(val)
        return formatFunc and formatFunc(val) or tostring(val)
    end

    valueText:SetText(formatValue(curVal))
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        valueText:SetText(formatValue(value))
        updateFill(value)
        if onChange then onChange(value) end
    end)

    -- Defer initial fill width until layout is done
    C_Timer.After(0, function() updateFill(curVal) end)

    container.slider = slider
    container.valueText = valueText
    return container
end

-- Helper: create a modern checkbox (flat toggle style)
local function CreateModernCheck(parent, labelText, checked, onClick)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(200, 22)

    local box = CreateFrame("Button", nil, container)
    box:SetSize(18, 18)
    box:SetPoint("LEFT", 0, 0)

    local boxBg = box:CreateTexture(nil, "BACKGROUND")
    boxBg:SetAllPoints()
    boxBg:SetColorTexture(UI.checkOff[1], UI.checkOff[2], UI.checkOff[3], UI.checkOff[4])

    local checkmark = box:CreateTexture(nil, "OVERLAY")
    checkmark:SetSize(12, 12)
    checkmark:SetPoint("CENTER")
    checkmark:SetColorTexture(UI.checkOn[1], UI.checkOn[2], UI.checkOn[3], UI.checkOn[4])

    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    label:SetTextColor(UI.text[1], UI.text[2], UI.text[3])
    label:SetPoint("LEFT", box, "RIGHT", 8, 0)
    label:SetText(labelText)

    container.isChecked = checked
    local function updateVisual()
        if container.isChecked then
            checkmark:Show()
            boxBg:SetColorTexture(UI.accentDim[1], UI.accentDim[2], UI.accentDim[3], 0.3)
        else
            checkmark:Hide()
            boxBg:SetColorTexture(UI.checkOff[1], UI.checkOff[2], UI.checkOff[3], UI.checkOff[4])
        end
    end
    updateVisual()

    box:SetScript("OnClick", function()
        container.isChecked = not container.isChecked
        updateVisual()
        if onClick then onClick(container.isChecked) end
    end)

    container.SetChecked = function(self, val)
        self.isChecked = val
        updateVisual()
    end
    container.GetChecked = function(self) return self.isChecked end

    return container
end

-- Helper: modern flat button
local function CreateModernButton(parent, text, width, height, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(UI.btnNormal[1], UI.btnNormal[2], UI.btnNormal[3], UI.btnNormal[4])
    btn.bg = bg

    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    label:SetTextColor(UI.accent[1], UI.accent[2], UI.accent[3])
    label:SetPoint("CENTER")
    label:SetText(text)
    btn.label = label

    btn:SetScript("OnEnter", function() bg:SetColorTexture(UI.btnHover[1], UI.btnHover[2], UI.btnHover[3], UI.btnHover[4]) end)
    btn:SetScript("OnLeave", function() bg:SetColorTexture(UI.btnNormal[1], UI.btnNormal[2], UI.btnNormal[3], UI.btnNormal[4]) end)
    btn:SetScript("OnMouseDown", function() bg:SetColorTexture(UI.btnPress[1], UI.btnPress[2], UI.btnPress[3], UI.btnPress[4]) end)
    btn:SetScript("OnMouseUp", function() bg:SetColorTexture(UI.btnHover[1], UI.btnHover[2], UI.btnHover[3], UI.btnHover[4]) end)
    btn:SetScript("OnClick", onClick)

    btn.SetText = function(self, t) self.label:SetText(t) end

    return btn
end

-- Helper: section header line
local function CreateSectionHeader(parent, text)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(1, 20)

    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    label:SetTextColor(UI.textDim[1], UI.textDim[2], UI.textDim[3])
    label:SetPoint("LEFT", 0, 0)
    label:SetText(string.upper(text))

    local line = container:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", label, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", container, "RIGHT")
    line:SetColorTexture(UI.border[1], UI.border[2], UI.border[3], 0.5)

    return container
end

-- Helper: create a modern text input box
local function CreateModernEditBox(parent, width, height)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(width, height)
    box:SetFontObject(ChatFontNormal)
    box:SetAutoFocus(false)
    box:SetMaxLetters(50)
    box:SetTextInsets(8, 8, 0, 0)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    box:SetBackdropColor(UI.sliderBg[1], UI.sliderBg[2], UI.sliderBg[3], UI.sliderBg[4])
    box:SetBackdropBorderColor(UI.border[1], UI.border[2], UI.border[3], UI.border[4])
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return box
end

CreateConfigWindow = function()
    if configFrame then
        return
    end

    local PANEL_WIDTH = 440
    local CONTENT_WIDTH = PANEL_WIDTH - 90  -- 30px left + 60px right (scrollbar + margin)
    local PANEL_HEIGHT = 620

    -- Main frame (no Blizzard template)
    configFrame = CreateFrame("Frame", "JG13_ConfigFrame", UIParent, "BackdropTemplate")
    configFrame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    configFrame:SetPoint("CENTER")
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    configFrame:SetFrameStrata("DIALOG")

    -- Dark background with thin border
    configFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    configFrame:SetBackdropColor(UI.bg[1], UI.bg[2], UI.bg[3], UI.bg[4])
    configFrame:SetBackdropBorderColor(UI.border[1], UI.border[2], UI.border[3], UI.border[4])

    -- Title bar area
    local titleBar = CreateFrame("Frame", nil, configFrame)
    titleBar:SetHeight(36)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(UI.header[1], UI.header[2], UI.header[3], UI.header[4])

    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
    titleText:SetTextColor(UI.accent[1], UI.accent[2], UI.accent[3])
    titleText:SetPoint("LEFT", 16, 0)
    titleText:SetText("Jar's G13 Bars")

    -- Close button (minimal X)
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(36, 36)
    closeBtn:SetPoint("RIGHT", 0, 0)
    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
    closeTxt:SetFont("Fonts\\FRIZQT__.TTF", 16, "")
    closeTxt:SetTextColor(UI.textDim[1], UI.textDim[2], UI.textDim[3])
    closeTxt:SetPoint("CENTER")
    closeTxt:SetText("x")
    closeBtn:SetScript("OnEnter", function() closeTxt:SetTextColor(1, 0.4, 0.4) end)
    closeBtn:SetScript("OnLeave", function() closeTxt:SetTextColor(UI.textDim[1], UI.textDim[2], UI.textDim[3]) end)
    closeBtn:SetScript("OnClick", function() configFrame:Hide() end)

    -- Scroll frame for content (prevents overflow)
    local scrollFrame = CreateFrame("ScrollFrame", nil, configFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 30, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -42, 4)

    -- Hide the default scroll bar textures for a cleaner look
    if scrollFrame.ScrollBar then
        local sb = scrollFrame.ScrollBar
        if sb.Background then sb.Background:Hide() end
    end

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(CONTENT_WIDTH)
    scrollFrame:SetScrollChild(content)

    local yPos = -16  -- starting offset inside content
    local SPACING = 14
    local SECTION_SPACING = 22

    local function advanceY(amount) yPos = yPos - amount end
    local function placeWidget(widget, height)
        widget:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yPos)
        widget:SetWidth(CONTENT_WIDTH)
        advanceY((height or 42) + SPACING)
    end

    -- === PROFILES SECTION ===
    local secProfiles = CreateSectionHeader(content, "Profiles")
    placeWidget(secProfiles, 20)

    -- Spec + layout label
    local specLabel = content:CreateFontString(nil, "OVERLAY")
    specLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    specLabel:SetTextColor(UI.text[1], UI.text[2], UI.text[3])
    specLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yPos)
    advanceY(16 + SPACING)

    local function UpdateSpecLabel()
        local specName = GetCurrentSpecName()
        local layoutText = currentLayoutName and (": " .. currentLayoutName) or ": (none)"
        specLabel:SetText("Spec: " .. specName .. " | Layout" .. layoutText)
    end
    UpdateSpecLabel()

    -- Layout name input + Save button row
    local profileRow = CreateFrame("Frame", nil, content)
    profileRow:SetSize(CONTENT_WIDTH, 26)
    placeWidget(profileRow, 26)

    local nameBox = CreateModernEditBox(profileRow, CONTENT_WIDTH - 80, 26)
    nameBox:SetPoint("LEFT", 0, 0)
    if currentLayoutName then
        nameBox:SetText(currentLayoutName)
    end

    local saveBtn = CreateModernButton(profileRow, "Save", 72, 26, function()
        local name = nameBox:GetText():trim()
        if name ~= "" then
            SaveLayout(name)
        end
    end)
    saveBtn:SetPoint("RIGHT", 0, 0)

    -- Load dropdown + Delete button row
    local loadRow = CreateFrame("Frame", nil, content)
    loadRow:SetSize(CONTENT_WIDTH, 26)
    placeWidget(loadRow, 26)

    local layoutDropdown = CreateFrame("DropdownButton", nil, loadRow, "WowStyle1DropdownTemplate")
    layoutDropdown:SetPoint("LEFT", 0, 0)
    layoutDropdown:SetWidth(CONTENT_WIDTH - 80)
    layoutDropdown:SetDefaultText(currentLayoutName or "Select a layout...")

    layoutDropdown:SetupMenu(function(_, rootDescription)
        local names = GetSortedLayoutNames()
        if #names == 0 then
            rootDescription:CreateTitle("No saved layouts")
            return
        end
        for _, name in ipairs(names) do
            rootDescription:CreateButton(name, function()
                LoadLayout(name)
            end)
        end
    end)

    local deleteBtn = CreateModernButton(loadRow, "Delete", 72, 26, function()
        local name = nameBox:GetText():trim()
        if name ~= "" then
            DeleteLayout(name)
        end
    end)
    deleteBtn:SetPoint("RIGHT", 0, 0)

    -- === APPEARANCE SECTION ===
    advanceY(SECTION_SPACING - SPACING)
    local sec1 = CreateSectionHeader(content, "Appearance")
    placeWidget(sec1, 20)

    -- Position slider
    local posSlider = CreateModernSlider(content, "JG13_PositionSlider", "Vertical Position",
        -2400, 0, activeProfile.positionY or -400, 1, CONTENT_WIDTH,
        function(v) return tostring(math.floor(v)) end,
        function(v) UpdateFramePosition(math.floor(v)) end)
    placeWidget(posSlider, 42)

    -- Background opacity slider
    local opacitySlider = CreateModernSlider(content, "JG13_OpacitySlider", "Background Opacity",
        0, 1, activeProfile.bgOpacity or 0.3, 0.05, CONTENT_WIDTH,
        function(v) return string.format("%.0f%%", v * 100) end,
        function(v) UpdateBackgroundOpacity(v) end)
    placeWidget(opacitySlider, 42)

    -- Scale slider
    local scaleSlider = CreateModernSlider(content, "JG13_ScaleSlider", "Scale",
        0.5, 1.0, activeProfile.scale or 1.0, 0.05, CONTENT_WIDTH,
        function(v) return string.format("%.0f%%", v * 100) end,
        function(v) UpdateScale(v) end)
    placeWidget(scaleSlider, 42)

    -- Overall transparency slider
    local alphaSlider = CreateModernSlider(content, "JG13_AlphaSlider", "Overall Transparency",
        0, 1, activeProfile.frameAlpha or 1.0, 0.05, CONTENT_WIDTH,
        function(v) return string.format("%.0f%%", v * 100) end,
        function(v) UpdateFrameAlpha(v) end)
    placeWidget(alphaSlider, 42)

    -- === BEHAVIOR SECTION ===
    advanceY(SECTION_SPACING - SPACING)
    local sec2 = CreateSectionHeader(content, "Behavior")
    placeWidget(sec2, 20)

    -- Hide on mouse out
    local hideCheck = CreateModernCheck(content, "Hide unless moused over", activeProfile.hideOnMouseOut,
        function(checked) ApplyHideOnMouseOut(checked) end)
    placeWidget(hideCheck, 22)

    -- Show keybinds
    local keybindsCheck = CreateModernCheck(content, "Show keybinds on buttons", activeProfile.showKeybinds,
        function(checked)
            activeProfile.showKeybinds = checked
            UpdateKeybinds()
            PersistActiveProfile()
        end)
    placeWidget(keybindsCheck, 22)

    -- === LAYOUT SECTION ===
    advanceY(SECTION_SPACING - SPACING)
    local sec3 = CreateSectionHeader(content, "Layout")
    placeWidget(sec3, 20)

    -- Layout mode buttons (radio-style toggle)
    local layoutRow2 = CreateFrame("Frame", nil, content)
    layoutRow2:SetSize(CONTENT_WIDTH, 30)
    placeWidget(layoutRow2, 30)

    local layoutLbl = layoutRow2:CreateFontString(nil, "OVERLAY")
    layoutLbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    layoutLbl:SetTextColor(UI.text[1], UI.text[2], UI.text[3])
    layoutLbl:SetPoint("LEFT", 0, 0)
    layoutLbl:SetText("Mode:")

    local function createLayoutToggle(parent, text, x, isActive, onClick)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(80, 28)
        btn:SetPoint("LEFT", x, 0)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        btn.bg = bg
        local lbl = btn:CreateFontString(nil, "OVERLAY")
        lbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        lbl:SetPoint("CENTER")
        lbl:SetText(text)
        btn.label = lbl
        btn.SetActive = function(self, active)
            if active then
                bg:SetColorTexture(UI.accentDim[1], UI.accentDim[2], UI.accentDim[3], 0.4)
                lbl:SetTextColor(UI.accent[1], UI.accent[2], UI.accent[3])
            else
                bg:SetColorTexture(UI.btnNormal[1], UI.btnNormal[2], UI.btnNormal[3], UI.btnNormal[4])
                lbl:SetTextColor(UI.textDim[1], UI.textDim[2], UI.textDim[3])
            end
        end
        btn:SetScript("OnClick", onClick)
        btn:SetActive(isActive)
        return btn
    end

    local g13Btn, keyzenBtn
    g13Btn = createLayoutToggle(layoutRow2, "G13", 50, activeProfile.layoutMode == "G13", function()
        activeProfile.layoutMode = "G13"
        g13Btn:SetActive(true)
        keyzenBtn:SetActive(false)
        ApplyLayoutMode()
        PersistActiveProfile()
    end)
    keyzenBtn = createLayoutToggle(layoutRow2, "Keyzen", 136, activeProfile.layoutMode == "Keyzen", function()
        activeProfile.layoutMode = "Keyzen"
        g13Btn:SetActive(false)
        keyzenBtn:SetActive(true)
        ApplyLayoutMode()
        PersistActiveProfile()
    end)

    -- === BLIZZARD BARS SECTION ===
    advanceY(SECTION_SPACING - SPACING)
    local sec4 = CreateSectionHeader(content, "Blizzard Bars")
    placeWidget(sec4, 20)

    local barNames = {
        {key = "MainActionBar", label = "Hide Main Bar (Bar 1)"},
    }

    local barChecks = {}
    for _, barInfo in ipairs(barNames) do
        if activeProfile.hideBars[barInfo.key] == nil then
            activeProfile.hideBars[barInfo.key] = true
        end
        local barCheck = CreateModernCheck(content, barInfo.label, activeProfile.hideBars[barInfo.key],
            function(checked)
                activeProfile.hideBars[barInfo.key] = checked
                HideDefaultBars()
                PersistActiveProfile()
            end)
        placeWidget(barCheck, 22)
        barChecks[barInfo.key] = barCheck
    end

    -- === BAR PAGING SECTION ===
    advanceY(SECTION_SPACING - SPACING)
    local secPaging = CreateSectionHeader(content, "Bar Paging  (Override Bar / Dragonriding unchanged)")
    placeWidget(secPaging, 20)

    local PAGE_CONDS = {
        { key = "b1", label = "Cat Form  /  Stealth" },
        { key = "b2", label = "Bear Form" },
        { key = "b3", label = "Moonkin  /  Other Form" },
        { key = "b4", label = "Bonus State 4" },
        { key = "b5", label = "Bonus State 5" },
    }

    local pagingSpinners = {}

    local function MakePageSpinner(mapKey, condLabel)
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(CONTENT_WIDTH, 24)

        local lbl = row:CreateFontString(nil, "OVERLAY")
        lbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        lbl:SetTextColor(UI.text[1], UI.text[2], UI.text[3])
        lbl:SetPoint("LEFT", 0, 0)
        lbl:SetText(condLabel)

        local valLbl = row:CreateFontString(nil, "OVERLAY")
        valLbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        valLbl:SetTextColor(UI.accent[1], UI.accent[2], UI.accent[3])
        valLbl:SetPoint("RIGHT", -46, 0)
        valLbl:SetText("Page " .. (activeProfile.pageMap[mapKey] or 1))

        local btnUp = CreateModernButton(row, ">", 20, 22, nil)
        btnUp:SetPoint("RIGHT", 0, 0)
        local btnDn = CreateModernButton(row, "<", 20, 22, nil)
        btnDn:SetPoint("RIGHT", btnUp, "LEFT", -2, 0)

        btnUp:SetScript("OnClick", function()
            local p = (activeProfile.pageMap[mapKey] or 1) + 1
            if p > 12 then p = 1 end
            activeProfile.pageMap[mapKey] = p
            valLbl:SetText("Page " .. p)
            PersistActiveProfile()
            RefreshStateDriver()
        end)
        btnDn:SetScript("OnClick", function()
            local p = (activeProfile.pageMap[mapKey] or 1) - 1
            if p < 1 then p = 12 end
            activeProfile.pageMap[mapKey] = p
            valLbl:SetText("Page " .. p)
            PersistActiveProfile()
            RefreshStateDriver()
        end)

        row.mapKey = mapKey
        row.valLbl = valLbl
        row.Refresh = function(self)
            self.valLbl:SetText("Page " .. (activeProfile.pageMap[self.mapKey] or 1))
        end
        return row
    end

    for _, cond in ipairs(PAGE_CONDS) do
        local sp = MakePageSpinner(cond.key, cond.label)
        placeWidget(sp, 24)
        table.insert(pagingSpinners, sp)
    end

    -- === FOCUS BAR SECTION ===
    advanceY(SECTION_SPACING - SPACING)
    local secFocus = CreateSectionHeader(content, "Focus Bars")
    placeWidget(secFocus, 20)

    for bi = 1, NUM_FOCUS_BARS do
        local focusConfigBtn = CreateModernButton(content, "Focus Bar " .. bi .. " Config", 180, 30, function()
            CreateFocusConfigWindow(bi)
            if focusConfigFrame[bi] then
                focusConfigFrame[bi]:SetShown(not focusConfigFrame[bi]:IsShown())
            end
        end)
        placeWidget(focusConfigBtn, 30)
    end

    -- === ACTIONS SECTION ===
    advanceY(SECTION_SPACING - SPACING)
    local sec5 = CreateSectionHeader(content, "Actions")
    placeWidget(sec5, 20)

    -- Keybind button (forward-declared so the closure can reference it)
    local keybindBtn
    keybindBtn = CreateModernButton(content, "Set Keybinds", 160, 30, function()
        if LibKeyBound then
            if LibKeyBound:IsShown() then
                LibKeyBound:Toggle()
                keybindBtn:SetText("Set Keybinds")
            else
                LibKeyBound:Toggle()
                keybindBtn:SetText("Exit Keybind Mode")
                print("|cff00ff00Jar's G13 Bars|r: Hover over a button and press a key to bind it.")
            end
        end
    end)
    placeWidget(keybindBtn, 30)

    -- Update button text when LibKeyBound state changes
    if LibKeyBound then
        LibKeyBound.RegisterCallback(keybindBtn, "LIBKEYBOUND_ENABLED", function()
            keybindBtn:SetText("Exit Keybind Mode")
        end)
        LibKeyBound.RegisterCallback(keybindBtn, "LIBKEYBOUND_DISABLED", function()
            keybindBtn:SetText("Set Keybinds")
        end)
    end

    -- Reset button
    local resetBtn = CreateModernButton(content, "Reset to Defaults", 160, 30, function()
        activeProfile = CreateDefaultProfile()
        currentLayoutName = nil
        JarsG13BarsDB.lastActiveLayout = nil
        PersistActiveProfile()
        ApplyActiveProfile()
        HideDefaultBars()
        UpdateKeybinds()
        if RefreshConfigUI then RefreshConfigUI() end
        print("|cff00ff00Jar's G13 Bars|r: Settings reset to default.")
    end)
    placeWidget(resetBtn, 30)

    -- Set total content height so scroll works
    content:SetHeight(math.abs(yPos) + 20)

    -- Make frame close with Escape
    tinsert(UISpecialFrames, "JG13_ConfigFrame")

    -- Reload function to refresh all UI widgets from activeProfile
    RefreshConfigUI = function(rebuild)
        if rebuild then
            -- Full rebuild needed (focus row slot count changed)
            local wasShown = configFrame:IsShown()
            local point, rel, relPoint, cx, cy = configFrame:GetPoint(1)
            configFrame:Hide()
            -- configFrame:SetParent(nil)
            configFrame = nil
            CreateConfigWindow()
            if configFrame and point then
                configFrame:ClearAllPoints()
                configFrame:SetPoint(point, rel, relPoint, cx, cy)
            end
            if wasShown and configFrame then configFrame:Show() end
            return
        end
        posSlider.slider:SetValue(activeProfile.positionY or -400)
        opacitySlider.slider:SetValue(activeProfile.bgOpacity or 0.3)
        scaleSlider.slider:SetValue(activeProfile.scale or 1.0)
        alphaSlider.slider:SetValue(activeProfile.frameAlpha or 1.0)
        hideCheck:SetChecked(activeProfile.hideOnMouseOut or false)
        keybindsCheck:SetChecked(activeProfile.showKeybinds ~= false)
        g13Btn:SetActive(activeProfile.layoutMode == "G13")
        keyzenBtn:SetActive(activeProfile.layoutMode == "Keyzen")
        for key, check in pairs(barChecks) do
            check:SetChecked(activeProfile.hideBars[key] ~= false)
        end
        nameBox:SetText(currentLayoutName or "")
        layoutDropdown:GenerateMenu()
        layoutDropdown:SetDefaultText(currentLayoutName or "Select a layout...")
        for _, sp in ipairs(pagingSpinners) do sp:Refresh() end
        UpdateSpecLabel()
        UpdateKeybinds()
    end

    configFrame:Hide()
end

-- ============================================================
-- FOCUS BAR CONFIG WINDOW (separate from main config)
-- ============================================================
CreateFocusConfigWindow = function(barIndex)
    if focusConfigFrame[barIndex] then
        return
    end

    local PANEL_WIDTH = 440
    local CONTENT_WIDTH = PANEL_WIDTH - 90
    local PANEL_HEIGHT = 620

    local f = CreateFrame("Frame", "JG13_FocusConfigFrame" .. barIndex, UIParent, "BackdropTemplate")
    focusConfigFrame[barIndex] = f
    f:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    f:SetPoint("CENTER", 240 + (barIndex - 1) * 60, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")

    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    f:SetBackdropColor(UI.bg[1], UI.bg[2], UI.bg[3], UI.bg[4])
    f:SetBackdropBorderColor(UI.border[1], UI.border[2], UI.border[3], UI.border[4])

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetHeight(36)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(UI.header[1], UI.header[2], UI.header[3], UI.header[4])

    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
    titleText:SetTextColor(UI.accent[1], UI.accent[2], UI.accent[3])
    titleText:SetPoint("LEFT", 16, 0)
    titleText:SetText("Focus Bar " .. barIndex .. " Config")

    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(36, 36)
    closeBtn:SetPoint("RIGHT", 0, 0)
    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
    closeTxt:SetFont("Fonts\\FRIZQT__.TTF", 16, "")
    closeTxt:SetTextColor(UI.textDim[1], UI.textDim[2], UI.textDim[3])
    closeTxt:SetPoint("CENTER")
    closeTxt:SetText("x")
    closeBtn:SetScript("OnEnter", function() closeTxt:SetTextColor(1, 0.4, 0.4) end)
    closeBtn:SetScript("OnLeave", function() closeTxt:SetTextColor(UI.textDim[1], UI.textDim[2], UI.textDim[3]) end)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 30, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -42, 4)
    f.scrollFrame = scrollFrame

    if scrollFrame.ScrollBar then
        local sb = scrollFrame.ScrollBar
        if sb.Background then sb.Background:Hide() end
    end

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(CONTENT_WIDTH)
    scrollFrame:SetScrollChild(content)

    local yPos = -16
    local SPACING = 14
    local SECTION_SPACING = 22

    local function advanceY(amount) yPos = yPos - amount end
    local function placeWidget(widget, height)
        widget:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yPos)
        widget:SetWidth(CONTENT_WIDTH)
        advanceY((height or 42) + SPACING)
    end

    -- === FOCUS PROFILES SECTION ===
    local secProfiles = CreateSectionHeader(content, "Focus Bar " .. barIndex .. " Profiles")
    placeWidget(secProfiles, 20)

    -- Spec + layout label
    local focusSpecLabel = content:CreateFontString(nil, "OVERLAY")
    focusSpecLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    focusSpecLabel:SetTextColor(UI.text[1], UI.text[2], UI.text[3])
    focusSpecLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yPos)
    advanceY(16 + SPACING)

    local function UpdateFocusSpecLabel()
        local specName = GetCurrentSpecName()
        local layoutText = currentFocusLayoutName[barIndex] and (": " .. currentFocusLayoutName[barIndex]) or ": (none)"
        focusSpecLabel:SetText("Spec: " .. specName .. " | Focus " .. barIndex .. " Layout" .. layoutText)
    end
    UpdateFocusSpecLabel()

    -- Layout name input + Save button row
    local profileRow = CreateFrame("Frame", nil, content)
    profileRow:SetSize(CONTENT_WIDTH, 26)
    placeWidget(profileRow, 26)

    local nameBox = CreateModernEditBox(profileRow, CONTENT_WIDTH - 80, 26)
    nameBox:SetPoint("LEFT", 0, 0)
    if currentFocusLayoutName[barIndex] then
        nameBox:SetText(currentFocusLayoutName[barIndex])
    end

    local saveBtn = CreateModernButton(profileRow, "Save", 72, 26, function()
        local name = nameBox:GetText():trim()
        if name ~= "" then
            SaveFocusLayout(barIndex, name)
        end
    end)
    saveBtn:SetPoint("RIGHT", 0, 0)

    -- Load dropdown + Delete button row
    local loadRow = CreateFrame("Frame", nil, content)
    loadRow:SetSize(CONTENT_WIDTH, 26)
    placeWidget(loadRow, 26)

    local focusLayoutDropdown = CreateFrame("DropdownButton", nil, loadRow, "WowStyle1DropdownTemplate")
    focusLayoutDropdown:SetPoint("LEFT", 0, 0)
    focusLayoutDropdown:SetWidth(CONTENT_WIDTH - 80)
    focusLayoutDropdown:SetDefaultText(currentFocusLayoutName[barIndex] or "Select a focus layout...")

    focusLayoutDropdown:SetupMenu(function(_, rootDescription)
        local names = GetSortedFocusLayoutNames(barIndex)
        if #names == 0 then
            rootDescription:CreateTitle("No saved focus layouts")
            return
        end
        for _, name in ipairs(names) do
            rootDescription:CreateButton(name, function()
                LoadFocusLayout(barIndex, name)
            end)
        end
    end)

    local deleteBtn = CreateModernButton(loadRow, "Delete", 72, 26, function()
        local name = nameBox:GetText():trim()
        if name ~= "" then
            DeleteFocusLayout(barIndex, name)
        end
    end)
    deleteBtn:SetPoint("RIGHT", 0, 0)

    -- === SETTINGS SECTION ===
    advanceY(SECTION_SPACING - SPACING)
    local secSettings = CreateSectionHeader(content, "Settings")
    placeWidget(secSettings, 20)

    local focusCfg = GetOrCreateFocusRowConfig(barIndex)

    -- Enable toggle
    local focusEnableCheck = CreateModernCheck(content, "Enable Focus Bar", focusCfg.enabled, function(val)
        activeFocusProfile[barIndex].enabled = val
        PersistActiveFocusProfile(barIndex)
        BuildFocusRow(barIndex)
    end)
    placeWidget(focusEnableCheck, 22)

    -- Orientation toggle (Horizontal / Vertical)
    local orientRow = CreateFrame("Frame", nil, content)
    orientRow:SetSize(CONTENT_WIDTH, 24)

    local orientLabel = orientRow:CreateFontString(nil, "OVERLAY")
    orientLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    orientLabel:SetTextColor(UI.text[1], UI.text[2], UI.text[3])
    orientLabel:SetPoint("LEFT", 0, 0)
    orientLabel:SetText("Orientation:")

    local hBtn = CreateModernButton(orientRow, "Horizontal", 90, 22, nil)
    hBtn:SetPoint("LEFT", orientLabel, "RIGHT", 8, 0)
    local vBtn = CreateModernButton(orientRow, "Vertical", 80, 22, nil)
    vBtn:SetPoint("LEFT", hBtn, "RIGHT", 4, 0)

    local function UpdateOrientBtnColors()
        local cur = activeFocusProfile[barIndex].orientation or "horizontal"
        if cur == "horizontal" then
            hBtn.label:SetTextColor(UI.accent[1], UI.accent[2], UI.accent[3])
            hBtn.bg:SetColorTexture(UI.accentDim[1], UI.accentDim[2], UI.accentDim[3], 0.4)
            vBtn.label:SetTextColor(UI.textDim[1], UI.textDim[2], UI.textDim[3])
            vBtn.bg:SetColorTexture(UI.btnNormal[1], UI.btnNormal[2], UI.btnNormal[3], UI.btnNormal[4])
        else
            hBtn.label:SetTextColor(UI.textDim[1], UI.textDim[2], UI.textDim[3])
            hBtn.bg:SetColorTexture(UI.btnNormal[1], UI.btnNormal[2], UI.btnNormal[3], UI.btnNormal[4])
            vBtn.label:SetTextColor(UI.accent[1], UI.accent[2], UI.accent[3])
            vBtn.bg:SetColorTexture(UI.accentDim[1], UI.accentDim[2], UI.accentDim[3], 0.4)
        end
    end
    UpdateOrientBtnColors()

    hBtn:SetScript("OnClick", function()
        activeFocusProfile[barIndex].orientation = "horizontal"
        PersistActiveFocusProfile(barIndex)
        BuildFocusRow(barIndex)
        UpdateOrientBtnColors()
    end)
    vBtn:SetScript("OnClick", function()
        activeFocusProfile[barIndex].orientation = "vertical"
        PersistActiveFocusProfile(barIndex)
        BuildFocusRow(barIndex)
        UpdateOrientBtnColors()
    end)

    placeWidget(orientRow, 24)

    -- Button size slider (24-120)
    local focusSizeSlider = CreateModernSlider(content, "JG13_FocusSizeSlider" .. barIndex, "Button Size",
        24, 120, focusCfg.buttonSize or 40, 2, CONTENT_WIDTH,
        function(v) return tostring(math.floor(v)) .. "px" end,
        function(val)
            activeFocusProfile[barIndex].buttonSize = val
            PersistActiveFocusProfile(barIndex)
            BuildFocusRowDebounced(barIndex)
        end)
    placeWidget(focusSizeSlider, 42)

    -- Button padding slider (0-20)
    local focusPadSlider = CreateModernSlider(content, "JG13_FocusPadSlider" .. barIndex, "Button Padding",
        0, 20, focusCfg.padding or 4, 1, CONTENT_WIDTH,
        function(v) return tostring(math.floor(v)) .. "px" end,
        function(val)
            activeFocusProfile[barIndex].padding = val
            PersistActiveFocusProfile(barIndex)
            BuildFocusRowDebounced(barIndex)
        end)
    placeWidget(focusPadSlider, 42)

    -- Background opacity slider
    local focusBgSlider = CreateModernSlider(content, "JG13_FocusBgSlider" .. barIndex, "Background Opacity",
        0, 1, focusCfg.bgOpacity or 0.3, 0.05, CONTENT_WIDTH,
        function(v) return string.format("%.0f%%", v * 100) end,
        function(val)
            activeFocusProfile[barIndex].bgOpacity = val
            PersistActiveFocusProfile(barIndex)
            if focusRowFrame[barIndex] and focusRowFrame[barIndex].bg then
                focusRowFrame[barIndex].bg:SetColorTexture(0, 0, 0, val)
            end
        end)
    placeWidget(focusBgSlider, 42)

    -- Lock/Unlock toggle
    local focusLockCheck = CreateModernCheck(content, "Lock Position", focusCfg.locked ~= false, function(val)
        activeFocusProfile[barIndex].locked = val
        PersistActiveFocusProfile(barIndex)
        -- Rebuild to add/remove nudge buttons
        BuildFocusRow(barIndex)
    end)
    placeWidget(focusLockCheck, 22)

    -- Non-interactive toggle
    local focusNonInterCheck = CreateModernCheck(content, "Non-Interactive (display only)", focusCfg.nonInteractive or false, function(val)
        activeFocusProfile[barIndex].nonInteractive = val
        PersistActiveFocusProfile(barIndex)
        BuildFocusRow(barIndex)
    end)
    placeWidget(focusNonInterCheck, 22)

    -- Combat-only toggle
    local focusCombatCheck = CreateModernCheck(content, "Only Show In Combat", focusCfg.combatOnly or false, function(val)
        activeFocusProfile[barIndex].combatOnly = val
        PersistActiveFocusProfile(barIndex)
        BuildFocusRow(barIndex)
    end)
    placeWidget(focusCombatCheck, 22)

    -- === SLOTS SECTION ===
    advanceY(SECTION_SPACING - SPACING)
    local secSlots = CreateSectionHeader(content, "Action Slots")
    placeWidget(secSlots, 20)

    local slotLabel = content:CreateFontString(nil, "OVERLAY")
    slotLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    slotLabel:SetTextColor(UI.text[1], UI.text[2], UI.text[3])
    slotLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yPos)
    slotLabel:SetText("Action Slots (1-180):")
    advanceY(18)

    -- Existing slot rows
    for i, slotID in ipairs(focusCfg.slots) do
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(CONTENT_WIDTH, 26)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yPos)

        local idx = i

        local slotBox = CreateModernEditBox(row, 60, 24)
        slotBox:SetPoint("LEFT", 0, 0)
        slotBox:SetText(tostring(slotID))
        slotBox:SetScript("OnEnterPressed", function(self)
            local val = tonumber(self:GetText())
            if val and val >= 1 and val <= 180 then
                activeFocusProfile[barIndex].slots[idx] = math.floor(val)
                PersistActiveFocusProfile(barIndex)
                BuildFocusRow(barIndex)
            else
                self:SetText(tostring(activeFocusProfile[barIndex].slots[idx]))
            end
            self:ClearFocus()
        end)

        local removeBtn = CreateModernButton(row, "x", 24, 22, function()
            table.remove(activeFocusProfile[barIndex].slots, idx)
            PersistActiveFocusProfile(barIndex)
            BuildFocusRow(barIndex)
            if RefreshFocusConfigUI[barIndex] then RefreshFocusConfigUI[barIndex](true) end
        end)
        removeBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)

        if i > 1 then
            local upBtn = CreateModernButton(row, "^", 24, 22, function()
                activeFocusProfile[barIndex].slots[idx], activeFocusProfile[barIndex].slots[idx - 1] = activeFocusProfile[barIndex].slots[idx - 1], activeFocusProfile[barIndex].slots[idx]
                PersistActiveFocusProfile(barIndex)
                BuildFocusRow(barIndex)
                if RefreshFocusConfigUI[barIndex] then RefreshFocusConfigUI[barIndex](true) end
            end)
            upBtn:SetPoint("RIGHT", removeBtn, "LEFT", -4, 0)
        end

        local slotDesc = row:CreateFontString(nil, "OVERLAY")
        slotDesc:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
        slotDesc:SetTextColor(UI.textDim[1], UI.textDim[2], UI.textDim[3])
        slotDesc:SetPoint("LEFT", slotBox, "RIGHT", 8, 0)
        slotDesc:SetPoint("RIGHT", removeBtn, "LEFT", -56, 0)
        slotDesc:SetJustifyH("LEFT")
        slotDesc:SetWordWrap(false)
        local barNum = math.ceil(slotID / 12)
        local btnNum = ((slotID - 1) % 12) + 1
        slotDesc:SetText("Bar " .. barNum .. " Btn " .. btnNum)

        advanceY(28)
    end

    -- Add slot button (max 8)
    if #focusCfg.slots < 8 then
        local addSlotBtn = CreateModernButton(content, "+ Add Slot", 120, 26, function()
            table.insert(activeFocusProfile[barIndex].slots, 1)
            PersistActiveFocusProfile(barIndex)
            BuildFocusRow(barIndex)
            if RefreshFocusConfigUI[barIndex] then RefreshFocusConfigUI[barIndex](true) end
        end)
        placeWidget(addSlotBtn, 26)
    end

    -- === ACTIONS SECTION ===
    advanceY(SECTION_SPACING - SPACING)
    local secActions = CreateSectionHeader(content, "Actions")
    placeWidget(secActions, 20)

    local resetFocusBtn = CreateModernButton(content, "Reset to Defaults", 160, 30, function()
        activeFocusProfile[barIndex] = CreateDefaultFocusProfile()
        currentFocusLayoutName[barIndex] = nil
        local _, _, lastActiveKey = GetFocusDBTables(barIndex)
        JarsG13BarsCharDB[lastActiveKey] = nil
        PersistActiveFocusProfile(barIndex)
        BuildFocusRow(barIndex)
        if RefreshFocusConfigUI[barIndex] then RefreshFocusConfigUI[barIndex](true) end
        print("|cff00ff00Jar's G13 Bars|r: Focus bar " .. barIndex .. " reset to defaults.")
    end)
    placeWidget(resetFocusBtn, 30)

    -- Set total content height
    content:SetHeight(math.abs(yPos) + 20)

    -- Make frame close with Escape
    tinsert(UISpecialFrames, "JG13_FocusConfigFrame" .. barIndex)

    -- Refresh function
    RefreshFocusConfigUI[barIndex] = function(rebuild)
        if rebuild then
            local wasShown = f:IsShown()
            local point, rel, relPoint, cx, cy = f:GetPoint(1)
            local savedScroll = scrollFrame:GetVerticalScroll()
            f:Hide()
            focusConfigFrame[barIndex] = nil
            CreateFocusConfigWindow(barIndex)
            f = focusConfigFrame[barIndex]
            if f and point then
                f:ClearAllPoints()
                f:SetPoint(point, rel, relPoint, cx, cy)
            end
            if wasShown and f then f:Show() end
            -- Restore scroll position after layout settles
            C_Timer.After(0, function()
                if focusConfigFrame[barIndex] then
                    local sf = focusConfigFrame[barIndex].scrollFrame
                    if sf then sf:SetVerticalScroll(savedScroll) end
                end
            end)
            return
        end
        focusEnableCheck:SetChecked(activeFocusProfile[barIndex].enabled or false)
        focusSizeSlider.slider:SetValue(activeFocusProfile[barIndex].buttonSize or 40)
        focusPadSlider.slider:SetValue(activeFocusProfile[barIndex].padding or 4)
        focusBgSlider.slider:SetValue(activeFocusProfile[barIndex].bgOpacity or 0.3)
        focusLockCheck:SetChecked(activeFocusProfile[barIndex].locked ~= false)
        focusNonInterCheck:SetChecked(activeFocusProfile[barIndex].nonInteractive or false)
        focusCombatCheck:SetChecked(activeFocusProfile[barIndex].combatOnly or false)
        UpdateOrientBtnColors()
        nameBox:SetText(currentFocusLayoutName[barIndex] or "")
        focusLayoutDropdown:GenerateMenu()
        focusLayoutDropdown:SetDefaultText(currentFocusLayoutName[barIndex] or "Select a focus layout...")
        UpdateFocusSpecLabel()
    end

    f:Hide()
end

-- Slash command
SLASH_JG131 = "/jg13"
SLASH_JG132 = "/jg13bind"
SlashCmdList["JG13"] = function(msg)
    -- keep the raw text so layout names keep their case
    local raw = msg:trim()
    msg = raw:lower()

    if msg == "bind" or msg == "keybind" or msg == "kb" then
        if LibKeyBound then
            LibKeyBound:Toggle()
            if LibKeyBound:IsShown() then
                print("|cff00ff00Jar's G13 Bars|r: Keybind mode enabled. Hover over a button and press a key.")
            else
                print("|cff00ff00Jar's G13 Bars|r: Keybind mode disabled.")
            end
        end
        return
    end

    if msg:sub(1, 5) == "save " then
        local name = raw:sub(6):trim()
        SaveLayout(name)
        return
    end

    if msg:sub(1, 5) == "load " then
        local name = raw:sub(6):trim()
        LoadLayout(name)
        return
    end

    if msg:sub(1, 7) == "delete " then
        local name = raw:sub(8):trim()
        DeleteLayout(name)
        return
    end

    if msg == "layouts" or msg == "list" then
        local names = GetSortedLayoutNames()
        if #names == 0 then
            print("|cff00ff00Jar's G13 Bars|r: No saved layouts.")
        else
            print("|cff00ff00Jar's G13 Bars|r: Saved layouts:")
            for _, name in ipairs(names) do
                local marker = (name == currentLayoutName) and " |cff00ffff(active)|r" or ""
                print("  - " .. name .. marker)
            end
        end
        return
    end

    -- Toggle config window
    configFrame:SetShown(not configFrame:IsShown())
end

-- entry point for JarsAddonConfig
function JarsG13Bars_OpenConfig()
    if configFrame then configFrame:Show() end
end
