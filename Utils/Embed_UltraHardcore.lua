-- Embed_UltraHardcore.lua
-- Embeds HardcoreAchievements rows into the UltraHardcore Settings "Achievements" tab (tabContents[3])
-- Minimal UI: no backdrops/borders; shows icon, title, points, optional level, tooltip.

local ADDON_NAME = ...
local EMBED = {}
local DEST      -- tabContents[3]
local ROW_H     = 28
local PADDING_X = 6
local GAP_Y     = 4

local function GetSourceRows()
  if AchievementPanel and type(AchievementPanel.achievements) == "table" then
    return AchievementPanel.achievements
  end
end

local function ReadRowData(src)
  if not src then return nil end
  local title = ""
  if src.Title and src.Title.GetText then
    title = src.Title:GetText() or ""
  elseif type(src.id) == "string" then
    title = src.id
  end

  local iconTex
  if src.Icon and src.Icon.GetTexture then
    iconTex = src.Icon:GetTexture()
  end

  local data = {
    id        = src.id or title,
    title     = title,
    iconTex   = iconTex,
    tooltip   = src.tooltip or src.desc or title,
    points    = tonumber(src.points) or 0,
    maxLevel  = tonumber(src.maxLevel) or nil,
    completed = not not src.completed,
  }
  return data
end

local function CreateEmbedRow(parent)
  local row = CreateFrame("Button", nil, parent)
  row:SetSize(1, ROW_H) -- width set by layout
  row:RegisterForClicks("AnyUp")

  row.Icon = row:CreateTexture(nil, "ARTWORK")
  row.Icon:SetSize(22, 22)
  row.Icon:SetPoint("LEFT", parent, "LEFT", PADDING_X, 0)
  row.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  row.Title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.Title:SetPoint("LEFT", row.Icon, "RIGHT", 6, 0)
  row.Title:SetJustifyH("LEFT")

  row.Level = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  row.Level:SetPoint("LEFT", row.Title, "RIGHT", 8, 0)
  row.Level:SetJustifyH("LEFT")

  row.Points = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.Points:SetJustifyH("RIGHT")
  row.Points:SetPoint("RIGHT", parent, "RIGHT", -PADDING_X, 0)

  row:SetScript("OnEnter", function(self)
    if not self.tooltip or self.tooltip == "" then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.title or "", 1, 0.82, 0)
    GameTooltip:AddLine(self.tooltip, 0.9, 0.9, 0.9, true)
    if self.maxLevel then
      GameTooltip:AddLine(("Required max level: %d"):format(self.maxLevel), 0.7, 0.7, 0.7)
    end
    if type(self.points) == "number" then
      GameTooltip:AddLine(("Points: %d"):format(self.points), 0.7, 0.9, 0.7)
    end
    if self.completed then
      GameTooltip:AddLine("Completed", 0.6, 0.9, 0.6)
    end
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)

  return row
end

local function LayoutRows(container, rows)
  if not container or not rows then return end -- guard to avoid nil container
  local y = -PADDING_X

  for _, r in ipairs(rows) do
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
    r:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, y)
    r.Points:ClearAllPoints()
    r.Points:SetPoint("RIGHT", container, "RIGHT", -PADDING_X, 0)
    y = y - (ROW_H + GAP_Y)
    r:Show()
  end

  local neededH = (ROW_H + GAP_Y) * #rows + PADDING_X
  container:SetHeight(math.max(neededH, 1))
end

