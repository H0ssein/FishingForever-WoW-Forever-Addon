local MIN_DOUBLE_CLICK = 0.05
local MAX_DOUBLE_CLICK = 0.4
local lastClickTime = 0
local ignoreLureUntil = 0

local DB_DEFAULTS = {
    enableDoubleClick = true,
    enableEasyReel    = true,
    reelInKey         = "BUTTON2",
    enableLureMenu    = true,
    enableSound       = true,
    doubleClickDelay  = 0.4,
}

local SOFT_TARGET_CVARS = {
    ["SoftTargetInteract"] = "3",
    ["SoftTargetInteractArc"] = "2",
    ["SoftTargetInteractRange"] = "30",
    ["SoftTargetInteractGameObject"] = "1",
}

local function IsFishingPoleEquipped()
    local mainHand = GetInventoryItemID("player", 16)
    if mainHand then
        local classID, subclassID
        if C_Item and C_Item.GetItemInfoInstant then
            _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(mainHand)
        elseif GetItemInfoInstant then
            _, _, _, _, _, classID, subclassID = GetItemInfoInstant(mainHand)
        elseif GetItemInfo then
            _, _, _, _, _, _, _, _, _, _, _, classID, subclassID = GetItemInfo(mainHand)
        end
        if classID == 2 and (subclassID == 20 or subclassID == 25) then
            return true
        end
    end
    return false
end

local function GetFishingSpellName()
    local name
    if C_Spell and C_Spell.GetSpellName then
        name = C_Spell.GetSpellName(7620) or C_Spell.GetSpellName(131474)
    elseif GetSpellInfo then
        name = GetSpellInfo(7620) or GetSpellInfo(131474)
    end
    return name or "Fishing"
end

local LURES = {6532, 7307, 6530, 6533, 6811, 6529}

local function GetItemCountWrapper(itemID)
    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(itemID)
    elseif GetItemCount then
        return GetItemCount(itemID)
    end
    return 0
end

local function GetAvailableLures()
    local available = {}
    for _, lureID in ipairs(LURES) do
        local count = GetItemCountWrapper(lureID)
        if count > 0 then
            table.insert(available, {id = lureID, count = count})
        end
    end
    return available
end

local function GetIcon(itemID)
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(itemID)
    elseif GetItemIcon then
        return GetItemIcon(itemID)
    end
    return select(10, GetItemInfo(itemID))
end

local lureMenu = CreateFrame("Frame", "FishingForeverLureMenu", UIParent, "BackdropTemplate")
lureMenu:SetFrameStrata("DIALOG")
lureMenu:Hide()
tinsert(UISpecialFrames, "FishingForeverLureMenu")

if lureMenu.SetBackdrop then
    lureMenu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    lureMenu:SetBackdropColor(0, 0, 0, 1)
    lureMenu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
end

local lureButtons = {}

local lureMenuCloseBtn = CreateFrame("Button", nil, lureMenu)
lureMenuCloseBtn:SetSize(20, 20)
lureMenuCloseBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
lureMenuCloseBtn:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
lureMenuCloseBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
lureMenuCloseBtn:SetScript("OnClick", function()
    ignoreLureUntil = GetTime() + 300
    lureMenu:Hide()
end)
lureMenuCloseBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -5)
    GameTooltip:SetText("Ignore Lures")
    GameTooltip:AddLine("Fish without lures for the next 5 minutes.", 1, 1, 1, true)
    GameTooltip:Show()
