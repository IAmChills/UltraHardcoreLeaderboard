local PREFIX = "UHLB"
local FRAME, SCROLL, SCROLL_CHILD, HEADER

local addon = LibStub("AceAddon-3.0"):NewAddon("UltraHardcoreLeaderboard", "AceComm-3.0")
addon.seen = addon.seen or {}
local seen = addon.seen
local addonIcon = LibStub("LibDBIcon-1.0")
local addonLDB = LibStub("LibDataBroker-1.1"):NewDataObject("UltraHardcoreLeaderboard", {
    type = "data source",
    text = "UltraHardcore Leaderboard",
    icon = "Interface\\AddOns\\UltraHardcoreLeaderboard\\Images\\UltraHardcoreLeaderbaordIcon",
    OnClick = function(self, btn)
        if btn == "LeftButton" then
            if FRAME:IsShown() then
                FRAME:Hide()
            else
                FRAME:Show()
                FRAME.RefreshLeaderboardUI(true)
            end
        end
    end,
    OnTooltipShow = function(tooltip)
        if not tooltip or not tooltip.AddLine then
            return
        end

		tooltip:AddLine("|cffffffffUltra Hardcore Leaderboard|r\n\nLeft-click to open the leaderboard", nil, nil, nil, nil)
	end,
})

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("UltraHardcoreLeaderboardDB", {
        profile = {
            minimap = {
                hide = false,
            },
            welcomeMessageShown = false,
            restrictToGuild = true,  -- New setting for guild restriction toggle
        },
    })
    addonIcon:Register("UltraHardcoreLeaderboard", addonLDB, self.db.profile.minimap)
    self:RegisterComm("UHLB", "OnCommReceived")
    
    -- Hook into GameTooltip to show preset for friendly players
    hooksecurefunc(GameTooltip, "SetUnit", function(tooltip, unit)
        if not unit then
            return
        end
        
        -- Check if it's a player (not NPC) and friendly
        if UnitIsPlayer(unit) and UnitIsFriend("player", unit) then
            local name = UnitName(unit)
            if name then
                local cache = UltraHardcoreLeaderboardDB and UltraHardcoreLeaderboardDB.cache
                local playerCache = cache and cache[name]
                if playerCache and playerCache.preset then
                    tooltip:AddLine("\n|cfff44336UHC: |r" .. playerCache.preset)
                    GameTooltip:Show()
                end
            end
        end
    end)
end

local settingsCheckboxOptions = {
    { id = 1, name = "UHC Player Frame", dbSettingsValueName = "hidePlayerFrame" },
    { id = 2, name = "Hide Minimap", dbSettingsValueName = "hideMinimap" },
    --{ id = 3, name = "Use Custom Buff Frame", dbSettingsValueName = "hideBuffFrame" },
    { id = 4, name = "Hide Target Frame", dbSettingsValueName = "hideTargetFrame" },
    { id = 5, name = "Hide Target Tooltips", dbSettingsValueName = "hideTargetTooltip" },
    { id = 6, name = "Death Indicator (Tunnel Vision)", dbSettingsValueName = "showTunnelVision" },
    { id = 7, name = "Tunnel Vision Covers Everything", dbSettingsValueName = "tunnelVisionMaxStrata" },
    --{ id = 8, name = "Hide Quest UI", dbSettingsValueName = "hideQuestFrame" },
    { id = 9, name = "Show Dazed Effect", dbSettingsValueName = "showDazedEffect" },
    { id = 10, name = "Show Crit Screen Shift Effect", dbSettingsValueName = "showCritScreenMoveEffect" },
    { id = 11, name = "Hide Action Bars when not resting", dbSettingsValueName = "hideActionBars" },
    { id = 12, name = "UHC Party Frames", dbSettingsValueName = "hideGroupHealth" },
    { id = 13, name = "Pets Die Permanently", dbSettingsValueName = "petsDiePermanently" },
    --{ id = 14, name = "Show Full Health Indicator", dbSettingsValueName = "showFullHealthIndicator" },
    { id = 15, name = "Disable Nameplates", dbSettingsValueName = "disableNameplateHealth" },
    { id = 16, name = "Show Incoming Damage Effect", dbSettingsValueName = "showIncomingDamageEffect" },
    { id = 17, name = "Breath Indicator", dbSettingsValueName = "hideBreathIndicator" },
    { id = 18, name = "Show Incoming Healing Effect", dbSettingsValueName = "showHealingIndicator" },
    { id = 19, name = "First Person Camera", dbSettingsValueName = "setFirstPersonCamera"},
    { id = 20, name = "Reject buffs from others", dbSettingsValueName = "rejectBuffsFromOthers"},
    { id = 21, name = "Route Planner", dbSettingsValueName = "routePlanner"},
    { id = 22, name = "Hide Quest UI", dbSettingsValueName = "completelyRemovePlayerFrame"},
    { id = 23, name = "Hide Action Bars when not resting", dbSettingsValueName = "completelyRemoveTargetFrame"},
}

