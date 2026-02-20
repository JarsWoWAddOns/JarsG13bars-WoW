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

-- Secure state driver for combat-safe action bar page swapping.
-- Uses WoW's restricted environment so page changes work even in combat.
local stateDriverFrame

local function SetupSecurePageDriver()
    stateDriverFrame = CreateFrame("Frame", "JG13_StateDriver", UIParent, "SecureHandlerStateTemplate")

    -- Register frame refs so the restricted snippet can access buttons 1-12
    for i = 1, 12 do
        stateDriverFrame:SetFrameRef("button" .. i, buttons[i])
    end

    -- Restricted Lua snippet executed on every state change (works in combat)
    stateDriverFrame:SetAttribute("_onstate-page", [[
        local page
        if newstate == "override" then
            page = GetOverrideBarIndex()
        elseif newstate == "vehicle" then
            page = GetVehicleBarIndex()
        elseif newstate == "possess" then
            page = 12
        else
            page = tonumber(newstate) or 1
        end

        for i = 1, 12 do
            local button = self:GetFrameRef("button" .. i)
            if button then
                button:SetAttribute("action", (page - 1) * 12 + i)
            end
        end
    ]])

    -- Macro condition string evaluated by the secure state system.
    -- [overridebar] fires for dragonriding / special mounts.
    RegisterStateDriver(stateDriverFrame, "page",
        "[overridebar] override; [vehicleui] vehicle; [possessbar] possess; " ..
        "[bonusbar:5] 11; [bonusbar:4] 10; [bonusbar:3] 9; [bonusbar:2] 8; [bonusbar:1] 7; " ..
        "[bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; 1"
    )
end

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

-- Flag: override bindings need to be (re)applied once combat ends
local pendingBindingUpdate = false

-- Function to setup override bindings
local function UpdateOverrideBindings()
    if not mainFrame then return end
    if InCombatLockdown() then
        pendingBindingUpdate = true
        return
    end
    pendingBindingUpdate = false
    
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

    -- Setup secure state driver for combat-safe page swapping
    SetupSecurePageDriver()

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
eventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
eventFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
eventFrame:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

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
            UpdateButtons()
        end)
        
    elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" or 
           event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" or 
           event == "UPDATE_OVERRIDE_ACTIONBAR" or event == "SPELL_UPDATE_ICON" or 
           event == "UPDATE_SHAPESHIFT_FORM" or event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        -- ActionBarButtonTemplate handles ACTIONBAR_SLOT_CHANGED internally
        -- Just update keybinds and paged actions
        UpdateButtons()
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Combat ended: apply any override bindings that were deferred
        if pendingBindingUpdate then
            UpdateOverrideBindings()
            UpdateKeybinds()
        end

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

