-- Jar's G13 Action Bars for WoW 12.0.1
-- Custom action bar layout for Logitech G13 gaming keypad

-- Saved variables
JarsG13BarsDB = JarsG13BarsDB or {}

-- Libraries
local LibKeyBound = LibStub("LibKeyBound-1.0")

-- Configuration
local PRIMARY_SIZE = 80      -- 100% size for 3x2 grid
local SIDE_SIZE = 52         -- 66% of primary (0.66 * 80 = 52.8 ≈ 52)
local BOTTOM_SIZE = 40       -- 50% of primary (doubled from 20)
local PADDING = 6            -- Padding between buttons
local SNAP_DISTANCE = 20     -- Distance to snap to center

-- Frame references
local mainFrame
local buttons = {}
local UIHider -- Hidden frame for hiding Blizzard bars
local updateThrottle = 0 -- Throttle for ActionButton updates

-- Initialize saved variables
local function InitDB()
    if not JarsG13BarsDB then
        JarsG13BarsDB = {}
    end
    
    if not JarsG13BarsDB.position then
        JarsG13BarsDB.position = { y = -400 }  -- Default lower on screen
    end
    
    -- Ensure Y value exists
    if not JarsG13BarsDB.position.y then
        JarsG13BarsDB.position.y = -400
    end
    
    -- Default background opacity
    if not JarsG13BarsDB.bgOpacity then
        JarsG13BarsDB.bgOpacity = 0.3
    end
    
    -- Default show keybinds setting
    if JarsG13BarsDB.showKeybinds == nil then
        JarsG13BarsDB.showKeybinds = true
    end
    
    -- Default scale
    if not JarsG13BarsDB.scale then
        JarsG13BarsDB.scale = 1.0  -- 100%
    end
    
    -- Default hide bars settings (hide all by default)
    if not JarsG13BarsDB.hideBars then
        JarsG13BarsDB.hideBars = {
            MainMenuBar = true,
            MainActionBar = true,  -- New in 12.0+
            MultiBarBottomLeft = true,
            MultiBarBottomRight = true,
            MultiBarRight = true,
            MultiBarLeft = true,
            MultiBar5 = true,
            MultiBar6 = true,
            MultiBar7 = true,
        }
    end
end