end)
lureMenuCloseBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function UpdateLureMenu(availableLures)
    for _, btn in ipairs(lureButtons) do
        btn:Hide()
    end
    
    if #availableLures == 0 then return false end
    
    local btnSize = 28
    local padding = 5
    local width = (#availableLures * btnSize) + ((#availableLures + 1) * padding)
    lureMenu:SetSize(width, btnSize + 2 * padding)
    
    lureMenuCloseBtn:ClearAllPoints()
    lureMenuCloseBtn:SetPoint("CENTER", lureMenu, "TOPRIGHT", 0, 0)
    
    for i, lure in ipairs(availableLures) do
        local btn = lureButtons[i]
        if not btn then
            btn = CreateFrame("Button", "FishingForeverLureBtn"..i, lureMenu, "SecureActionButtonTemplate")
            btn:SetSize(btnSize, btnSize)
            btn:RegisterForClicks("AnyUp", "AnyDown")
            
            local tex = btn:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            btn.icon = tex
            btn:SetNormalTexture("")
            
            if btn.CreateMaskTexture then
                local mask = btn:CreateMaskTexture()
                mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                mask:SetAllPoints(btn.icon)
                btn.icon:AddMaskTexture(mask)
                
                btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
                btn:GetHighlightTexture():SetBlendMode("ADD")
                btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
            else
                btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
                btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
            end
            
            local font = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
            font:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
            btn.Count = font
            
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -5)
                GameTooltip:SetItemByID(self.itemID)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            table.insert(lureButtons, btn)
        end
        
        btn.itemID = lure.id
        btn:SetPoint("LEFT", lureMenu, "LEFT", padding + (i - 1) * (btnSize + padding), 0)
        
        btn.icon:SetTexture(GetIcon(lure.id))
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", "/use item:"..lure.id.."\n/use 16")
        btn:SetScript("PostClick", function()
            ignoreLureUntil = GetTime() + 10
            lureMenu:Hide()
        end)
        btn.Count:SetText(lure.count > 1 and lure.count or "")
        btn:Show()
    end
    return true
end

lureMenu:RegisterEvent("BAG_UPDATE_DELAYED")
lureMenu:RegisterEvent("UNIT_INVENTORY_CHANGED")
lureMenu:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
    if self:IsShown() and not InCombatLockdown() then
        local hasLure = GetWeaponEnchantInfo()
        if hasLure then
            self:Hide()
            return
        end
        local lures = GetAvailableLures()
        if #lures == 0 then
            self:Hide()
        else
            UpdateLureMenu(lures)
        end
    end
end)


local function GetCVarBG()
    if C_CVar and C_CVar.GetCVar then
        return C_CVar.GetCVar("Sound_EnableSoundWhenGameIsInBG")
    else
        return GetCVar("Sound_EnableSoundWhenGameIsInBG")
    end
end

local function SetCVarBG(val)
    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar("Sound_EnableSoundWhenGameIsInBG", val)
    else
        SetCVar("Sound_EnableSoundWhenGameIsInBG", val)
    end
end

local function GetCVarSound()
    if C_CVar and C_CVar.GetCVar then
        return C_CVar.GetCVar("Sound_EnableSFX")
    else
        return GetCVar("Sound_EnableSFX")
    end
end

local function SetCVarSound(val)
    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar("Sound_EnableSFX", val)
    else
        SetCVar("Sound_EnableSFX", val)
    end
end

local function SafeGetCVar(cvar)
    if C_CVar and C_CVar.GetCVar then
        return C_CVar.GetCVar(cvar)
    elseif GetCVar then
        return GetCVar(cvar)
    end
    return nil
end

local function SafeSetCVar(cvar, val)
    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar(cvar, tostring(val))
    elseif SetCVar then
        SetCVar(cvar, tostring(val))
    end
end

local function GetKeyDisplayName(key)
    if not key or key == "BUTTON2" or key == "RightButton" then
        return "Right Click"
    elseif key == "BUTTON1" or key == "LeftButton" then
        return "Left Click"
    elseif key == "BUTTON3" or key == "MiddleButton" then
        return "Middle Click"
    elseif key == "BUTTON4" then
        return "Mouse 4"
    elseif key == "BUTTON5" then
        return "Mouse 5"
    else
        return key
    end
end

local isFishing = false
local castBtn = nil