function GetPresetAndTooltip(playerName) -- Made global for achievements addon
    local presetNames = { "Lite", "Recommended", "Ultra", "Experimental" }
    local presets = {
        { -- Lite
            hidePlayerFrame = true,
            showTunnelVision = true,
        },
        { -- Recommended
            hidePlayerFrame = true,
            showTunnelVision = true,
            hideTargetFrame = true,
            hideTargetTooltip = true,
            disableNameplateHealth = true,
            showDazedEffect = true,
            hideGroupHealth = true,
            hideMinimap = true,
        },
        { -- Ultra
            hidePlayerFrame = true,
            showTunnelVision = true,
            hideTargetFrame = true,
            hideTargetTooltip = true,
            disableNameplateHealth = true,
            showDazedEffect = true,
            hideGroupHealth = true,
            hideMinimap = true,
            petsDiePermanently = true,
            hideActionBars = true,
            tunnelVisionMaxStrata = true,
            rejectBuffsFromOthers = true,
            routePlanner = true,
        },
        { -- Experimental
            hidePlayerFrame = true,
            showTunnelVision = true,
            hideTargetFrame = true,
            hideTargetTooltip = true,
            disableNameplateHealth = true,
            showDazedEffect = true,
            hideGroupHealth = true,
            hideMinimap = true,
            petsDiePermanently = true,
            hideActionBars = true,
            tunnelVisionMaxStrata = true,
            hideBreathIndicator = true,
            showCritScreenMoveEffect = true,
            showIncomingDamageEffect = true,
            showHealingIndicator = true,
            setFirstPersonCamera = true,
            rejectBuffsFromOthers = true,
            routePlanner = true,
            completelyRemovePlayerFrame = true,
            completelyRemoveTargetFrame = true,
        }
    }

    -- Build the player's known settings table (true means explicitly enabled)
    local settings = nil
    if playerName == UnitName("player") and UltraHardcoreDB then
        local guid = UnitGUID("player")
        if guid and UltraHardcoreDB.characterSettings and UltraHardcoreDB.characterSettings[guid] then
            settings = UltraHardcoreDB.characterSettings[guid]
        elseif UltraHardcoreDB.GLOBAL_SETTINGS then
            -- backward compat until everyone has migrated
            settings = UltraHardcoreDB.GLOBAL_SETTINGS
        end
    elseif seen[playerName] and seen[playerName].customSettings then
        settings = {}
        for _, settingId in ipairs(seen[playerName].customSettings) do
            local id = tonumber(settingId)
            for _, option in ipairs(settingsCheckboxOptions) do
                if option.id == id then
                    settings[option.dbSettingsValueName] = true
                    break
                end
            end
        end
    end

    local cache = UltraHardcoreLeaderboardDB and UltraHardcoreLeaderboardDB.cache
    cache = cache and cache[playerName]

    if not settings and cache then
        -- 1) Prefer exact customSettings from cache if present
        if type(cache.customSettings) == "table" and next(cache.customSettings) ~= nil then
            settings = {}
            for _, settingId in ipairs(cache.customSettings) do
                local id = tonumber(settingId)
                for _, option in ipairs(settingsCheckboxOptions) do
                    if option.id == id then
                        settings[option.dbSettingsValueName] = true
                        break
                    end
                end
            end
        end

        -- 2) If still nothing, normalize the preset string and map to your preset tiers
        if (not settings) or (next(settings) == nil) then
            local p = cache.preset
            if type(p) == "string" then
                -- normalize: lowercase, strip spaces and punctuation (handles "Lite +", "Lite+", "lite-plus", etc.)
                local norm = p:lower():gsub("%s+", ""):gsub("%p", "")
                local idx
                if norm:find("^lite") then
                    idx = 1
                elseif norm:find("^recommended") or norm == "rec" then
                    idx = 2
                elseif norm:find("^ultra") or norm == "ult" then
                    idx = 3
                elseif norm:find("^experimental") or norm == "exp" then
                    idx = 4
                end
                if idx then
                    settings = presets[idx]  -- use the default toggles for that tier
                end
            end
        end

        -- 3) Ensure the outward-facing preset name reflects cache if we fell back
        if settings and (not preset or preset == "Custom") and type(cache.preset) == "string" then
            preset = cache.preset   -- e.g., "Lite +"
        end
    end

    -- Determine preset for leaderboard column
    local function trueKeys(t)
        local s = {}
        if t then for k, v in pairs(t) do if v == true then s[k] = true end end end
        return s
    end
    local function hasAll(have, need)
        for k in pairs(need) do if not have[k] then return false end end
        return true
    end
    local function hasAny(have, subset)
        for k in pairs(subset) do if have[k] then return true end end
        return false
    end

    -- Tier sets (cumulative)
    local L = trueKeys(presets[1])            -- Lite
    local R = trueKeys(presets[2])            -- Recommended (includes Lite)
    local U = trueKeys(presets[3])            -- Ultra (includes Recommended)
    local E = trueKeys(presets[4])            -- Experimental (includes Ultra)

    -- Exclusive deltas (new options introduced at each tier)
    local R_only = {}; for k in pairs(R) do if not L[k] then R_only[k] = true end end
    local U_only = {}; for k in pairs(U) do if not R[k] then U_only[k] = true end end
    local E_only = {}; for k in pairs(E) do if not U[k] then E_only[k] = true end end

    -- Player's enabled set (restricted to known tier keys)
    local player = {}
    if settings then
        for k in pairs(L) do if settings[k] == true then player[k] = true end end
        for k in pairs(R_only) do if settings[k] == true then player[k] = true end end
        for k in pairs(U_only) do if settings[k] == true then player[k] = true end end
        for k in pairs(E_only) do if settings[k] == true then player[k] = true end end
    end

    local preset
    if not settings then
        -- fallback to what you already store remotely when no local settings
        preset = seen[playerName] and seen[playerName].preset or "Custom"
    else
        if hasAll(player, E) then
            -- full Experimental (top tier; nothing above it to be partial)
            preset = "Experimental"
        elseif hasAll(player, U) then
            -- full Ultra; add "+" if any Experimental-only entries are toggled
            preset = hasAny(player, E_only) and "Ultra +" or "Ultra"
        elseif hasAll(player, R) then
            -- full Recommended; add "+" if any Ultra-only entries are toggled
            preset = hasAny(player, U_only) and "Recommended +" or "Recommended"
        elseif hasAll(player, L) then
            -- full Lite; add "+" if any options from higher tiers are toggled
            preset = (hasAny(player, R_only) or hasAny(player, U_only) or hasAny(player, E_only)) and "Lite +" or "Lite"
        else
            -- didn't fully satisfy Lite
            preset = "Custom"
        end
    end

    local tooltipText = {}
    table.insert(tooltipText, "|cffffd100Settings Enabled|r")
    table.insert(tooltipText, " ")

    local RED   = "|cfff44336"
    local WHITE = "|cffffffff"
    local GRAY  = "|cff414141"
    local END   = "|r"

    local nameByKey = {}
    for _, opt in ipairs(settingsCheckboxOptions) do
        nameByKey[opt.dbSettingsValueName] = opt.name
    end

    -- Helper: take only the 'true' keys from a preset table
    local function enabledSet(t)
        local s = {}
        if t then
            for k, v in pairs(t) do
            if v == true then s[k] = true end
            end
        end
        return s
    end

    local L = enabledSet(presets[1])
    local R = enabledSet(presets[2])
    local U = enabledSet(presets[3])
    local E = enabledSet(presets[4])

    local L_only = L
    local R_only = {}
    for k in pairs(R) do if not L[k] then R_only[k] = true end end
    local U_only = {}
    for k in pairs(U) do if not R[k] then U_only[k] = true end end
    local E_only = {}
    for k in pairs(E) do if not U[k] then E_only[k] = true end end

    local sections = {
        { title = "Lite",          keys = L_only },
        { title = "Recommended",   keys = R_only },
        { title = "Ultra",         keys = U_only },
        { title = "Experimental",  keys = E_only },
    }

    for i, sec in ipairs(sections) do
        table.insert(tooltipText, RED .. sec.title .. END)

        local hadAny = false
        for _, opt in ipairs(settingsCheckboxOptions) do
            local key = opt.dbSettingsValueName
            if sec.keys[key] then
            hadAny = true
            local enabled = (settings and settings[key] == true)
            table.insert(tooltipText, (enabled and WHITE or GRAY) .. (nameByKey[key] or key) .. END)
            end
        end

        if not hadAny then
            table.insert(tooltipText, GRAY .. "(none)" .. END)
        end
        if i < #sections then table.insert(tooltipText, " ") end
    end