-- Hide default action bars
local function HideDefaultBars()
    -- Create hidden parent frame if it doesn't exist
    if not UIHider then
        UIHider = CreateFrame("Frame")
        UIHider:Hide()
    end
    
    -- Configurable action bars
    local configurableBars = {
        "MainMenuBar",        -- <= 11.2.5
        "MainActionBar",      -- >= 12.0
        "MultiBarBottomLeft", 
        "MultiBarBottomRight",
        "MultiBarRight",
        "MultiBarLeft",
        "MultiBar5",
        "MultiBar6", 
        "MultiBar7",
    }
    
    for _, barName in ipairs(configurableBars) do
        local bar = _G[barName]
        if bar then
            local shouldHide = JarsG13BarsDB.hideBars[barName]
            if shouldHide then
                -- Unregister events that force the bar to show
                if barName == "MainMenuBar" or barName == "MainActionBar" then
                    if bar.UnregisterEvent then
                        pcall(function()
                            bar:UnregisterEvent("PLAYER_REGEN_ENABLED")
                            bar:UnregisterEvent("PLAYER_REGEN_DISABLED")
                            bar:UnregisterEvent("ACTIONBAR_SHOWGRID")
                            bar:UnregisterEvent("ACTIONBAR_HIDEGRID")
                        end)
                    end
                end
                
                -- Purge EditMode state
                if bar.system then
                    bar.isShownExternal = nil
                end
                
                -- Use HideBase if available (EditMode override)
                if bar.HideBase then
                    bar:HideBase()
                else
                    bar:Hide()
                end
                
                -- Set parent to hidden frame to keep it hidden
                bar:SetParent(UIHider)
                
                -- Hide individual buttons for this bar
                if barName == "MainMenuBar" or barName == "MainActionBar" then
                    for i = 1, 12 do
                        local button = _G["ActionButton" .. i]
                        if button then
                            button:Hide()
                            button:SetAttribute("statehidden", true)
                        end
                    end
                elseif barName == "MultiBarBottomLeft" then
                    for i = 1, 12 do
                        local button = _G["MultiBarBottomLeftButton" .. i]
                        if button then
                            button:Hide()
                            button:SetAttribute("statehidden", true)
                        end
                    end
                elseif barName == "MultiBarBottomRight" then
                    for i = 1, 12 do
                        local button = _G["MultiBarBottomRightButton" .. i]
                        if button then
                            button:Hide()
                            button:SetAttribute("statehidden", true)
                        end
                    end
                elseif barName == "MultiBarRight" then
                    for i = 1, 12 do
                        local button = _G["MultiBarRightButton" .. i]
                        if button then
                            button:Hide()
                            button:SetAttribute("statehidden", true)
                        end
                    end
                elseif barName == "MultiBarLeft" then
                    for i = 1, 12 do
                        local button = _G["MultiBarLeftButton" .. i]
                        if button then
                            button:Hide()
                            button:SetAttribute("statehidden", true)
                        end
                    end
                elseif barName == "MultiBar5" then
                    for i = 1, 12 do
                        local button = _G["MultiBar5Button" .. i]
                        if button then
                            button:Hide()
                            button:SetAttribute("statehidden", true)
                        end
                    end
                elseif barName == "MultiBar6" then
                    for i = 1, 12 do
                        local button = _G["MultiBar6Button" .. i]
                        if button then
                            button:Hide()
                            button:SetAttribute("statehidden", true)
                        end
                    end
                elseif barName == "MultiBar7" then
                    for i = 1, 12 do
                        local button = _G["MultiBar7Button" .. i]
                        if button then
                            button:Hide()
                            button:SetAttribute("statehidden", true)
                        end
                    end
                end
            else
                -- Show the bar - restore parent and re-register events
                if barName == "MainMenuBar" or barName == "MainActionBar" then
                    if bar.RegisterEvent then
                        pcall(function()
                            bar:RegisterEvent("PLAYER_REGEN_ENABLED")
                            bar:RegisterEvent("PLAYER_REGEN_DISABLED")
                            bar:RegisterEvent("ACTIONBAR_SHOWGRID")
                            bar:RegisterEvent("ACTIONBAR_HIDEGRID")
                        end)
                    end
                end
                
                -- Restore parent
                bar:SetParent(UIParent)
                
                -- Use ShowBase if available (EditMode override)
                if bar.ShowBase then
                    bar:ShowBase()
                else
                    bar:Show()
                end
                
                -- Show individual buttons
                if barName == "MainMenuBar" or barName == "MainActionBar" then
                    for i = 1, 12 do
                        local button = _G["ActionButton" .. i]
                        if button then
                            button:SetAttribute("statehidden", false)
                            button:Show()
                        end
                    end
                end
            end
        end
    end
end

-- Function to update keybind visibility
local function UpdateKeybinds()
    local show = JarsG13BarsDB.showKeybinds
    for i = 1, 24 do
        local button = _G["JG13_Button" .. i]
        if button then
            -- Update hotkey text from keybindings
            if button.HotKey then
                local command
                if i <= 12 then
                    command = "ACTIONBUTTON" .. i
                elseif i <= 24 then
                    command = "MULTIACTIONBAR1BUTTON" .. (i - 12)
                end
                
                if command then
                    local key = GetBindingKey(command)
                    if key then
                        button.HotKey:SetText(GetBindingText(key, "KEY_", 1))
                    else
                        button.HotKey:SetText("")
                    end
                end
            end
            -- Show or hide the hotkey
            if button.HotKey then
                if show then
                    button.HotKey:Show()
                else
                    button.HotKey:Hide()
                end
            end
        end
    end
end

-- Function to setup override bindings
local function UpdateOverrideBindings()
    if InCombatLockdown() or not mainFrame then return end
    
    ClearOverrideBindings(mainFrame)
    
    for i = 1, 24 do
        local button = _G["JG13_Button" .. i]
        if button then
            local command
            if i <= 12 then
                command = "ACTIONBUTTON" .. i
            elseif i <= 24 then
                command = "MULTIACTIONBAR1BUTTON" .. (i - 12)
            end
            
            if command then
                for k = 1, select("#", GetBindingKey(command)) do
                    local key = select(k, GetBindingKey(command))
                    if key and key ~= "" then
                        -- Use "Keybind" as the mouse button for keybind clicks
                        SetOverrideBindingClick(mainFrame, false, key, button:GetName(), "Keybind")
                    end
                end
            end
        end
    end
end