local mainFrame = CreateFrame("Frame")
mainFrame:RegisterEvent("PLAYER_LOGIN")
mainFrame:RegisterEvent("PLAYER_LOGOUT")
mainFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        FishingForeverDB = FishingForeverDB or {}
        for k, v in pairs(DB_DEFAULTS) do
            if FishingForeverDB[k] == nil then
                FishingForeverDB[k] = v
            end
        end
        MAX_DOUBLE_CLICK = FishingForeverDB.doubleClickDelay
        
        if FishingForeverDB.savedCVars then
            for cvar, origVal in pairs(FishingForeverDB.savedCVars) do
                SafeSetCVar(cvar, origVal)
            end
            FishingForeverDB.savedCVars = nil
        end
        
        local panel = CreateFrame("Frame", "FishingForeverOptionsPanel", UIParent)
        panel.name = "Fishing Forever"
        
        local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("Fishing Forever")
        
        local ver = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        ver:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 6, 2)
        
        local version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("FishingForever", "Version")) 
             or (GetAddOnMetadata and GetAddOnMetadata("FishingForever", "Version")) 
             or "Unknown"
        ver:SetText(version)
        
        local divider = panel:CreateTexture(nil, "ARTWORK")
        divider:SetColorTexture(0.4, 0.4, 0.4, 0.6)
        divider:SetSize(550, 1)
        divider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
        
        local function MakeCheckbox(label, desc, yOffset, dbKey)
            local cb = CreateFrame("CheckButton", "FishingForeverCB_"..dbKey, panel, "InterfaceOptionsCheckButtonTemplate")
            cb:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, yOffset)
            cb.Text:SetText(label)
            cb.Text:SetTextColor(1, 1, 1)
            if desc then
                cb:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(label, 1, 1, 1)
                    GameTooltip:AddLine(desc, nil, nil, nil, true)
                    GameTooltip:Show()
                end)
                cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
            cb:SetChecked(FishingForeverDB[dbKey])
            cb:SetScript("OnClick", function(self)
                FishingForeverDB[dbKey] = self:GetChecked()
                if dbKey == "enableDoubleClick" then
                    MAX_DOUBLE_CLICK = FishingForeverDB.doubleClickDelay
                end
            end)
            return cb
        end
        
        -- 1. Double Right-Click to Fish
        local cbDC = MakeCheckbox(
            "Enable Double Right-Click to Fish",
            "Double right-click anywhere while holding a fishing pole to instantly cast Fishing.",
            -56, "enableDoubleClick")
        
        local sliderLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        sliderLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 42, -88)
        sliderLabel:SetText("Double-Click Window")
        
        local sliderDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        sliderDesc:SetPoint("TOPLEFT", panel, "TOPLEFT", 42, -104)
        sliderDesc:SetTextColor(0.7, 0.7, 0.7)
        sliderDesc:SetText("How quickly you must double-click. Lower = faster.")
        
        local slider = CreateFrame("Slider", "FishingForeverDelaySlider", panel, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", panel, "TOPLEFT", 42, -126)
        slider:SetMinMaxValues(0.1, 0.8)
        slider:SetValueStep(0.05)
        slider:SetWidth(220)
        slider:SetValue(FishingForeverDB.doubleClickDelay)
        slider.Low:SetText("0.1s")
        slider.High:SetText("0.8s")
        slider.Text:SetText(string.format("%.2fs", FishingForeverDB.doubleClickDelay))
        slider:SetScript("OnValueChanged", function(self, val)
            local rounded = math.floor(val * 20 + 0.5) / 20
            FishingForeverDB.doubleClickDelay = rounded
            MAX_DOUBLE_CLICK = rounded
            self.Text:SetText(string.format("%.2fs", rounded))
        end)
        
        local function UpdateSliderState(enabled)
            if enabled then
                slider:Enable()
                sliderLabel:SetTextColor(1, 1, 1)
                sliderDesc:SetTextColor(0.7, 0.7, 0.7)
                slider.Low:SetTextColor(1, 1, 1)
                slider.High:SetTextColor(1, 1, 1)
            else
                slider:Disable()
                sliderLabel:SetTextColor(0.4, 0.4, 0.4)
                sliderDesc:SetTextColor(0.4, 0.4, 0.4)
                slider.Low:SetTextColor(0.4, 0.4, 0.4)
                slider.High:SetTextColor(0.4, 0.4, 0.4)
            end
        end
        
        UpdateSliderState(FishingForeverDB.enableDoubleClick)
        
        local origClick = cbDC:GetScript("OnClick")
        cbDC:SetScript("OnClick", function(self)
            if origClick then origClick(self) end
            UpdateSliderState(self:GetChecked())
        end)
        
        -- 2. Easy Reel-in
        local cbReel = MakeCheckbox(
            "Enable Easy Reel-in (No Bobber Aiming)",
            "Reel in your catch using a hotkey without needing to aim or click directly on the bobber (uses Soft-Target interaction).",
            -180, "enableEasyReel")
            
        local keyLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        keyLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 42, -214)
        keyLabel:SetText("Reel-in Hotkey:")
        
        local keyBtn = CreateFrame("Button", "FishingForeverReelInKeyButton", panel, "UIPanelButtonTemplate")
        keyBtn:SetSize(130, 22)
        keyBtn:SetPoint("LEFT", keyLabel, "RIGHT", 10, 0)
        keyBtn:SetText(GetKeyDisplayName(FishingForeverDB.reelInKey))
        
        local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        resetBtn:SetSize(65, 22)
        resetBtn:SetPoint("LEFT", keyBtn, "RIGHT", 8, 0)
        resetBtn:SetText("Reset")
        
        local keyDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        keyDesc:SetPoint("TOPLEFT", panel, "TOPLEFT", 42, -238)
        keyDesc:SetTextColor(0.7, 0.7, 0.7)
        keyDesc:SetText("Default is Right-Click. Click button to assign a custom key.")
        
        local isBindingKey = false
        keyBtn:SetScript("OnClick", function(self)
            if isBindingKey then return end
            isBindingKey = true
            self:SetText("<Press Any Key>")
            self:EnableKeyboard(true)
            
            local function StopBinding(newKey)
                isBindingKey = false
                self:EnableKeyboard(false)
                self:SetScript("OnKeyDown", nil)
                self:SetScript("OnMouseDown", nil)
                if newKey and newKey ~= "ESCAPE" then
                    FishingForeverDB.reelInKey = newKey
                end
                self:SetText(GetKeyDisplayName(FishingForeverDB.reelInKey))
            end
            
            self:SetScript("OnKeyDown", function(_, key)
                if key == "ESCAPE" then
                    StopBinding(nil)
                else
                    StopBinding(key:upper())
                end
            end)
            
            self:SetScript("OnMouseDown", function(_, button)
                local mapped = "BUTTON2"
                if button == "LeftButton" then mapped = "BUTTON1"
                elseif button == "RightButton" then mapped = "BUTTON2"
                elseif button == "MiddleButton" then mapped = "BUTTON3"
                elseif button == "Button4" then mapped = "BUTTON4"
                elseif button == "Button5" then mapped = "BUTTON5"
                end
                StopBinding(mapped)
            end)
        end)
        
        resetBtn:SetScript("OnClick", function()
            FishingForeverDB.reelInKey = "BUTTON2"
            keyBtn:SetText(GetKeyDisplayName("BUTTON2"))
        end)
        
        local function UpdateEasyReelState(enabled)
            if enabled then
                keyBtn:Enable()
                resetBtn:Enable()
                keyLabel:SetTextColor(1, 1, 1)
                keyDesc:SetTextColor(0.7, 0.7, 0.7)
            else
                keyBtn:Disable()
                resetBtn:Disable()
                keyLabel:SetTextColor(0.4, 0.4, 0.4)
                keyDesc:SetTextColor(0.4, 0.4, 0.4)
            end
        end
        
        UpdateEasyReelState(FishingForeverDB.enableEasyReel)
        
        local origReelClick = cbReel:GetScript("OnClick")
        cbReel:SetScript("OnClick", function(self)
            if origReelClick then origReelClick(self) end
            UpdateEasyReelState(self:GetChecked())
        end)
        
        -- 3. Smart Lure Menu
        MakeCheckbox(
            "Enable Smart Lure Menu",
            "After casting, if no lure is applied a quick-select menu appears near your cursor.",
            -276, "enableLureMenu")
        
        -- 4. Sound Automation
        MakeCheckbox(
            "Enable Sound Automation",
            "Turns on sound (and background sound) when you start fishing, then restores your original settings when done.",
            -320, "enableSound")
        
        if InterfaceOptions_AddCategory then
            InterfaceOptions_AddCategory(panel)
        elseif Settings and Settings.RegisterCanvasLayoutCategory then
            local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
            Settings.RegisterAddOnCategory(category)
        end
        
        C_Timer.After(1, function()
            local currentCVar = GetCVarBG()
            if FishingForeverDB.userBGSetting ~= nil then
                SetCVarBG(FishingForeverDB.userBGSetting)
            else
                if currentCVar == "1" then
                    FishingForeverDB.userBGSetting = "0"
                    SetCVarBG("0")
                else
                    FishingForeverDB.userBGSetting = currentCVar
                end
            end
        end)
        
        castBtn = CreateFrame("Button", "FishingForeverCastButton", UIParent, "SecureActionButtonTemplate")
        castBtn:EnableMouse(true)
        castBtn:RegisterForClicks("AnyUp", "AnyDown")
        castBtn:SetScript("PostClick", function(self, button)
            if IsMouselooking() then
                MouselookStop()
            end
        end)
        castBtn:Show()
        local btn = castBtn
        
        local clickFrame = CreateFrame("Frame")
        clickFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
        clickFrame:RegisterEvent("GLOBAL_MOUSE_UP")
        clickFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        clickFrame:SetScript("OnEvent", function(self, event, buttonName)
            if event == "PLAYER_REGEN_DISABLED" then
                if not InCombatLockdown() then ClearOverrideBindings(btn) end
                if lureMenu:IsShown() then lureMenu:Hide() end
                return
            end
            
            if event == "GLOBAL_MOUSE_UP" and buttonName == "RightButton" then
                if IsMouselooking() then
                    MouselookStop()
                end
                return
            end
            
            if isFishing then
                return
            end
            
            local isCasting = (UnitCastingInfo and UnitCastingInfo("player")) or (C_Spell and C_Spell.GetSpellCastInfo and C_Spell.GetSpellCastInfo("player"))
            local isChanneling = (UnitChannelInfo and UnitChannelInfo("player")) or (C_Spell and C_Spell.GetSpellChannelInfo and C_Spell.GetSpellChannelInfo("player"))
            if isCasting or (isChanneling and isChanneling ~= GetFishingSpellName()) then
                if not InCombatLockdown() then ClearOverrideBindings(btn) end
                return
            end
            
            if event == "GLOBAL_MOUSE_DOWN" and buttonName == "RightButton" then
                if not FishingForeverDB.enableDoubleClick then return end
                if InCombatLockdown() or not IsFishingPoleEquipped() or UnitExists("mouseover") or GetUnitSpeed("player") > 0 then
                    if not InCombatLockdown() then ClearOverrideBindings(btn) end
                    return
                end
                
                local now = GetTime()
                if lastClickTime and lastClickTime > 0 and (now - lastClickTime < MAX_DOUBLE_CLICK) and (now - lastClickTime > MIN_DOUBLE_CLICK) then
                    lastClickTime = 0
                    local spellName = GetFishingSpellName()
                    SetOverrideBindingSpell(btn, true, "BUTTON2", spellName)
                    if IsMouselooking() then
                        MouselookStop()
                    end
                else
                    lastClickTime = now
                    if not InCombatLockdown() then ClearOverrideBindings(btn) end
                end
            else
                if not InCombatLockdown() then ClearOverrideBindings(btn) end
                lastClickTime = 0
            end
        end)
    elseif event == "PLAYER_LOGOUT" then
        if not isFishing then
            FishingForeverDB.userBGSetting = GetCVarBG()
        else
            if FishingForeverDB.savedCVars then
                for cvar, origVal in pairs(FishingForeverDB.savedCVars) do
                    SafeSetCVar(cvar, origVal)
                end
                FishingForeverDB.savedCVars = nil
            end
        end
    end