return preset, table.concat(tooltipText, "\n")
end

function UHCLB_GetLocalSettingsIdList()
    local ids = {}
    if UltraHardcoreDB and settingsCheckboxOptions then
        local guid = UnitGUID("player")
        local s = (guid and UltraHardcoreDB.characterSettings and UltraHardcoreDB.characterSettings[guid])
                or UltraHardcoreDB.GLOBAL_SETTINGS
        if s then
        for _, opt in ipairs(settingsCheckboxOptions) do
            if s[opt.dbSettingsValueName] then
            table.insert(ids, opt.id)
            end
        end
        end
    end
    return ids
end

local function FormatNumber(num)
    if num >= 1000 then
        return string.format("%.1fk", num / 1000)
    end
    return tostring(num)
end

function addon:OnCommReceived(prefix, msg, dist, sender)
    local net = self:GetModule("Network", true)
    if net and net.OnCommReceived then
        net:OnCommReceived(prefix, msg, dist, sender)
    end
end

function SendAnnounce()
    local net = addon:GetModule("Network", true)
    if net and net.SendDelta then
        net:SendDelta()
    end
    if FRAME and FRAME:IsShown() then
        FRAME.RefreshLeaderboardUI()
    end
end

local function StartAnnounceTicker()
    C_Timer.NewTicker(60, SendAnnounce)
