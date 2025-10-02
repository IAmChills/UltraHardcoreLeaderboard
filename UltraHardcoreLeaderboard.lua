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
        },
    })
    addonIcon:Register("UltraHardcoreLeaderboard", addonLDB, self.db.profile.minimap)
    self:RegisterComm("UHLB", "OnCommReceived")
end

local settingsCheckboxOptions = {
    { id = 1, name = "Hide Player Frame", dbSettingsValueName = "hidePlayerFrame" },
    { id = 2, name = "Hide Minimap", dbSettingsValueName = "hideMinimap" },
    { id = 3, name = "Use Custom Buff Frame", dbSettingsValueName = "hideBuffFrame" },
    { id = 4, name = "Hide Target Frame", dbSettingsValueName = "hideTargetFrame" },
    { id = 5, name = "Hide Target Tooltips", dbSettingsValueName = "hideTargetTooltip" },
    { id = 6, name = "Death Indicator (Tunnel Vision)", dbSettingsValueName = "showTunnelVision" },
    { id = 7, name = "Tunnel Vision Covers Everything", dbSettingsValueName = "tunnelVisionMaxStrata" },
    { id = 8, name = "Hide Quest UI", dbSettingsValueName = "hideQuestFrame" },
    { id = 9, name = "Show Dazed Effect", dbSettingsValueName = "showDazedEffect" },
    { id = 10, name = "Show Crit Screen Shift Effect", dbSettingsValueName = "showCritScreenMoveEffect" },
    { id = 11, name = "Hide Action Bars when not resting", dbSettingsValueName = "hideActionBars" },
    { id = 12, name = "Hide Group Health", dbSettingsValueName = "hideGroupHealth" },
    { id = 13, name = "Pets Die Permanently", dbSettingsValueName = "petsDiePermanently" },
    { id = 14, name = "Show Full Health Indicator", dbSettingsValueName = "showFullHealthIndicator" },
    { id = 15, name = "Disable Nameplate Information", dbSettingsValueName = "disableNameplateHealth" },
    { id = 16, name = "Show Incoming Damage Effect", dbSettingsValueName = "showIncomingDamageEffect" },
    { id = 17, name = "Breath Indicator (Red Overlay)", dbSettingsValueName = "hideBreathIndicator" },
}

function GetPresetAndTooltip(playerName)
    local presetNames = { "Lite", "Recommended", "Experimental" }
    local presets = {
        { -- Lite
            hidePlayerFrame = true,
            hideMinimap = false,
            hideBuffFrame = false,
            hideTargetFrame = false,
            hideTargetTooltip = false,
            showTunnelVision = true,
            tunnelVisionMaxStrata = false,
            hideQuestFrame = false,
            showDazedEffect = false,
            showCritScreenMoveEffect = false,
            hideActionBars = false,
            hideGroupHealth = false,
            petsDiePermanently = false,
            showFullHealthIndicator = false,
            disableNameplateHealth = false,
            showIncomingDamageEffect = false,
            hideBreathIndicator = false,
        },
        { -- Recommended
            hidePlayerFrame = true,
            hideMinimap = true,
            hideBuffFrame = true,
            hideTargetFrame = true,
            hideTargetTooltip = true,
            showTunnelVision = true,
            tunnelVisionMaxStrata = true,
            hideQuestFrame = true,
            showDazedEffect = true,
            hideGroupHealth = true,
            showCritScreenMoveEffect = false,
            hideActionBars = false,
            petsDiePermanently = false,
            showFullHealthIndicator = false,
            disableNameplateHealth = true,
            showIncomingDamageEffect = false,
            hideBreathIndicator = true,
        },
        { -- Ultra
            hidePlayerFrame = true,
            hideMinimap = true,
            hideBuffFrame = true,
            hideTargetFrame = true,
            hideTargetTooltip = true,
            showTunnelVision = true,
            tunnelVisionMaxStrata = true,
            showFullHealthIndicator = true,
            disableNameplateHealth = true,
            showIncomingDamageEffect = true,
            hideQuestFrame = true,
            showDazedEffect = true,
            showCritScreenMoveEffect = true,
            hideActionBars = true,
            hideGroupHealth = true,
            petsDiePermanently = true,
            hideBreathIndicator = true,
        }
    }

    local tooltipText = {}
    table.insert(tooltipText, "|cffffd100Settings Enabled|r")
    table.insert(tooltipText, " ")

    local preset = "Custom"
    local settings = nil

    -- Determine settings source
    if playerName == UnitName("player") and UltraHardcoreDB and UltraHardcoreDB.GLOBAL_SETTINGS then
        settings = UltraHardcoreDB.GLOBAL_SETTINGS
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

    -- Determine preset for leaderboard column
    if settings then
        for i, presetSettings in ipairs(presets) do
            local isMatch = true
            for key, value in pairs(presetSettings) do
                if settings[key] ~= value then
                    isMatch = false
                    break
                end
            end
            if isMatch then
                preset = presetNames[i]
                break
            end
        end
    else
        preset = seen[playerName] and seen[playerName].preset or "Custom"
    end

    -- Generate tooltip based on settings
    if settings then
        local hasSettings = false
        for _, option in ipairs(settingsCheckboxOptions) do
            if settings[option.dbSettingsValueName] then
                table.insert(tooltipText, option.name)
                hasSettings = true
            end
        end
        if not hasSettings then
            table.insert(tooltipText, "No settings enabled")
        end
    else
        table.insert(tooltipText, "Error: Settings data unavailable")
    end

    return preset, table.concat(tooltipText, "\n")
