-- Jar's G13 Action Bars for WoW 12.0.1
-- Custom action bar layout for Logitech G13 gaming keypad

-- Saved variables
JarsG13BarsDB = JarsG13BarsDB or {}

-- Libraries
local LibKeyBound = LibStub and LibStub("LibKeyBound-1.0", true)

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

-- Action bar page tracking
local currentPage = 1

-- Calculate which page we're on based on game state
local function GetCurrentPage()
    -- Check for override bar (dragonriding, special mounts)
    -- Try new API first, fall back to old
    local hasOverride = C_ActionBar and C_ActionBar.HasOverrideActionBar and C_ActionBar.HasOverrideActionBar() or HasOverrideActionBar()
    if hasOverride then
        if C_ActionBar and C_ActionBar.GetOverrideBarIndex then
            return C_ActionBar.GetOverrideBarIndex()
        else
            return 18  -- Override bar uses page 18 (actions 133-144)
        end
    end
    
    -- Check for vehicle bar
    local hasVehicle = C_ActionBar and C_ActionBar.HasVehicleActionBar and C_ActionBar.HasVehicleActionBar() or HasVehicleActionBar()
    if hasVehicle then
        if C_ActionBar and C_ActionBar.GetVehicleBarIndex then
            return C_ActionBar.GetVehicleBarIndex()
        else
            return 12  -- Vehicle bar uses page 12 (actions 133-144)
        end
    end
    
    -- Check for possess bar (still uses old API as of 12.0.0)
    if IsPossessBarVisible() then
        return 12  -- Possess bar uses page 12
    end
    
    -- Check for bonus bar (stance, forms, etc.)
    local bonusBarOffset = C_ActionBar and C_ActionBar.GetBonusBarOffset and C_ActionBar.GetBonusBarOffset() or GetBonusBarOffset()
    if bonusBarOffset and bonusBarOffset > 0 then
        return bonusBarOffset + 6  -- Bonus bars are pages 7-11
    end
    
    -- Use the current action bar page
    if C_ActionBar and C_ActionBar.GetActionBarPage then
        return C_ActionBar.GetActionBarPage() or 1
    else
        return 1  -- Default to page 1 (actions 1-12)
    end
end

-- Update button actions based on current page
local function UpdatePagedActions()
    if InCombatLockdown() then return end
    
    local page = GetCurrentPage()
    if page == currentPage then return end  -- No change
    
    currentPage = page
    
    -- Update buttons 1-12 to point to the correct page
    for i = 1, 12 do
        local button = buttons[i]
        if button then
            local action = (page - 1) * 12 + i
            button:SetAttribute("action", action)
        end
    end
end

