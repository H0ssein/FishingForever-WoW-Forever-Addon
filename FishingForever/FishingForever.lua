local MIN_DOUBLE_CLICK = 0.05
local MAX_DOUBLE_CLICK = 0.4
local lastClickTime = 0
local ignoreLureUntil = 0

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

local LURES = {6522, 46006, 62673, 69907, 6532, 7307, 6530, 6533, 6811, 6529, 67404}

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
            lureMenu:Hide()
        end)
        btn.Count:SetText(lure.count > 1 and lure.count or "")
        btn:Show()
    end
    return true
end


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

local isFishing = false

local mainFrame = CreateFrame("Frame")
mainFrame:RegisterEvent("PLAYER_LOGIN")
mainFrame:RegisterEvent("PLAYER_LOGOUT")
mainFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        FishingForeverDB = FishingForeverDB or {}
        
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
        
        local btn = CreateFrame("Button", "FishingForeverCastButton", UIParent, "SecureActionButtonTemplate")
        btn:EnableMouse(true)
        btn:RegisterForClicks("AnyUp", "AnyDown")
        btn:Show()
        
        local clickFrame = CreateFrame("Frame")
        clickFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
        clickFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        clickFrame:SetScript("OnEvent", function(self, event, buttonName)
            if event == "PLAYER_REGEN_DISABLED" then
                if not InCombatLockdown() then ClearOverrideBindings(btn) end
                if lureMenu:IsShown() then lureMenu:Hide() end
                return
            end
            
            if event == "GLOBAL_MOUSE_DOWN" and buttonName == "RightButton" then
                if InCombatLockdown() or not IsFishingPoleEquipped() or UnitExists("mouseover") or GetUnitSpeed("player") > 0 then
                    if not InCombatLockdown() then ClearOverrideBindings(btn) end
                    return
                end
                
                local now = GetTime()
                if lastClickTime and lastClickTime > 0 and (now - lastClickTime < MAX_DOUBLE_CLICK) and (now - lastClickTime > MIN_DOUBLE_CLICK) then
                    lastClickTime = 0
                    local spellName = GetFishingSpellName()
                    SetOverrideBindingSpell(btn, true, "BUTTON2", spellName)
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
                if GetCVarBG() ~= "1" then
                    SetCVarBG("1")
                end
                
                if not InCombatLockdown() then
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
                if FishingForeverDB and FishingForeverDB.userBGSetting ~= nil then
                    SetCVarBG(FishingForeverDB.userBGSetting)
                end
            end
        end
    end
end)