end

function addon:RefreshUIIfVisible()
  if FRAME and FRAME:IsShown() then
    FRAME.RefreshLeaderboardUI()
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("PLAYER_DEAD")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:RegisterEvent("MODIFIER_STATE_CHANGED")

ev:SetScript("OnEvent", function(_, e, key, state)
    if e == "PLAYER_LOGIN" then
        -- Initialize cache
        local cache = addon:GetModule("Cache", true)
        if cache and cache.Init then cache:Init() end

        -- Show welcome message on first login
        C_Timer.After(1, function()
            addon:ShowWelcomeMessage()
        end)

        -- Announce 3 seconds after login and every 60 seconds
        C_Timer.After(3, SendAnnounce)
        StartAnnounceTicker()

        -- Ask a few peers for their recent cache
        local net = addon:GetModule("Network", true)
        if net and net.SendSnapReq then
            C_Timer.After(5, function()
                net:SendSnapReq()
            end)
        end
    elseif e == "PLAYER_LOGOUT" then
        local net = addon:GetModule("Network", true)
        if net and net.SendOfflineDelta then
            net:SendOfflineDelta()
        end
	elseif e == "MODIFIER_STATE_CHANGED" then
	  local net = addon:GetModule("Network", true)
	  if key == "LALT" and FRAME and FRAME:IsShown() and net and net:IsDebug() then
	    FRAME.RefreshLeaderboardUI()
	  end
    elseif e == "PLAYER_DEAD" then
        local net = addon:GetModule("Network", true)
        if net and net.MarkDeadAndSend then
            net:MarkDeadAndSend()
        end
        return
    else
        -- Coalesce other events into a short delay
        C_Timer.After(2, SendAnnounce)
    end
end)


function addon:OnDisable()
  ev:UnregisterAllEvents()
end

-- Function to show welcome message popup on first login
function addon:ShowWelcomeMessage()
    if not self.db.profile.welcomeMessageShown then
        -- Create a simple popup dialog
        StaticPopup_Show("UltraHardcore Leaderboard Message")
        -- Mark as shown
        self.db.profile.welcomeMessageShown = true
    end
end

-- Define the welcome message popup
StaticPopupDialogs["UltraHardcore Leaderboard Message"] = {
    text = "The Ultra Hardcore Leaderboard no longer tracks your achievements. That has been made into a plugin for Ultra Hardcore and is a separate addon. You can find it at \n\n https://www.curseforge.com/wow/addons/hardcore-achievements",
    button1 = "Got it!",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function()
        -- Popup automatically closes
    end,
}

C_Timer.NewTicker(60, function()
  local now = (GetServerTime and GetServerTime()) or time()
  for name, row in pairs(seen) do
    if (now - (row.last or 0)) > 600 then
      seen[name] = nil
    end
  end
  if addon.RefreshUIIfVisible then
    addon:RefreshUIIfVisible()
  end
end)

local function UHLB_ShouldShowLVersion()
    return IsLeftAltKeyDown()
end

local ROW_HEIGHT = 18
local VISIBLE_ROWS = 18
local COLS = {
    { key = "name",    title = "Player Name", width = 100, align = "CENTER" },
    { key = "level",   title = "Lvl",        width = 50,  align = "CENTER" },
    { key = "class",   title = "Class",      width = 60,  align = "CENTER" },
    { key = "preset",  title = "Preset",     width = 100,  align = "CENTER" },
    { key = "lowestHealth", title = "Lowest HP", width = 90, align = "CENTER" },
    { key = "elitesSlain", title = "Elites", width = 60, align = "CENTER" },
    { key = "enemiesSlain", title = "Enemies", width = 80, align = "CENTER" },
    { key = "achievements", title = "Achievements", width = 110, align = "CENTER" },
    { key = "seen",    title = "Updated",       width = 80,  align = "CENTER" },
    { key = "version", title = "Version",    width = 70,  align = "CENTER" },
}

local sortState = {
    key = nil,
    asc = true
}

local function isDead(e)
    return e and e.dead == true
end

local function valueForSort(e, key)
    if key == "seen" then
        return tonumber(e.lastSeenSec) or math.huge
    elseif key == "name" or key == "class" or key == "preset" or key == "version" then
        return tostring(e[key] or ""):lower()
    elseif key == "online" then
        return e.online and 1 or 0
    elseif key == "achievements" then
        return tonumber(e.achievementPoints) or 0
    else
        return tonumber(e[key]) or 0
    end
end