end)



local soundFrame = CreateFrame("Frame")
soundFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
soundFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
soundFrame:SetScript("OnEvent", function(self, event, unit)
    if unit == "player" then
        if event == "UNIT_SPELLCAST_CHANNEL_START" then
            local expectedName = GetFishingSpellName()
            local channelName = UnitChannelInfo("player")
            if channelName == expectedName then
                isFishing = true
                if IsMouselooking() then
                    MouselookStop()
                end
                FishingForeverDB = FishingForeverDB or {}
                
                if FishingForeverDB.enableSound then
                    local curSound = GetCVarSound()
                    if curSound ~= "1" then
                        FishingForeverDB.userSoundSetting = curSound
                        SetCVarSound("1")
                    end
                    
                    local curBG = GetCVarBG()
                    if curBG ~= "1" then
                        SetCVarBG("1")
                    end
                end
                
                if FishingForeverDB.enableEasyReel then
                    FishingForeverDB.savedCVars = FishingForeverDB.savedCVars or {}
                    for cvar, targetVal in pairs(SOFT_TARGET_CVARS) do
                        local cur = SafeGetCVar(cvar)
                        if cur ~= nil and FishingForeverDB.savedCVars[cvar] == nil then
                            FishingForeverDB.savedCVars[cvar] = cur
                        end
                        SafeSetCVar(cvar, targetVal)
                    end
                    
                    if castBtn and not InCombatLockdown() then
                        local key = FishingForeverDB.reelInKey or "BUTTON2"
                        SetOverrideBinding(castBtn, true, key, "INTERACTTARGET")
                    end
                end
                
                if FishingForeverDB.enableLureMenu and not InCombatLockdown() then
                    local hasLure = GetWeaponEnchantInfo()
                    local nowTime = GetTime()
                    if hasLure then
                        ignoreLureUntil = 0
                    end
                    if not hasLure and nowTime > ignoreLureUntil then
                        local lures = GetAvailableLures()
                        if #lures > 0 then
                            if UpdateLureMenu(lures) then
                                local x, y = GetCursorPosition()
                                local scale = UIParent:GetEffectiveScale()
                                lureMenu:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (x / scale) + 40, (y / scale) - 20)
                                lureMenu:Show()
                            end
                        end
                    end
                end
            end
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            if isFishing then
                isFishing = false
                if IsMouselooking() then
                    MouselookStop()
                end
                if FishingForeverDB then
                    if FishingForeverDB.userBGSetting ~= nil then
                        SetCVarBG(FishingForeverDB.userBGSetting)
                    end
                    if FishingForeverDB.userSoundSetting ~= nil then
                        SetCVarSound(FishingForeverDB.userSoundSetting)
                        FishingForeverDB.userSoundSetting = nil
                    end
                    
                    if FishingForeverDB.enableEasyReel then
                        if castBtn and not InCombatLockdown() then
                            ClearOverrideBindings(castBtn)
                        end
                        if FishingForeverDB.savedCVars then
                            for cvar, origVal in pairs(FishingForeverDB.savedCVars) do
                                SafeSetCVar(cvar, origVal)
                            end
                            FishingForeverDB.savedCVars = nil
                        end
                    end
                end
            end
        end
    end
end)
