local addon = LibStub("AceAddon-3.0"):GetAddon("UltraHardcoreLeaderboard")
local Cache  = addon:NewModule("Cache")  -- AceAddon module

UltraHardcoreLeaderboardDB       = UltraHardcoreLeaderboardDB or {}
UltraHardcoreLeaderboardDB.cache = UltraHardcoreLeaderboardDB.cache or {}
UltraHardcoreLeaderboardDB.tsIndex = UltraHardcoreLeaderboardDB.tsIndex or {}

Cache.PURGE_AGE = 7 * 24 * 60 * 60  -- 7 days in seconds
Cache.ACTIVE_THRESHOLD = 24 * 60 * 60  -- 24 hours for "active" players

-- Timestamp helper
local function Now()
  local t = GetServerTime and GetServerTime()
  return t
end

-- Maintain a sorted index of { name, ts } pairs
local function UpdateIndex(name, ts)
    local index = UltraHardcoreLeaderboardDB.tsIndex
    -- Remove existing entry for name
    for i, entry in ipairs(index) do
        if entry.name == name then
            table.remove(index, i)
            break
        end
    end
    -- Insert new entry in sorted order (newest first)
    local newEntry = { name = name, ts = ts }
    if #index == 0 then
        table.insert(index, newEntry)
    else
        for i, entry in ipairs(index) do
            if ts > entry.ts then
                table.insert(index, i, newEntry)
                return
            end
        end
        table.insert(index, newEntry) -- Append if oldest
    end
end

function Cache:Upsert(rec)
  UltraHardcoreLeaderboardDB.cache   = UltraHardcoreLeaderboardDB.cache   or {}
  UltraHardcoreLeaderboardDB.tsIndex = UltraHardcoreLeaderboardDB.tsIndex or {}
  if not rec or not rec.name or not rec.ts or type(rec.ts) ~= "number" then
    if addon:GetModule("Network", true):IsDebug() then
      print("|cff66ccffUHLB|r Cache: Invalid record received for upsert")
    end
    return false
  end
  local cur = UltraHardcoreLeaderboardDB.cache[rec.name]
  if not cur or rec.ts > (cur.ts or 0) then
    UltraHardcoreLeaderboardDB.cache[rec.name] = rec
    UpdateIndex(rec.name, rec.ts)
    return true
  end
  return false
end

function Cache:PurgeOld()
  local cutoff = Now() - self.PURGE_AGE
  local db = UltraHardcoreLeaderboardDB.cache
  local index = UltraHardcoreLeaderboardDB.tsIndex
  local removed = 0
  -- Iterate backwards to safely remove stale entries
    for i = #index, 1, -1 do
        local entry = index[i]
        if not entry.ts or entry.ts < cutoff then
            db[entry.name] = nil
            table.remove(index, i)
            removed = removed + 1
        end
    end
    if removed > 0 and addon:GetModule("Network", true):IsDebug() then
        print("|cff66ccffUHLB|r Cache: Purged", removed, "stale records")
    end
end

function Cache:GetActiveRecords(maxRecords)
    local index = UltraHardcoreLeaderboardDB.tsIndex
    local db = UltraHardcoreLeaderboardDB.cache
    local cutoff = Now() - self.ACTIVE_THRESHOLD
    local records = {}
    for _, entry in ipairs(index) do
        if entry.ts >= cutoff then
            local rec = db[entry.name]
            if rec then
                records[#records + 1] = rec
            end
        else
            break -- Index is sorted, so stop once we hit stale records
        end
        if maxRecords and #records >= maxRecords then
            break
        end
    end
    return records
end

function Cache:SetupPurgeTimers()
  C_Timer.After(5, function() self:PurgeOld() end)
  if self._purgeTicker then self._purgeTicker:Cancel() end
  self._purgeTicker = C_Timer.NewTicker(3 * 60 * 60, function() self:PurgeOld() end)
end

function Cache:Init()
    UltraHardcoreLeaderboardDB       = UltraHardcoreLeaderboardDB or {}
    UltraHardcoreLeaderboardDB.cache = UltraHardcoreLeaderboardDB.cache or {}
    UltraHardcoreLeaderboardDB.tsIndex = UltraHardcoreLeaderboardDB.tsIndex or {}
    self:SetupPurgeTimers()
end