-- Create a single action button
local function CreateActionButton(parent, index, size)
    local button = CreateFrame("CheckButton", "JG13_Button" .. index, parent, "ActionBarButtonTemplate")
    button:SetSize(size, size)
    button.action = index
    
    -- Setup action button
    button:SetAttribute("type", "action")
    button:SetAttribute("action", index)
    
    -- Register for clicks - "Keybind" is a virtual button used by SetOverrideBindingClick
    button:RegisterForClicks("AnyUp")
    
    -- Set commandName for keybind lookup
    if index <= 12 then
        -- Buttons 1-12: Main Action Bar
        button:SetAttribute("commandName", "ACTIONBUTTON" .. index)
    elseif index <= 24 then
        -- Buttons 13-24: MultiActionBar1 (Right Bar 2 / Bar 6)
        button:SetAttribute("commandName", "MULTIACTIONBAR1BUTTON" .. (index - 12))
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
        if fontFace then
            button.Count:SetFont(fontFace, math.max(24, size * 0.7), fontFlags or "OUTLINE")
        end
    end
    
    -- Hotkey text - Keep small
    if button.HotKey then
        local fontFace, _, fontFlags = button.HotKey:GetFont()
        if fontFace then
            button.HotKey:SetFont(fontFace, math.max(8, size * 0.2), fontFlags)
        end
    end
    
    -- LibKeyBound support for keybinding
    button.GetBindingAction = function(self)
        if self.action and self.action <= 12 then
            return "ACTIONBUTTON" .. self.action
        elseif self.action and self.action <= 24 then
            return "MULTIACTIONBAR1BUTTON" .. (self.action - 12)
        end
        return nil
    end
    
    button.GetHotkey = function(self)
        local action = self:GetBindingAction()
        if not action then
            return ""
        end
        local key = GetBindingKey(action)
        if key then
            return GetBindingText(key, "KEY_", 1)
        end
        return ""
    end
    
    button.GetActionName = function(self)
        if self.action and self.action <= 12 then
            return "Action Button " .. self.action
        elseif self.action and self.action <= 24 then
            return "Bar 6 Button " .. (self.action - 12)
        end
        return "Button " .. (self.action or "?")
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

-- Create the main frame with all buttons
-- Create the main frame with all buttons
local function CreateMainFrame()
    local frame = CreateFrame("Frame", "JG13_MainFrame", UIParent)
    frame:SetMovable(false)
    frame:EnableMouse(false)
    
    -- Calculate frame size
    local primaryWidth = (PRIMARY_SIZE * 3) + (PADDING * 2)
    local primaryHeight = (PRIMARY_SIZE * 2) + PADDING
    local sideWidth = (SIDE_SIZE * 2) + PADDING
    local sideHeight = (SIDE_SIZE * 3) + (PADDING * 2)
    local bottomWidth = (BOTTOM_SIZE * 6) + (PADDING * 5)
    local bottomHeight = BOTTOM_SIZE
    
    local totalWidth = sideWidth + PADDING + primaryWidth + PADDING + sideWidth
    local totalHeight = primaryHeight + PADDING + bottomHeight
    
    frame:SetSize(totalWidth, totalHeight)
    
    -- Set scale
    frame:SetScale(JarsG13BarsDB.scale or 1.0)
    
    -- Set position - always centered horizontally, Y from saved variables
    local pos = JarsG13BarsDB.position
    frame:ClearAllPoints()
    frame:SetPoint("TOP", UIParent, "TOP", 0, pos.y)
    
    -- Background (for visibility during setup)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, JarsG13BarsDB.bgOpacity or 0.3)
    
    -- Create buttons
    local buttonIndex = 1
    
    -- LEFT SIDE: Action Bar 2 (slots 13-18) - 2x3 grid at 66% size
    for row = 0, 2 do
        for col = 0, 1 do
            local btn = CreateActionButton(frame, 12 + buttonIndex, SIDE_SIZE)
            local xPos = col * (SIDE_SIZE + PADDING)
            local yPos = -row * (SIDE_SIZE + PADDING)
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", xPos, yPos)
            buttons[12 + buttonIndex] = btn
            buttonIndex = buttonIndex + 1
        end
    end
    
    -- PRIMARY CENTER: Action Bar 1 (slots 1-6) - 3x2 grid at 100% size
    local primaryOffsetX = sideWidth + PADDING
    buttonIndex = 1
    for row = 0, 1 do
        for col = 0, 2 do
            local btn = CreateActionButton(frame, buttonIndex, PRIMARY_SIZE)
            local xPos = primaryOffsetX + col * (PRIMARY_SIZE + PADDING)
            local yPos = -row * (PRIMARY_SIZE + PADDING)
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", xPos, yPos)
            buttons[buttonIndex] = btn
            buttonIndex = buttonIndex + 1
        end
    end
    
    -- RIGHT SIDE: Action Bar 2 (slots 19-24) - 2x3 grid at 66% size
    local rightOffsetX = primaryOffsetX + primaryWidth + PADDING
    buttonIndex = 7
    for row = 0, 2 do
        for col = 0, 1 do
            local btn = CreateActionButton(frame, 12 + buttonIndex, SIDE_SIZE)
            local xPos = rightOffsetX + col * (SIDE_SIZE + PADDING)
            local yPos = -row * (SIDE_SIZE + PADDING)
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", xPos, yPos)
            buttons[12 + buttonIndex] = btn
            buttonIndex = buttonIndex + 1
        end
    end
    
    -- BOTTOM: Action Bar 1 (slots 7-12) - 6x1 grid at 25% size
    local bottomOffsetY = -(primaryHeight + PADDING)
    local bottomOffsetX = primaryOffsetX + (primaryWidth / 2) - (bottomWidth / 2)
    buttonIndex = 7
    for col = 0, 5 do
        local btn = CreateActionButton(frame, buttonIndex, BOTTOM_SIZE)
        local xPos = bottomOffsetX + col * (BOTTOM_SIZE + PADDING)
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", xPos, bottomOffsetY)
        buttons[buttonIndex] = btn
        buttonIndex = buttonIndex + 1
    end
    
    return frame