local function DefaultCompare(a, b)
    -- 0) Dead (0% lowest HP) always at the bottom
    -- local ad, bd = isDead(a), isDead(b)
    -- if ad ~= bd then
    --     return not ad
    -- end

    -- 1) Online first (true > false)
    local ao = a.online and 1 or 0
    local bo = b.online and 1 or 0
    if ao ~= bo then
        return ao > bo
    end

    -- 2) Level (higher first)
    if a.level ~= b.level then
        return (a.level or 0) > (b.level or 0)
    end

    -- 3) Name (A → Z, case-insensitive)
    local an = tostring(a.name or ""):lower()
    local bn = tostring(b.name or ""):lower()
    if an ~= bn then
        return an < bn
    end

    -- 4) Last seen (more recent first: smaller seconds-since → higher rank)
    local aLast = a.lastSeenSec or math.huge
    local bLast = b.lastSeenSec or math.huge
    return aLast < bLast
end

local function ApplySort(entries)
    if sortState.key then
        local key, asc = sortState.key, sortState.asc
        table.sort(entries, function(a, b)
            -- Dead-bottom rule still applies even for header sorts
            -- local ad, bd = isDead(a), isDead(b)
            -- if ad ~= bd then
            --     return not ad
            -- end

            local va, vb = valueForSort(a, key), valueForSort(b, key)
            if va == vb then
                -- stable-ish tiebreakers: Level desc, then Name asc
                if (a.level or 0) ~= (b.level or 0) then
                    return (a.level or 0) > (b.level or 0)
                end
                return tostring(a.name or ""):lower() < tostring(b.name or ""):lower()
            end
            if asc then
                return va < vb
            else
                return va > vb
            end
        end)
    else
        table.sort(entries, DefaultCompare)
    end
end

local function UpdateHeaderArrows()
    if not HEADER then
        return
    end
    for i, col in ipairs(COLS) do
        local txt = col.title
        if sortState.key == col.key then
            txt = txt .. (sortState.asc and " |TInterface\\MainMenuBar\\UI-MainMenu-ScrollUpButton-Up:30:25|t" or " |TInterface\\MainMenuBar\\UI-MainMenu-ScrollDownButton-Up:30:25|t")
            --txt = txt .. (sortState.asc and " |TInterface\\Buttons\\arrow-up-down:15:15:0:-2|t" or " |TInterface\\Buttons\\arrow-down-down:15:15:0:2|t")
        end
        HEADER[i]:SetText(txt)
    end
end

local UHLB_ContextMenu
local UHLB_ContextTarget

local function UHLB_IsInviteDisabled(name)
    if not name or name == UnitName("player") or (IsInGroup() and not (UnitIsGroupLeader("player") or (IsInRaid() and UnitIsGroupAssistant("player")))) then return true end
    return false
end

UHLB_ContextMenu = CreateFrame("Frame", "UHLB_ContextMenu", UIParent, "UIDropDownMenuTemplate")

-- Bind initializer: builds Whisper / Invite menu for the current UHLB_ContextTarget
UIDropDownMenu_Initialize(UHLB_ContextMenu, function(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo()
    if (level or 1) == 1 then
        -- Title (player name)
        info = UIDropDownMenu_CreateInfo()
        info.text = UHLB_ContextTarget or "Player"
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        -- Whisper
        info = UIDropDownMenu_CreateInfo()
        info.text = "Whisper"
        info.notCheckable = true
        info.func = function()
            if UHLB_ContextTarget then
                if ChatFrame_OpenChat then
                    ChatFrame_OpenChat("/w " .. UHLB_ContextTarget .. " ")
                end
            end
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info, level)

        -- Invite
        info = UIDropDownMenu_CreateInfo()
        info.text = "Invite to Group"
        info.notCheckable = true
        info.disabled = UHLB_IsInviteDisabled(UHLB_ContextTarget)
        info.func = function()
            if UHLB_ContextTarget then
                if C_PartyInfo and C_PartyInfo.InviteUnit then
                    C_PartyInfo.InviteUnit(UHLB_ContextTarget)
                else
                    InviteUnit(UHLB_ContextTarget)
                end
            end
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info, level)

        -- Cancel
        info = UIDropDownMenu_CreateInfo()
        info.text = "Cancel"
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
    end
end, "MENU")

-- Helper to show the menu at the cursor
local function UHLB_ShowContextMenuFor(name)
    if not name or name == "" then return end
    UHLB_ContextTarget = name
    ToggleDropDownMenu(1, nil, UHLB_ContextMenu, "cursor", 3, -3)
end