-- Event handler for page changes
local pageFrame = CreateFrame("Frame")
pageFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
pageFrame:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
pageFrame:RegisterEvent("UPDATE_POSSESS_BAR")
pageFrame:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
pageFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
pageFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
pageFrame:SetScript("OnEvent", function()
    UpdatePagedActions()
end)

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
    
    -- Default layout mode
    if not JarsG13BarsDB.layoutMode then
        JarsG13BarsDB.layoutMode = "G13"  -- G13 or Keyzen
    end

    -- Default frame alpha (overall transparency)
    if not JarsG13BarsDB.frameAlpha then
        JarsG13BarsDB.frameAlpha = 1.0
    end

    -- Default hide on mouse out
    if JarsG13BarsDB.hideOnMouseOut == nil then
        JarsG13BarsDB.hideOnMouseOut = false
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
    
    -- Hide MultiBarBottomLeft (actions 73-84) since JG13 buttons 13-24 mirror it
    local multiBar = _G["MultiBarBottomLeft"]
    if multiBar then
        multiBar:SetParent(UIHider)
        multiBar:Hide()
        -- Hide individual buttons
        for i = 1, 12 do
            local button = _G["MultiBarBottomLeftButton" .. i]
            if button then
                button:Hide()
                button:SetParent(UIHider)
            end
        end
    end
    
    -- Manage main action bar
    local configurableBars = {
        "MainMenuBar",        -- <= 11.2.5
        "MainActionBar",      -- >= 12.0
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
        if button and button.HotKey then
            if show then
                -- Buttons 1-12 use standard action bindings, 13-24 use click bindings
                local command
                if i <= 12 then
                    command = "ACTIONBUTTON" .. i
                else
                    -- Use click binding for buttons 13-24 (exclusive to this addon)
                    command = "CLICK JG13_Button" .. i .. ":Keybind"
                end
                
                if command then
                    local key = GetBindingKey(command)
                    if key and key ~= "" then
                        local bindingText = GetBindingText(key, "KEY_", 1)
                        if bindingText and bindingText ~= "" and bindingText:byte() > 31 then
                            button.HotKey:SetText(bindingText)
                        else
                            button.HotKey:SetText("")
                        end
                    else
                        button.HotKey:SetText("")
                    end
                end
                button.HotKey:Show()
            else
                -- When hiding, clear text and hide
                button.HotKey:SetText("")
                button.HotKey:Hide()
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
    button.baseAction = index  -- Store the base action for reference
    
    -- Setup action button
    button:SetAttribute("type", "action")
    button:RegisterForClicks("AnyUp")
    
    if index <= 12 then
        -- Buttons 1-12: Mirror Blizzard's main action bar (ActionButton1-12)
        -- The hook will sync these to match Blizzard's dynamic paging
        button:SetAttribute("action", index)
        button:SetAttribute("commandName", "ACTIONBUTTON" .. index)
    else
        -- Buttons 13-24: Mirror ActionBar 2 (MultiActionBar1 actions 73-84)
        local multiBarAction = 72 + (index - 12)
        button:SetAttribute("action", multiBarAction)
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
        if self.baseAction and self.baseAction <= 12 then
            return "ACTIONBUTTON" .. self.baseAction
        elseif self.baseAction and self.baseAction <= 24 then
            -- Use CLICK bindings for buttons 13-24 (more reliable for custom addon buttons)
            return "CLICK JG13_Button" .. self.baseAction .. ":LeftButton"
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

-- Layout positioning functions
local function ApplyG13Layout(frame)
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

local function ApplyKeyzenLayout(frame)
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
    
    -- Create all buttons first (without positioning)
    for i = 1, 24 do
        buttons[i] = CreateActionButton(frame, i, PRIMARY_SIZE)
    end
    
    -- Apply layout based on mode
    if JarsG13BarsDB.layoutMode == "Keyzen" then
        ApplyKeyzenLayout(frame)
    else
        ApplyG13Layout(frame)
    end

    -- Apply overall frame alpha
    frame:SetAlpha(JarsG13BarsDB.frameAlpha or 1.0)

    -- Hide on mouse out behavior (uses IsMouseOver polling since child buttons consume mouse events)
    if JarsG13BarsDB.hideOnMouseOut then
        frame:SetAlpha(0)
        frame:SetScript("OnUpdate", function(self)
            if self:IsMouseOver() then
                self:SetAlpha(JarsG13BarsDB.frameAlpha or 1.0)
            else
                self:SetAlpha(0)
            end
        end)
    end

    return frame
end

-- Update all buttons - just refresh keybinds and paged actions
local function UpdateButtons()
    UpdatePagedActions()
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
eventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
eventFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
eventFrame:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "JarsG13Bars" then
            InitDB()
            HideDefaultBars()
            mainFrame = CreateMainFrame()
            
            CreateConfigWindow()
            
            -- Setup override bindings and update keybinds after a delay to ensure buttons are ready
            C_Timer.After(1, function()
                UpdatePagedActions()  -- Initial page setup
                UpdateOverrideBindings()
                UpdateKeybinds()
            end)
            
            print("|cff00ff00Jar's G13 Action Bars|r loaded. Type |cff00ffff/jg13|r to configure.")
            print("|cff00ff00Jar's G13|r: Buttons 1-12 mirror Action Bar 1, buttons 13-24 mirror Action Bar 2.")
            
            self:UnregisterEvent("ADDON_LOADED")
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        HideDefaultBars()
        C_Timer.After(0.5, function()
            UpdatePagedActions()
            UpdateButtons()
        end)
        
    elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" or 
           event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" or 
           event == "UPDATE_OVERRIDE_ACTIONBAR" or event == "SPELL_UPDATE_ICON" or 
           event == "UPDATE_SHAPESHIFT_FORM" or event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        -- ActionBarButtonTemplate handles ACTIONBAR_SLOT_CHANGED internally
        -- Just update keybinds and paged actions
        UpdateButtons()
        
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

-- Function to update overall frame alpha
local function UpdateFrameAlpha(alpha)
    if mainFrame then
        JarsG13BarsDB.frameAlpha = alpha
        if not JarsG13BarsDB.hideOnMouseOut then
            mainFrame:SetAlpha(alpha)
        end
    end
end

-- Function to apply hide-on-mouse-out behavior
local function ApplyHideOnMouseOut(enabled)
    if not mainFrame then return end
    JarsG13BarsDB.hideOnMouseOut = enabled
    if enabled then
        mainFrame:SetAlpha(0)
        mainFrame:SetScript("OnUpdate", function(self)
            if self:IsMouseOver() then
                self:SetAlpha(JarsG13BarsDB.frameAlpha or 1.0)
            else
                self:SetAlpha(0)
            end
        end)
    else
        mainFrame:SetAlpha(JarsG13BarsDB.frameAlpha or 1.0)
        mainFrame:SetScript("OnUpdate", nil)
    end
end

-- Create config window
local configFrame
CreateConfigWindow = function()
    if configFrame then
        return
    end
    
    configFrame = CreateFrame("Frame", "JG13_ConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    configFrame:SetSize(400, 780)
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
    posSlider:SetMinMaxValues(-2400, 0)
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

    -- Frame Alpha (overall transparency) label
    local alphaLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    alphaLabel:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -40)
    alphaLabel:SetText("Overall Transparency:")

    -- Frame Alpha slider
    local alphaSlider = CreateFrame("Slider", "JG13_AlphaSlider", configFrame, "OptionsSliderTemplate")
    alphaSlider:SetPoint("TOPLEFT", alphaLabel, "BOTTOMLEFT", 0, -20)
    alphaSlider:SetMinMaxValues(0, 1)
    alphaSlider:SetValue(JarsG13BarsDB.frameAlpha or 1.0)
    alphaSlider:SetValueStep(0.05)
    alphaSlider:SetObeyStepOnDrag(true)
    alphaSlider:SetWidth(350)

    -- Alpha slider text
    alphaSlider.Low:SetText("Invisible")
    alphaSlider.High:SetText("Full")
    alphaSlider.Text:SetText(string.format("%.0f%%", (JarsG13BarsDB.frameAlpha or 1.0) * 100))

    alphaSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 0.05 + 0.5) * 0.05  -- Round to nearest 0.05
        self.Text:SetText(string.format("%.0f%%", value * 100))
        UpdateFrameAlpha(value)
    end)

    -- Hide on mouse out checkbox
    local hideCheck = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
    hideCheck:SetPoint("TOPLEFT", alphaSlider, "BOTTOMLEFT", -10, -10)
    hideCheck.text = hideCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hideCheck.text:SetPoint("LEFT", hideCheck, "RIGHT", 5, 0)
    hideCheck.text:SetText("Hide unless moused over")
    hideCheck:SetChecked(JarsG13BarsDB.hideOnMouseOut)
    hideCheck:SetScript("OnClick", function(self)
        ApplyHideOnMouseOut(self:GetChecked())
    end)

    -- Layout mode dropdown
    local layoutLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    layoutLabel:SetPoint("TOPLEFT", hideCheck, "BOTTOMLEFT", 10, -10)
    layoutLabel:SetText("Layout Mode:")
    
    local layoutDropdown = CreateFrame("DropdownButton", nil, configFrame, "WowStyle1DropdownTemplate")
    layoutDropdown:SetPoint("TOPLEFT", layoutLabel, "TOPRIGHT", 5, 3)
    layoutDropdown:SetWidth(130)
    layoutDropdown:SetDefaultText(JarsG13BarsDB.layoutMode or "G13")
    layoutDropdown:SetupMenu(function(_, rootDescription)
        local layouts = { "G13", "Keyzen" }
        for _, name in ipairs(layouts) do
            rootDescription:CreateRadio(name,
                function() return JarsG13BarsDB.layoutMode == name end,
                function()
                    JarsG13BarsDB.layoutMode = name
                    if mainFrame then
                        if name == "Keyzen" then
                            ApplyKeyzenLayout(mainFrame)
                        else
                            ApplyG13Layout(mainFrame)
                        end
                    end
                end)
        end
    end)
    
    -- Reset button
    local resetBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    resetBtn:SetSize(150, 25)
    resetBtn:SetPoint("TOP", layoutDropdown, "BOTTOM", 0, -10)
    resetBtn:SetText("Reset to Default")
    resetBtn:SetScript("OnClick", function()
        posSlider:SetValue(-400)
        opacitySlider:SetValue(0.3)
        scaleSlider:SetValue(1.0)
        alphaSlider:SetValue(1.0)
        hideCheck:SetChecked(false)
        UpdateFramePosition(-400)
        UpdateBackgroundOpacity(0.3)
        UpdateScale(1.0)
        UpdateFrameAlpha(1.0)
        ApplyHideOnMouseOut(false)
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
    barLabel:SetText("Hide Blizzard Main Action Bar:")
    
    local barNames = {
        {key = "MainActionBar", label = "Main Bar (Bar 1)"},
    }
    
    local yOffset = -50
    for i, barInfo in ipairs(barNames) do
        local check = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", barLabel, "BOTTOMLEFT", 20, -10)
        check.text = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        check.text:SetPoint("LEFT", check, "RIGHT", 5, 0)
        check.text:SetText(barInfo.label)
        
        -- Initialize checkbox state only if it's nil (not set yet)
        if JarsG13BarsDB.hideBars[barInfo.key] == nil then
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