end

-- Update all buttons
local function UpdateButtons()
    for i, button in pairs(buttons) do
        if button and button.action then
            -- Use protected functions safely
            if ActionButton_Update then
                pcall(ActionButton_Update, button)
            end
            if ActionButton_UpdateHotkeys then
                pcall(ActionButton_UpdateHotkeys, button)
            end
            if ActionButton_UpdateCooldown then
                pcall(ActionButton_UpdateCooldown, button)
            end
            if ActionButton_UpdateUsable then
                pcall(ActionButton_UpdateUsable, button)
            end
            if ActionButton_UpdateCount then
                pcall(ActionButton_UpdateCount, button)
            end
            if ActionButton_UpdateState then
                pcall(ActionButton_UpdateState, button)
            end
        end
    end
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
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTER_COMBAT")
eventFrame:RegisterEvent("PLAYER_LEAVE_COMBAT")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "JarsG13Bars" then
            InitDB()
            HideDefaultBars()
            mainFrame = CreateMainFrame()
            
            print("DEBUG: About to call CreateConfigWindow()")
            CreateConfigWindow()
            print("DEBUG: CreateConfigWindow() returned, frame is:", _G["JG13_ConfigFrame"])
            
            -- Setup override bindings and update keybinds after a delay to ensure buttons are ready
            C_Timer.After(1, function()
                UpdateOverrideBindings()
                UpdateKeybinds()
            end)
            
            print("|cff00ff00Jar's G13 Action Bars|r loaded. Type |cff00ffff/jg13|r to configure.")
            
            self:UnregisterEvent("ADDON_LOADED")
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        HideDefaultBars()
        C_Timer.After(0.5, UpdateButtons)
        
    elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" then
        -- Full update when actions change (no throttle)
        UpdateButtons()
        
    elseif event == "ACTIONBAR_UPDATE_COOLDOWN" then
        -- Throttle cooldown updates to once per second
        local now = GetTime()
        if now - updateThrottle >= 1.0 then
            updateThrottle = now
            for i, button in pairs(buttons) do
                if button and button.action and ActionButton_UpdateCooldown then
                    pcall(ActionButton_UpdateCooldown, button)
                end
            end
        end
        
    elseif event == "ACTIONBAR_UPDATE_USABLE" or event == "SPELL_UPDATE_USABLE" then
        -- Throttle usability updates to once per second
        local now = GetTime()
        if now - updateThrottle >= 1.0 then
            updateThrottle = now
            for i, button in pairs(buttons) do
                if button and button.action and ActionButton_UpdateUsable then
                    pcall(ActionButton_UpdateUsable, button)
                end
            end
        end
        
    elseif event == "ACTIONBAR_UPDATE_STATE" then
        -- Update button state (pushed/checked)
        for i, button in pairs(buttons) do
            if button and button.action and ActionButton_UpdateState then
                pcall(ActionButton_UpdateState, button)
            end
        end
        
    elseif event == "SPELL_UPDATE_CHARGES" then
        -- Update charge counts
        for i, button in pairs(buttons) do
            if button and button.action and ActionButton_UpdateCount then
                pcall(ActionButton_UpdateCount, button)
            end
        end
        
    elseif event == "PLAYER_TARGET_CHANGED" or 
           event == "PLAYER_ENTER_COMBAT" or 
           event == "PLAYER_LEAVE_COMBAT" then
        -- These events are infrequent, safe to update
        UpdateButtons()
    end