end

function UHCLB_GetLocalSettingsIdList()
  local ids = {}
  if UltraHardcoreDB and UltraHardcoreDB.GLOBAL_SETTINGS and settingsCheckboxOptions then
    for _, opt in ipairs(settingsCheckboxOptions) do
      if UltraHardcoreDB.GLOBAL_SETTINGS[opt.dbSettingsValueName] then
        table.insert(ids, opt.id) -- matches how GetPresetAndTooltip reconstructs settings
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
ev:SetScript("OnEvent", function(_, e)
    if e == "PLAYER_LOGIN" then
        -- Initialize cache
        local cache = addon:GetModule("Cache", true)
        if cache and cache.Init then cache:Init() end

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
    else
        -- Coalesce other events into a short delay
        C_Timer.After(2, SendAnnounce)
    end
end)

function addon:OnDisable()
  ev:UnregisterAllEvents()
end

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

local ROW_HEIGHT = 18
local VISIBLE_ROWS = 18
local COLS = {
    { key = "name",    title = "Player Name", width = 100, align = "CENTER" },
    { key = "level",   title = "Lvl",        width = 40,  align = "CENTER" },
    { key = "class",   title = "Class",      width = 50,  align = "CENTER" },
    { key = "preset",  title = "Preset",     width = 80,  align = "CENTER" },
    { key = "seen",    title = "Seen",       width = 50,  align = "CENTER" },
    { key = "version", title = "Version",    width = 50,  align = "CENTER" },
    { key = "lowestHealth", title = "Lowest HP", width = 70, align = "CENTER" },
    { key = "elitesSlain", title = "Elites", width = 50, align = "CENTER" },
    { key = "enemiesSlain", title = "Enemies", width = 50, align = "CENTER" },
    { key = "xpGainedWithoutAddon", title = "XP w/o Addon", width = 90, align = "CENTER" },
}

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
    f:SetSize(770, 420)
    f:SetPoint("CENTER")
    f:Hide()

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("CENTER", f.TitleBg, "CENTER")
    f.title:SetText("|cfff44336Ultra Hardcore — Live Leaderboard|r")

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
                self.highlight:Show()
                if self.name and self.tooltipText then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 36, self:GetHeight() * -1)
                    GameTooltip:SetText(self.name, 1, 1, 1)
                    GameTooltip:AddLine(self.tooltipText, 1, 1, 1, true)
                    GameTooltip:Show()
                end
            end
        end)
        row:SetScript("OnLeave", function(self)
            self.highlight:Hide()
            GameTooltip:Hide()
        end)
        leaderboardRows[i] = row
    end

    local hint = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("CENTER", f, "BOTTOM", 0, 24)
    hint:SetJustifyH("CENTER")
    hint:SetJustifyV("MIDDLE")
    hint:SetText("|cffbbbbbbData may take up to 60 seconds to fully propagate after logging in|r")

    f.CloseButton:SetScript("OnClick", function() f:Hide() end)

    function f.RefreshLeaderboardUI(levelSort)
        local data = addon:GetModule("Data", true)
        local rows = data and data:BuildRowsForUI(seen) or {}
        local entries = {}
        for _, r in ipairs(rows) do
        local preset, tooltipText = GetPresetAndTooltip(r.name)
        table.insert(entries, {
            name = r.name,
            level = r.level,
            class = r.class,
            lowestHealth = r.lowestHealth,
            elitesSlain = r.elitesSlain,
            enemiesSlain = r.enemiesSlain,
            xpGainedWithoutAddon = r.xpGainedWithoutAddon,
            preset = preset,
            seen = r.lastSeenText,
            version = r.version,
            tooltipText = tooltipText,
            online = r.online,
        })
        end

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
                    if not self.online then return end
                    self.highlight:Show()
                    if self.name and self.tooltipText then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
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

            local nameText = e.name
            if string.len(nameText) > 18 then
                nameText = string.sub(nameText, 1, 16) .. ".."
            end
            row.cols[1]:SetText(nameText)
            row.cols[2]:SetText(e.level)
            row.cols[3]:SetText(e.class)
            row.cols[4]:SetText(e.preset)
            row.cols[5]:SetText(e.seen)
            row.cols[6]:SetText(e.version)
            row.cols[7]:SetText(e.lowestHealth .. "%")
            row.cols[8]:SetText(e.elitesSlain)
            row.cols[9]:SetText(e.enemiesSlain)
            row.cols[10]:SetText(FormatNumber(e.xpGainedWithoutAddon))

            row.name = e.name
            row.tooltipText = e.tooltipText
            row.online = e.online and true or false

            if not row.online then row.highlight:Hide() end

            local isOffline = not row.online

            local r,g,b = isOffline and 0.65 or 1, isOffline and 0.65 or 1, isOffline and 0.65 or 1
            for _, fs in ipairs(row.cols) do
            fs:SetTextColor(r, g, b)
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