function EMBED:Rebuild()
  -- Hard guard: don't layout until destination content exists
  if not DEST or not DEST.Content then return end
  if not self.Content then self.Content = DEST.Content end

  local srcRows = GetSourceRows()
  if not srcRows then
    if self.rows then for _, r in ipairs(self.rows) do r:Hide() end end
    return
  end

  self.rows = self.rows or {}
  local needed = 0

  for _, srow in ipairs(srcRows) do
    if not srow._isHidden then
      needed = needed + 1
      local data = ReadRowData(srow)

      local row = self.rows[needed]
      if not row then
        row = CreateEmbedRow(self.Content)
        self.rows[needed] = row
      end

      row.id        = data.id
      row.title     = data.title
      row.tooltip   = data.tooltip
      row.points    = data.points
      row.maxLevel  = data.maxLevel
      row.completed = data.completed

      if data.iconTex then
        row.Icon:SetTexture(data.iconTex)
      else
        row.Icon:SetTexture(136116) -- generic achievement icon
      end

      row.Title:SetText(data.title or "")

      if data.maxLevel and data.maxLevel > 0 then
        -- Keep highlight color; optionally dim if your source flagged outleveled via red
        if srow.Title and srow.Title.GetTextColor then
          local r, g = srow.Title:GetTextColor()
          if r and r > 0.8 and g and g < 0.3 then
            row.Title:SetTextColor(0.9, 0.2, 0.2)
          else
            row.Title:SetTextColor(1, 0.82, 0)
          end
        else
          row.Title:SetTextColor(1, 0.82, 0)
        end
        row.Level:SetText(("≤%d"):format(data.maxLevel))
        row.Level:Show()
      else
        row.Title:SetTextColor(1, 0.82, 0)
        row.Level:SetText("")
        row.Level:Hide()
      end

      if data.points and data.points > 0 then
        row.Points:SetText(("%d pts"):format(data.points))
        if data.completed then
          row.Points:SetTextColor(0.6, 0.9, 0.6)
        else
          row.Points:SetTextColor(0.9, 0.9, 0.9)
        end
      else
        row.Points:SetText("")
      end
    end
  end

  for i = needed + 1, #self.rows do
    self.rows[i]:Hide()
  end

  LayoutRows(self.Content, self.rows)
end

local function BuildEmbedIfNeeded()
  if DEST and DEST.Scroll and DEST.Content and EMBED.Content then return true end
  if not tabContents or not tabContents[3] then return false end

  DEST = tabContents[3]

  DEST.Scroll = CreateFrame("ScrollFrame", nil, DEST, "UIPanelScrollFrameTemplate")
  DEST.Scroll:SetPoint("TOPLEFT", DEST, "TOPLEFT", 8, -8)
  DEST.Scroll:SetPoint("BOTTOMRIGHT", DEST, "BOTTOMRIGHT", -28, 12)

  DEST.Content = CreateFrame("Frame", nil, DEST.Scroll)
  DEST.Content:SetSize(1, 1)
  DEST.Scroll:SetScrollChild(DEST.Content)

  -- IMPORTANT: bind the content so Rebuild/LayoutRows get a valid container
  EMBED.Content = DEST.Content

  DEST:HookScript("OnShow", function()
    -- Ensure binding persists if something recreated frames
    if not EMBED.Content or EMBED.Content ~= DEST.Content then
      EMBED.Content = DEST.Content
    end
    EMBED:Rebuild()
  end)

  DEST.Scroll:SetScript("OnSizeChanged", function(self)
    self:UpdateScrollChildRect()
  end)

  return true
end

local function HookSourceSignals()
  if EMBED._hooked then return end
  if type(CheckPendingCompletions) == "function" then
    hooksecurefunc("CheckPendingCompletions", function()
      C_Timer.After(0, function() EMBED:Rebuild() end)
    end)
  end
  if type(UpdateTotalPoints) == "function" then
    hooksecurefunc("UpdateTotalPoints", function()
      C_Timer.After(0, function() EMBED:Rebuild() end)
    end)
  end
  EMBED._hooked = true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, arg1)
  if BuildEmbedIfNeeded() then
    HookSourceSignals()
    -- defer one frame so Settings tab sizing is ready before layout
    C_Timer.After(0, function() EMBED:Rebuild() end)
  else
    -- Try again shortly if tabContents not ready yet
    C_Timer.After(0.25, function()
      if BuildEmbedIfNeeded() then
        HookSourceSignals()
        C_Timer.After(0, function() EMBED:Rebuild() end)
      end
    end)
  end

  -- If source rows are not built yet, try another refresh shortly
  if not GetSourceRows() then
    C_Timer.After(1.0, function()
      HookSourceSignals()
      if DEST and DEST:IsShown() then EMBED:Rebuild() end
    end)
  end
end)