end)

-- Function to update main frame position
local function UpdateFramePosition(yOffset)
    if mainFrame then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("TOP", UIParent, "TOP", 0, yOffset)
        JarsG13BarsDB.position.y = yOffset
    end
end

-- Function to update background opacity
local function UpdateBackgroundOpacity(opacity)
    if mainFrame and mainFrame.bg then
        mainFrame.bg:SetColorTexture(0, 0, 0, opacity)
        JarsG13BarsDB.bgOpacity = opacity
    end
end

-- Function to update frame scale
local function UpdateScale(scale)
    if mainFrame then
        mainFrame:SetScale(scale)
        JarsG13BarsDB.scale = scale
    end
end

-- Create config window
local configFrame
CreateConfigWindow = function()
    if configFrame then
        return
    end
    
    configFrame = CreateFrame("Frame", "JG13_ConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    configFrame:SetSize(400, 680)
    configFrame:SetPoint("CENTER")
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    configFrame:SetFrameStrata("DIALOG")
    
    configFrame.title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    configFrame.title:SetPoint("TOP", configFrame, "TOP", 0, -5)
    configFrame.title:SetText("Jar's G13 Bars Configuration")
    
    -- Position label
    local posLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    posLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 20, -40)
    posLabel:SetText("Vertical Position:")
    
    -- Position slider
    local posSlider = CreateFrame("Slider", "JG13_PositionSlider", configFrame, "OptionsSliderTemplate")
    posSlider:SetPoint("TOPLEFT", posLabel, "BOTTOMLEFT", 0, -20)
    posSlider:SetMinMaxValues(-1200, 0)
    posSlider:SetValue(JarsG13BarsDB.position.y)
    posSlider:SetValueStep(1)
    posSlider:SetObeyStepOnDrag(true)
    posSlider:SetWidth(350)
    
    -- Slider text
    posSlider.Low:SetText("Bottom")
    posSlider.High:SetText("Top")
    posSlider.Text:SetText(JarsG13BarsDB.position.y)
    
    posSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        self.Text:SetText(value)
        UpdateFramePosition(value)
    end)
    
    -- Background opacity label
    local opacityLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    opacityLabel:SetPoint("TOPLEFT", posSlider, "BOTTOMLEFT", 0, -30)
    opacityLabel:SetText("Background Opacity:")
    
    -- Opacity slider
    local opacitySlider = CreateFrame("Slider", "JG13_OpacitySlider", configFrame, "OptionsSliderTemplate")
    opacitySlider:SetPoint("TOPLEFT", opacityLabel, "BOTTOMLEFT", 0, -20)
    opacitySlider:SetMinMaxValues(0, 1)
    opacitySlider:SetValue(JarsG13BarsDB.bgOpacity or 0.3)
    opacitySlider:SetValueStep(0.05)
    opacitySlider:SetObeyStepOnDrag(true)
    opacitySlider:SetWidth(350)
    
    -- Opacity slider text
    opacitySlider.Low:SetText("Transparent")
    opacitySlider.High:SetText("Opaque")
    opacitySlider.Text:SetText(string.format("%.0f%%", (JarsG13BarsDB.bgOpacity or 0.3) * 100))
    
    opacitySlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 0.05 + 0.5) * 0.05  -- Round to nearest 0.05
        self.Text:SetText(string.format("%.0f%%", value * 100))
        UpdateBackgroundOpacity(value)
    end)
    
    -- Scale label
    local scaleLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", opacitySlider, "BOTTOMLEFT", 0, -40)
    scaleLabel:SetText("Scale:")
    
    -- Scale slider
    local scaleSlider = CreateFrame("Slider", "JG13_ScaleSlider", configFrame, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 0, -20)
    scaleSlider:SetMinMaxValues(0.5, 1.0)
    scaleSlider:SetValue(JarsG13BarsDB.scale or 1.0)
    scaleSlider:SetValueStep(0.05)
    scaleSlider:SetObeyStepOnDrag(true)
    scaleSlider:SetWidth(350)
    
    -- Scale slider text
    scaleSlider.Low:SetText("50%")
    scaleSlider.High:SetText("100%")
    scaleSlider.Text:SetText(string.format("%.0f%%", (JarsG13BarsDB.scale or 1.0) * 100))
    
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 0.05 + 0.5) * 0.05  -- Round to nearest 0.05
        self.Text:SetText(string.format("%.0f%%", value * 100))
        UpdateScale(value)
    end)
    
    -- Reset button
    local resetBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    resetBtn:SetSize(150, 25)
    resetBtn:SetPoint("TOP", scaleSlider, "BOTTOM", 0, -30)
    resetBtn:SetText("Reset to Default")
    resetBtn:SetScript("OnClick", function()
        posSlider:SetValue(-400)
        opacitySlider:SetValue(0.3)
        scaleSlider:SetValue(1.0)
        UpdateFramePosition(-400)
        UpdateBackgroundOpacity(0.3)
        UpdateScale(1.0)
        print("|cff00ff00Jar's G13 Bars|r: Settings reset to default.")
    end)
    
    -- Set Keybinds button
    local keybindBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    keybindBtn:SetSize(150, 25)
    keybindBtn:SetPoint("TOP", resetBtn, "BOTTOM", 0, -10)
    keybindBtn:SetText("Set Keybinds")
    keybindBtn:SetScript("OnClick", function()
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
    
    -- Update button text when LibKeyBound state changes
    LibKeyBound.RegisterCallback(keybindBtn, "LIBKEYBOUND_ENABLED", function()
        keybindBtn:SetText("Exit Keybind Mode")
    end)
    LibKeyBound.RegisterCallback(keybindBtn, "LIBKEYBOUND_DISABLED", function()
        keybindBtn:SetText("Set Keybinds")
    end)
    
    -- Action Bar Hide Checkboxes
    -- Show Keybinds checkbox
    local keybindsCheck = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
    keybindsCheck:SetPoint("TOPLEFT", keybindBtn, "BOTTOMLEFT", -110, -10)
    keybindsCheck.text = keybindsCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    keybindsCheck.text:SetPoint("LEFT", keybindsCheck, "RIGHT", 5, 0)
    keybindsCheck.text:SetText("Show Keybinds")
    keybindsCheck:SetChecked(JarsG13BarsDB.showKeybinds)
    keybindsCheck:SetScript("OnClick", function(self)
        JarsG13BarsDB.showKeybinds = self:GetChecked()
        UpdateKeybinds()
    end)
    
    local barLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    barLabel:SetPoint("TOPLEFT", keybindsCheck, "BOTTOMLEFT", 20, -20)
    barLabel:SetText("Hide Blizzard Action Bars:")
    
    local barNames = {
        {key = "MainActionBar", label = "Main Bar (Bar 1)"},
        {key = "MultiBarBottomLeft", label = "Bottom Left (Bar 2)"},
        {key = "MultiBarBottomRight", label = "Bottom Right (Bar 3)"},
        {key = "MultiBarRight", label = "Right Bar 1 (Bar 4)"},
        {key = "MultiBarLeft", label = "Right Bar 2 (Bar 5)"},
        {key = "MultiBar5", label = "Bar 6"},
        {key = "MultiBar6", label = "Bar 7"},
        {key = "MultiBar7", label = "Bar 8"},
    }
    
    local yOffset = -50
    for i, barInfo in ipairs(barNames) do
        local check = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", barLabel, "BOTTOMLEFT", 20 + ((i-1) % 2) * 200, -10 - math.floor((i-1) / 2) * 30)
        check.text = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        check.text:SetPoint("LEFT", check, "RIGHT", 5, 0)
        check.text:SetText(barInfo.label)
        
        -- Initialize checkbox state (handle new MainActionBar)
        if not JarsG13BarsDB.hideBars[barInfo.key] then
            JarsG13BarsDB.hideBars[barInfo.key] = true
        end
        check:SetChecked(JarsG13BarsDB.hideBars[barInfo.key])
        
        check:SetScript("OnClick", function(self)
            JarsG13BarsDB.hideBars[barInfo.key] = self:GetChecked()
            HideDefaultBars()
        end)
    end
    
    -- Close button (already provided by BasicFrameTemplateWithInset)
    configFrame:Hide()
end

-- Slash command
SLASH_JG131 = "/jg13"
SLASH_JG132 = "/jg13bind"
SlashCmdList["JG13"] = function(msg)
    msg = msg:lower():trim()
    
    if msg == "bind" or msg == "keybind" or msg == "kb" then
        -- Toggle keybind mode
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
    
    -- Toggle config window
    configFrame:SetShown(not configFrame:IsShown())
end
