local addon = LibStub("AceAddon-3.0"):GetAddon("UltraHardcoreLeaderboard")
local Data  = addon:NewModule("Data")

-- seconds → "now/5m/2h/3d"
local function FormatAgo(sec)
  if not sec or sec < 0 then return "?" end
  if sec < 5 then return "now" end
  if sec < 60 then return ("%ds"):format(math.floor(sec)) end
  local m = math.floor(sec/60)
  if m < 60 then return ("%dm"):format(m) end
  local h = math.floor(sec/3600)
  if h < 48 then return ("%dh"):format(h) end
  local d = math.floor(sec/86400)
  return ("%dd"):format(d)
end

-- Timestamp helper
local function Now()
  local t = GetServerTime and GetServerTime()
  return t
end

-- Treat entries in `seen` as "online" if updated within ~10 minutes.
-- Keep using your existing 'seen[name].last = GetTime()' mechanic.
local SEEN_TTL = 10 * 60  -- 10 minutes

local function IsOnline(name, seen)
    local s = seen and seen[name]
    if not s or not s.last then return false end
    return (Now() - s.last) < SEEN_TTL
end

local function safeN(v, d) v = tonumber(v); return v ~= nil and v or d end
local function r2(v) return tonumber(string.format("%.2f", v)) end

-- Build the unified dataset for the UI:
--  - start from SavedVariables cache (7d retention)
--  - add any 'seen' entries that aren't in cache yet (e.g., just received live, no disk save yet)
function Data:BuildRowsForUI(seen)
  local cache = (UltraHardcoreLeaderboardDB and UltraHardcoreLeaderboardDB.cache) or {}
  local index = (UltraHardcoreLeaderboardDB and UltraHardcoreLeaderboardDB.tsIndex) or {}
  local rows, have = {}, {}

  local curGuild = (GetGuildInfo("player") or "")
  local curRealm = (GetRealmName() or "")
  local function inScope(rec)
    return (rec.guild or "") == curGuild
  end

  -- 1) rows from cache (source of truth for last-known)
  for _, entry in ipairs(index) do
        local rec = cache[entry.name]
        if rec and inScope(rec) then
            local lastSeenSec = math.max(0, Now() - (rec.ts or 0))
            rows[#rows + 1] = {
                name                 = entry.name,
                level                = safeN(rec.level, 0),
                class                = rec.class or "UNKNOWN",
                lowestHealth         = r2(safeN(rec.lowestHealth, 100.00)),
                elitesSlain          = safeN(rec.elitesSlain, 0),
                enemiesSlain         = safeN(rec.enemiesSlain, 0),
                xpGainedWithoutAddon = safeN(rec.xpGainedWithoutAddon, 0),
                preset               = rec.preset or "",
                version              = rec.version or "0.0.0",
                ts                   = rec.ts or 0,
                lastSeenSec          = lastSeenSec,
                lastSeenText         = FormatAgo(lastSeenSec),
                online               = IsOnline(entry.name, seen),
            }
            have[entry.name] = true
        end
    end

    -- 2) Add seen rows not in cache
    if seen then
        for name, s in pairs(seen) do
            if not have[name] and inScope(s) then
                local online = IsOnline(name, seen)
                local approxTs = Now()
                local lastSeenSec = math.max(0, Now() - (s.last or 0))
                rows[#rows + 1] = {
                    name                 = name,
                    level                = safeN(s.level, 0),
                    class                = s.class or "UNKNOWN",
                    lowestHealth         = r2(safeN(s.lowestHealth, 100.00)),
                    elitesSlain          = safeN(s.elitesSlain, 0),
                    enemiesSlain         = safeN(s.enemiesSlain, 0),
                    xpGainedWithoutAddon = safeN(s.xpGainedWithoutAddon, 0),
                    preset               = s.preset or "",
                    version              = s.version or "0.0.0",
                    ts                   = approxTs,
                    lastSeenSec          = lastSeenSec,
                    lastSeenText         = FormatAgo(lastSeenSec),
                    online               = online,
                }
            end
        end
    end

  table.sort(rows, function(a, b)
    -- 0) Online first (true > false)
    local ao = a.online and 1 or 0
    local bo = b.online and 1 or 0
    if ao ~= bo then return ao > bo end

    -- 1) Level (higher first)
    if a.level ~= b.level then return a.level > b.level end

    -- 2) Name (A → Z, case-insensitive if you prefer)
    local an = (a.name or "")
    local bn = (b.name or "")
    -- an, bn = an:lower(), bn:lower()  -- uncomment for case-insensitive sort
    if an ~= bn then return an < bn end

    -- 3) Last seen (more recent first: smaller seconds-since → higher rank)
    local aLast = a.lastSeenSec or math.huge
    local bLast = b.lastSeenSec or math.huge
    return aLast < bLast
  end)

  return rows
end