local function CreateMainFrame()
    local f = CreateFrame("Frame", "UHLB_LeaderboardFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetFrameStrata("HIGH")
    f:SetSize(940, 420)
    f:SetPoint("CENTER")
    f:Hide()

    	-- Allow closing with ESC key via UISpecialFrames
	local frameName = f:GetName()
	local exists = false
	for i = 1, #UISpecialFrames do
		if UISpecialFrames[i] == frameName then
			exists = true
			break
		end
	end
	if not exists then
		table.insert(UISpecialFrames, frameName)
	end

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("CENTER", f.TitleBg, "CENTER")
    -- Set initial title based on restriction setting
    if addon.db.profile.restrictToGuild then
        f.title:SetText("|cfff44336Ultra Hardcore — Guild Live Leaderboard|r")
    else
        f.title:SetText("|cfff44336Ultra Hardcore — Realm Live Leaderboard|r")
    end

    local totalWidth = 0
    for _, col in ipairs(COLS) do
        totalWidth = totalWidth + col.width + 10
    end
    totalWidth = totalWidth - 10

    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -28)
    header:SetSize(totalWidth, 20)

    HEADER = {}
    local x = 0
    for i, col in ipairs(COLS) do
        local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", header, "LEFT", x, 0)
        fs:SetSize(col.width, 20)
        fs:SetJustifyH(col.align or "CENTER")
        fs:SetJustifyV("MIDDLE")
        fs:SetText(col.title)
        fs:EnableMouse(true)
        fs:SetScript("OnMouseUp", function(_, button)
            if button ~= "LeftButton" then return end
            if sortState.key == col.key then
                sortState.asc = not sortState.asc
            else
                sortState.key = col.key
                -- Simple convention: numbers default desc for first click, strings asc
                local numeric = (col.key ~= "name" and col.key ~= "class" and col.key ~= "preset" and col.key ~= "version" and col.key ~= "seen")
                sortState.asc = not numeric
            end
            UpdateHeaderArrows()
            f.RefreshLeaderboardUI()
        end)
        HEADER[i] = fs
        x = x + col.width + 10
    end

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 36)
    SCROLL = scroll

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(totalWidth, 1)
    scroll:SetScrollChild(child)
    SCROLL_CHILD = child

    leaderboardRows = {}
    for i = 1, VISIBLE_ROWS + 2 do
        local row = CreateFrame("Frame", nil, child)
        row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -((i-1) * ROW_HEIGHT))
        row:SetSize(totalWidth, ROW_HEIGHT)
        row:EnableMouse(true)
        row.cols = {}
        local xOffset = 0
        for j, col in ipairs(COLS) do
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("TOPLEFT", row, "TOPLEFT", xOffset, 0)
            fs:SetWidth(col.width)
            fs:SetHeight(ROW_HEIGHT)
            fs:SetJustifyH(COLS[j].align or "CENTER")
            fs:SetJustifyV("MIDDLE")
            row.cols[j] = fs
            xOffset = xOffset + col.width + 10
        end
        row:Hide()

        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints(row)
        row.highlight:SetColorTexture(0.95, 0.26, 0.21, 0.25)
        row.highlight:Hide()

        row:SetScript("OnMouseUp", function(self, button)
            if button == "RightButton" and self.name and self.online then
                UHLB_ShowContextMenuFor(self.name)
            elseif button == "LeftButton" and self.name then
                CloseDropDownMenus()
            end
        end)
        row:SetScript("OnEnter", function(self)
            if self.online then
                self.highlight:SetColorTexture(0.95, 0.26, 0.21, 0.25)
            else
                self.highlight:SetColorTexture(0.60, 0.60, 0.60, 0.25)
            end
            self.highlight:Show()

            if self.name and self.tooltipText then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 36, self:GetHeight() * -1)
                GameTooltip:SetText(self.name, 1, 1, 1)
                GameTooltip:AddLine(self.tooltipText, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function(self)
            self.highlight:Hide()
            GameTooltip:Hide()
        end)
        leaderboardRows[i] = row
    end

    -- Add guild restriction checkbox
    local guildCheckbox = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    guildCheckbox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
    guildCheckbox:SetSize(20, 20)
    guildCheckbox:SetChecked(addon.db.profile.restrictToGuild)
    
    local guildCheckboxLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    guildCheckboxLabel:SetPoint("LEFT", guildCheckbox, "RIGHT", 5, 0)
    guildCheckboxLabel:SetText("Restrict to Guild")
    
    guildCheckbox:SetScript("OnClick", function(self)
        addon.db.profile.restrictToGuild = self:GetChecked()
        -- Update title based on restriction setting
        if addon.db.profile.restrictToGuild then
            f.title:SetText("|cfff44336Ultra Hardcore — Guild Live Leaderboard|r")
        else
            f.title:SetText("|cfff44336Ultra Hardcore — Realm Live Leaderboard|r")
        end
        f.RefreshLeaderboardUI()
    end)

    local hint = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("CENTER", f, "BOTTOM", 0, 20)
    hint:SetJustifyH("CENTER")
    hint:SetJustifyV("MIDDLE")
    hint:SetText("|cffbbbbbbData may take up to 60 seconds to fully propagate after logging in|r")

    -- Player count label in bottom right corner
    local playerCountLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    playerCountLabel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -15, 14)
    playerCountLabel:SetJustifyH("RIGHT")
    playerCountLabel:SetJustifyV("MIDDLE")
    playerCountLabel:SetText("Players online: 0/0")

    f.CloseButton:SetScript("OnClick", function() f:Hide() end)

    -- Helper function to convert hex color to RGB
    local function hexToRgb(hex)
        local r = tonumber(hex:sub(1, 2), 16)
        local g = tonumber(hex:sub(3, 4), 16)
        local b = tonumber(hex:sub(5, 6), 16)
        return r, g, b
    end
    
    -- Helper function to convert RGB to hex
    local function rgbToHex(r, g, b)
        return string.format("%02x%02x%02x", math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5))
    end
    
    -- Helper function to interpolate between two colors
    local function interpolateColor(color1, color2, t)
        -- Clamp t between 0 and 1
        t = math.max(0, math.min(1, t))
        
        local r1, g1, b1 = hexToRgb(color1)
        local r2, g2, b2 = hexToRgb(color2)
        
        local r = r1 + (r2 - r1) * t
        local g = g1 + (g2 - g1) * t
        local b = b1 + (b2 - b1) * t
        
        return rgbToHex(r, g, b)
    end
    
    -- Helper function to get achievement completion color based on percentage with smooth gradients
    local function GetAchievementColor(completed, total)
        if not total or total == 0 then
            return "9d9d9d"  -- Gray for 0%
        end
        
        local percentage = (completed or 0) / total * 100
        
        if percentage == 0 then
            return "9d9d9d"  -- Gray
        elseif percentage > 0 and percentage < 20 then
            -- Gradient from Gray (0%) to White (20%)
            local t = percentage / 20
            return interpolateColor("9d9d9d", "ffffff", t)
        elseif percentage >= 20 and percentage < 40 then
            -- Gradient from White (20%) to Green (40%)
            local t = (percentage - 20) / 20
            return interpolateColor("ffffff", "1eff00", t)
        elseif percentage >= 40 and percentage < 60 then
            -- Gradient from Green (40%) to Blue (60%)
            local t = (percentage - 40) / 20
            return interpolateColor("1eff00", "0070dd", t)
        elseif percentage >= 60 and percentage < 80 then
            -- Gradient from Blue (60%) to Purple (80%)
            local t = (percentage - 60) / 20
            return interpolateColor("0070dd", "a335ee", t)
        else
            -- Gradient from Purple (80%) to Orange (100%)
            local t = (percentage - 80) / 20
            return interpolateColor("a335ee", "ff8000", t)
        end
    end

    function f.RefreshLeaderboardUI(levelSort)
        local data = addon:GetModule("Data", true)
        local rows = data and data:BuildRowsForUI(seen) or {}
        local entries = {}
        local net = addon:GetModule("Network", true)
        for _, r in ipairs(rows) do
            local preset, tooltipText = GetPresetAndTooltip(r.name)

            local shownVersion
            if IsLeftAltKeyDown() and net and net:IsDebug() then
                local sv = seen[r.name]
                shownVersion = (sv and sv.LVersion) or r.version
            else
                shownVersion = r.version
            end
            table.insert(entries, {
                name = r.name,
                level = r.level,
                class = r.class,
                lowestHealth = r.lowestHealth,
                elitesSlain = r.elitesSlain,
                enemiesSlain = r.enemiesSlain,
                achievementsCompleted = r.achievementsCompleted,
                achievementsTotal = r.achievementsTotal,
                achievementPoints = r.achievementPoints,
                preset = preset,
                seen = r.lastSeenText,
                version = shownVersion,
                tooltipText = tooltipText,
                online = r.online,
                lastSeenSec = r.lastSeenSec,
				dead = r.dead,
                guild = r.guild,
            })
        end

        ApplySort(entries)

        -- Count online and total players
        local onlineCount = 0
        local totalCount = #entries
        for _, e in ipairs(entries) do
            if e.online then
                onlineCount = onlineCount + 1
            end
        end
        
        -- Update player count label
        playerCountLabel:SetText(string.format("Players online: %d/%d", onlineCount, totalCount))

        for _, row in ipairs(leaderboardRows) do row:Hide() end
        local totalHeight = #entries * ROW_HEIGHT
        SCROLL_CHILD:SetHeight(math.max(totalHeight, VISIBLE_ROWS * ROW_HEIGHT))

        for i, e in ipairs(entries) do
            local row = leaderboardRows[i]
            if not row then
                row = CreateFrame("Frame", nil, SCROLL_CHILD)
                row:SetPoint("TOPLEFT", SCROLL_CHILD, "TOPLEFT", 0, -((i-1) * ROW_HEIGHT))
                row:SetSize(totalWidth, ROW_HEIGHT)
                row:EnableMouse(true)

                row.highlight = row:CreateTexture(nil, "BACKGROUND")
                row.highlight:SetAllPoints(row)
                row.highlight:SetColorTexture(0.95, 0.26, 0.21, 0.25)
                row.highlight:Hide()

                row.cols = {}
                local xOffset = 0
                for j, col in ipairs(COLS) do
                    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    fs:SetPoint("TOPLEFT", row, "TOPLEFT", xOffset, 0)
                    fs:SetWidth(col.width)
                    fs:SetHeight(ROW_HEIGHT)
                    fs:SetJustifyH(COLS[j].align or "CENTER")
                    fs:SetJustifyV("MIDDLE")
                    row.cols[j] = fs
                    xOffset = xOffset + col.width + 10
                end

                -- Add a hidden background highlight
                row.highlight = row:CreateTexture(nil, "BACKGROUND")
                row.highlight:SetAllPoints(row)
                row.highlight:SetColorTexture(0.95, 0.26, 0.21, 0.25)
                row.highlight:Hide()

                row:SetScript("OnMouseUp", function(self, button)
                    if button == "RightButton" and self.name and self.online then
                        UHLB_ShowContextMenuFor(self.name)
                    elseif button == "LeftButton" and self.name then
                        CloseDropDownMenus()
                    end
                end)
                row:SetScript("OnEnter", function(self)
                    if self.online then
                        self.highlight:SetColorTexture(0.95, 0.26, 0.21, 0.25)
                    else
                        self.highlight:SetColorTexture(0.60, 0.60, 0.60, 0.25)
                    end
                    self.highlight:Show()

                    if self.name and self.tooltipText then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 36, self:GetHeight() * -1)
                        GameTooltip:SetText(self.name, 1, 1, 1)
                        GameTooltip:AddLine(self.tooltipText, 1, 1, 1, true)
                        GameTooltip:Show()
                    end
                end)
                row:SetScript("OnLeave", function(self)
                    self.highlight:Hide()
                    GameTooltip:Hide()
                end)
                leaderboardRows[i] = row
            end

            local base = e.name
            local maxChars = 18

            if string.len(base) > maxChars then
            base = string.sub(base, 1, maxChars - 2) .. "."
            end

            -- Prefix a skull icon for dead players using an inline texture
            if isDead(e) then
            local skull = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:12:12:0:0|t "
            base = skull .. base
            end

            row.cols[1]:SetText(base)
            row.cols[2]:SetText(e.level)
            row.cols[3]:SetText(e.class)
            row.cols[4]:SetText(e.preset)
            row.cols[5]:SetText(e.lowestHealth .. "%")
            row.cols[6]:SetText(e.elitesSlain)
            row.cols[7]:SetText(e.enemiesSlain)
            -- Format achievement points with colored completion bracket
            local completed = e.achievementsCompleted or 0
            local total = e.achievementsTotal or 0
            local colorCode = GetAchievementColor(completed, total)
            row.cols[8]:SetText(string.format("%d pts |cff%s[%d/%d]|r", e.achievementPoints or 0, colorCode, completed, total))
            row.cols[9]:SetText(e.seen)
            row.cols[10]:SetText(e.version)
            

            row.name = e.name
            row.tooltipText = e.tooltipText
            row.online = e.online and true or false

            if not row.online then row.highlight:Hide() end

            local isOffline = not row.online

            -- Default colors for all columns
            local r,g,b = isOffline and 0.65 or 1, isOffline and 0.65 or 1, isOffline and 0.65 or 1
            
            -- Special colors for dead players
            if isDead(e) then
                r, g, b = 0.95, 0.26, 0.21  -- Red for dead players
            end

            -- Color all columns with default colors
            for _, fs in ipairs(row.cols) do
                fs:SetTextColor(r, g, b)
            end
            
            -- Special coloring for player name (first column) - guild members in global view
            if isGlobalView and isGuildMember then
                row.cols[1]:SetTextColor(0.4, 0.8, 0.4)  -- Light green for guild member names in global view
            end
            row:SetAlpha(isOffline and 0.75 or 1)

            row:Show()
        end

        SCROLL:UpdateScrollChildRect()
    end

    return f
end

C_Timer.After(1, function()
    if not FRAME then FRAME = CreateMainFrame() end
end)

------------------------------------------------------------
-- Slash command to toggle
------------------------------------------------------------
SLASH_UHLB1 = "/uhlb"
SLASH_UHLB2 = "/uhclb"  -- old alias kept

SlashCmdList.UHLB = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")

  -- default: toggle the UI
  if msg == "" or msg == "toggle" then
    if not FRAME then FRAME = CreateMainFrame() end
    if FRAME:IsShown() then
      FRAME:Hide()
    else
      FRAME:Show()
      FRAME.RefreshLeaderboardUI(true)
    end
    return
  end

  -- debug toggle
  if msg == "debug" then
    local net = addon and addon:GetModule("Network", true)
    if net then
      net:SetDebug(not net:IsDebug())
      print("|cff66ccffUHLB|r debug:", tostring(net:IsDebug()))
    end
    return
  end
end