-- Modern UI color palette
local UI = {
    bg        = { 0.10, 0.10, 0.12, 0.95 },
    header    = { 0.13, 0.13, 0.16, 1 },
    accent    = { 0.30, 0.75, 0.75, 1 },      -- teal accent
    accentDim = { 0.20, 0.50, 0.50, 1 },
    text      = { 0.90, 0.90, 0.90, 1 },
    textDim   = { 0.55, 0.55, 0.58, 1 },
    section   = { 0.16, 0.16, 0.19, 1 },
    border    = { 0.22, 0.22, 0.26, 1 },
    sliderBg  = { 0.18, 0.18, 0.22, 1 },
    sliderFill= { 0.30, 0.75, 0.75, 0.6 },
    btnNormal = { 0.18, 0.18, 0.22, 1 },
    btnHover  = { 0.24, 0.24, 0.28, 1 },
    btnPress  = { 0.14, 0.14, 0.17, 1 },
    checkOn   = { 0.30, 0.75, 0.75, 1 },
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

CreateConfigWindow = function()
    if configFrame then
        return
    end

    local PANEL_WIDTH = 380
    local CONTENT_WIDTH = PANEL_WIDTH - 40  -- 20px padding each side
    local PANEL_HEIGHT = 540

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
    scrollFrame:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 20, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -32, 4)

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

    -- === APPEARANCE SECTION ===
    local sec1 = CreateSectionHeader(content, "Appearance")
    placeWidget(sec1, 20)

    -- Position slider
    local posSlider = CreateModernSlider(content, "JG13_PositionSlider", "Vertical Position",
        -2400, 0, JarsG13BarsDB.position.y, 1, CONTENT_WIDTH,
        function(v) return tostring(math.floor(v)) end,
        function(v) UpdateFramePosition(math.floor(v)) end)
    placeWidget(posSlider, 42)

    -- Background opacity slider
    local opacitySlider = CreateModernSlider(content, "JG13_OpacitySlider", "Background Opacity",
        0, 1, JarsG13BarsDB.bgOpacity or 0.3, 0.05, CONTENT_WIDTH,
        function(v) return string.format("%.0f%%", v * 100) end,
        function(v) UpdateBackgroundOpacity(v) end)
    placeWidget(opacitySlider, 42)

    -- Scale slider
    local scaleSlider = CreateModernSlider(content, "JG13_ScaleSlider", "Scale",
        0.5, 1.0, JarsG13BarsDB.scale or 1.0, 0.05, CONTENT_WIDTH,
        function(v) return string.format("%.0f%%", v * 100) end,
        function(v) UpdateScale(v) end)
    placeWidget(scaleSlider, 42)

    -- Overall transparency slider
    local alphaSlider = CreateModernSlider(content, "JG13_AlphaSlider", "Overall Transparency",
        0, 1, JarsG13BarsDB.frameAlpha or 1.0, 0.05, CONTENT_WIDTH,
        function(v) return string.format("%.0f%%", v * 100) end,
        function(v) UpdateFrameAlpha(v) end)
    placeWidget(alphaSlider, 42)

    -- === BEHAVIOR SECTION ===
    advanceY(SECTION_SPACING - SPACING)
    local sec2 = CreateSectionHeader(content, "Behavior")
    placeWidget(sec2, 20)

    -- Hide on mouse out
    local hideCheck = CreateModernCheck(content, "Hide unless moused over", JarsG13BarsDB.hideOnMouseOut,
        function(checked) ApplyHideOnMouseOut(checked) end)
    placeWidget(hideCheck, 22)

    -- Show keybinds
    local keybindsCheck = CreateModernCheck(content, "Show keybinds on buttons", JarsG13BarsDB.showKeybinds,
        function(checked)
            JarsG13BarsDB.showKeybinds = checked
            UpdateKeybinds()
        end)
    placeWidget(keybindsCheck, 22)

    -- === LAYOUT SECTION ===
    advanceY(SECTION_SPACING - SPACING)
    local sec3 = CreateSectionHeader(content, "Layout")
    placeWidget(sec3, 20)

    -- Layout mode buttons (radio-style toggle)
    local layoutRow = CreateFrame("Frame", nil, content)
    layoutRow:SetSize(CONTENT_WIDTH, 30)
    placeWidget(layoutRow, 30)

    local layoutLbl = layoutRow:CreateFontString(nil, "OVERLAY")
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
    g13Btn = createLayoutToggle(layoutRow, "G13", 50, JarsG13BarsDB.layoutMode == "G13", function()
        JarsG13BarsDB.layoutMode = "G13"
        g13Btn:SetActive(true)
        keyzenBtn:SetActive(false)
        if mainFrame then ApplyG13Layout(mainFrame) end
    end)
    keyzenBtn = createLayoutToggle(layoutRow, "Keyzen", 136, JarsG13BarsDB.layoutMode == "Keyzen", function()
        JarsG13BarsDB.layoutMode = "Keyzen"
        g13Btn:SetActive(false)
        keyzenBtn:SetActive(true)
        if mainFrame then ApplyKeyzenLayout(mainFrame) end
    end)

    -- === BLIZZARD BARS SECTION ===
    advanceY(SECTION_SPACING - SPACING)
    local sec4 = CreateSectionHeader(content, "Blizzard Bars")
    placeWidget(sec4, 20)

    local barNames = {
        {key = "MainActionBar", label = "Hide Main Bar (Bar 1)"},
    }

    for _, barInfo in ipairs(barNames) do
        if JarsG13BarsDB.hideBars[barInfo.key] == nil then
            JarsG13BarsDB.hideBars[barInfo.key] = true
        end
        local barCheck = CreateModernCheck(content, barInfo.label, JarsG13BarsDB.hideBars[barInfo.key],
            function(checked)
                JarsG13BarsDB.hideBars[barInfo.key] = checked
                HideDefaultBars()
            end)
        placeWidget(barCheck, 22)
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
    LibKeyBound.RegisterCallback(keybindBtn, "LIBKEYBOUND_ENABLED", function()
        keybindBtn:SetText("Exit Keybind Mode")
    end)
    LibKeyBound.RegisterCallback(keybindBtn, "LIBKEYBOUND_DISABLED", function()
        keybindBtn:SetText("Set Keybinds")
    end)

    -- Reset button
    local resetBtn = CreateModernButton(content, "Reset to Defaults", 160, 30, function()
        posSlider.slider:SetValue(-400)
        opacitySlider.slider:SetValue(0.3)
        scaleSlider.slider:SetValue(1.0)
        alphaSlider.slider:SetValue(1.0)
        hideCheck:SetChecked(false)
        keybindsCheck:SetChecked(true)
        UpdateFramePosition(-400)
        UpdateBackgroundOpacity(0.3)
        UpdateScale(1.0)
        UpdateFrameAlpha(1.0)
        ApplyHideOnMouseOut(false)
        JarsG13BarsDB.showKeybinds = true
        UpdateKeybinds()
        print("|cff00ff00Jar's G13 Bars|r: Settings reset to default.")
    end)
    placeWidget(resetBtn, 30)

    -- Set total content height so scroll works
    content:SetHeight(math.abs(yPos) + 20)

    -- Make frame close with Escape
    tinsert(UISpecialFrames, "JG13_ConfigFrame")

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
