local ADDON_NAME      = ...
local addon           = LibStub("AceAddon-3.0"):GetAddon("UltraHardcoreLeaderboard")
local Network         = addon:NewModule("Network", "AceComm-3.0") -- uses AceComm API if you want
local AceSerializer   = LibStub("AceSerializer-3.0")
local LibDeflate      = LibStub("LibDeflate", true)
local PREFIX          = "UHLB"
local BASE_ADDON_NAME = "UltraHardcore"
local DEBUG           = false

local seen = addon.seen or {}
addon.seen = seen

local SNAP_REQ_PEERS     = 3     -- whisper up to N guildmates
local SNAP_MAX_ROWS      = 500   -- cap snapshot size
local SNAP_ROWS_PER_PART = 100   -- rows per SNAP message (AceComm still chunks long strings)

Network._snapGotData = false

local function D(...) if DEBUG then print("|cff66ccffUHLB|r", ...) end end

function Network:IsDebug() return DEBUG end
function Network:SetDebug(v) DEBUG = not not v end

-- Convenience: get Cache module
local function Cache()
  return addon:GetModule("Cache", true)
end

-- Timestamp helper
local function Now()
  local t = GetServerTime and GetServerTime()
  return t
end

-- Build the local player record
local function BuildRecordFromPlayer()
  local name = UnitName("player")
  local presetOnly = select(1, GetPresetAndTooltip(name))
  local stats = CharacterStats and CharacterStats:GetCurrentCharacterStats() or {}
  local rec = {
    name                 = name,
    level                = UnitLevel("player") or 0,
    class                = select(1, UnitClass("player")) or "Unknown",
    lowestHealth         = tonumber(string.format("%.2f", stats.lowestHealth or 100.00)),
    elitesSlain          = stats.elitesSlain or 0,
    enemiesSlain         = stats.enemiesSlain or 0,
    xpGainedWithoutAddon = stats.xpGainedWithoutAddon or 0,
    preset               = presetOnly or "",
    version              = GetAddOnMetadata(BASE_ADDON_NAME, "Version") or "0.0.0",
    LVersion             = GetAddOnMetadata(ADDON_NAME , "Version") or "0.0.0",
    customSettings       = (UHCLB_GetLocalSettingsIdList and UHCLB_GetLocalSettingsIdList()) or nil,
    ts                   = Now(),
    guild                = (GetGuildInfo("player") or ""),
    realm                = (GetRealmName() or ""),
    faction              = (UnitFactionGroup("player") or ""),
  }
  return rec
end

-- Encoding helpers (AceSerializer + optional LibDeflate)
if not AceSerializer then
    print("|cff66ccffUHLB|r Error: AceSerializer-3.0 is missing. Please install Ace3.")
end
if not LibDeflate then
    print("|cff66ccffUHLB|r Warning: LibDeflate is missing. Using uncompressed payloads.")
end

-- Debug helper to log table contents
local function debugTable(tbl)
    if not tbl then return "nil" end
    local parts = {}
    for k, v in pairs(tbl) do
        parts[#parts + 1] = string.format("%s=%s", tostring(k), tostring(v))
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function encode(tbl)
  if not AceSerializer then
    print("|cff66ccffUHLB|r Network: Cannot encode, AceSerializer-3.0 not loaded")
    return nil
  end
  if type(tbl) ~= "table" then
    print("|cff66ccffUHLB|r Network: Invalid table for encoding")
    return nil
  end

  local serialized = AceSerializer:Serialize(tbl)  -- ONLY one return value

  if LibDeflate then
    local comp = LibDeflate:CompressDeflate(serialized)
    if not comp then
      print("|cff66ccffUHLB|r Network: Compression failed for type", tbl.type or "unknown")
      return nil
    end
    return LibDeflate:EncodeForPrint(comp)
  else
    return serialized
  end
end

local function decode(payload)
  -- Try LibDeflate path first (if library present AND payload is compressed)
  if LibDeflate then
    local comp = LibDeflate:DecodeForPrint(payload)
    if comp then
      local decompressed = LibDeflate:DecompressDeflate(comp)
      if decompressed then
        local ok, tbl = AceSerializer:Deserialize(decompressed)
        if ok then return tbl end
      end
    end
  end
  -- Fallback: plain AceSerializer (covers senders that didn’t compress)
  local ok, tbl = AceSerializer:Deserialize(payload)
  if ok then return tbl end
  return nil
end

-- Simple TTL-based dedup for records (name@ts)
local recent = {}        -- key -> expireAt
local RECENT_TTL = 300   -- 5 minutes

local function recKey(r)
  return (r.name or "?") .. "@" .. tostring(r.ts or 0)
end

local function isDupe(r)
  local t = Now()
  local k = recKey(r)
  local exp = recent[k]
  if exp and exp > t then return true end
  recent[k] = t + RECENT_TTL
  -- Cleanup to prevent unbounded growth
  if math.random(40) == 1 then
    local t = Now()
    for key, ttl in pairs(recent) do
    if ttl <= t then recent[key] = nil end
  end
end
  return false
end

local function PlayerNameRealm()
  local n, r = UnitName("player")
  r = r or GetRealmName()
  return (r and r ~= "" and (n.."-"..r)) or n
end

local function GuildOnline()
  local t = {}
  local num = select(2, GetNumGuildMembers()) or 0
  D("Guild: Online guild members: " .. num)
  if num == 0 then return t end
  for i = 1, num do
    local fullName, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
    if online and fullName and fullName ~= PlayerNameRealm() and fullName:match("%w+-%w+") then
      t[#t+1] = fullName
    end
  end
  return t
end

local function PickN(t, n)
  local c = { unpack(t) }
  for i = #c, 2, -1 do
    local j = math.random(i)
    c[i], c[j] = c[j], c[i]
  end
  local out = {}
  for i = 1, math.min(n, #c) do out[i] = c[i] end
  return out
end

-- Build a list of records since a timestamp, newest first, capped
local function CollectRowsSince(sinceTs)
    local cache = addon:GetModule("Cache", true)
    local rows = cache and cache:GetActiveRecords(SNAP_MAX_ROWS) or {}
    -- Don't filter by guild here - we want all data for global leaderboard
    -- Filter by sinceTs if provided
    if sinceTs then
        local filtered = {}
        for _, rec in ipairs(rows) do
            if not sinceTs or (rec.ts and rec.ts >= sinceTs) then
                filtered[#filtered + 1] = rec
            end
        end
        rows = filtered
    end
    return rows
end

local function SendSnapshot(target, since)
  if not target or target == "" then return end
  local rows = CollectRowsSince(since) or {}
  if #rows == 0 then return end
  local payload = encode({ type = "SNAP", rows = rows })
  if payload then
    D("SEND SNAP to", target, "#rows", #rows, "bytes", #payload)
    addon:SendCommMessage(PREFIX, payload, "WHISPER", target)
  end
end

function Network:SendSnapReq()
  local cand = GuildOnline() or {}
  if #cand == 0 then
    D("SendSnapReq: No online guild members to query")
    return
  end

  local peers = PickN(cand, #cand)

  local cache = addon:GetModule("Cache", true)
  if not cache then
    D("SendSnapReq: Cache module not loaded")
    return
  end

  local since = Now() - (cache.PURGE_AGE or 7 * 24 * 60 * 60)
  if type(since) ~= "number" or since <= 0 or since ~= since then
    D("SendSnapReq: Invalid since timestamp:", tostring(since))
    return
  end

  local payload = encode({ type = "SNAP_REQ", since = since })
  if not payload then
    D("SendSnapReq: Failed to encode SNAP_REQ payload")
    return
  end

  self._snapGotData = false
  for idx, who in ipairs(peers) do
    C_Timer.After(0.4 * idx, function()
      --if self._snapGotData then return end  -- stop scheduling further whispers
      addon:SendCommMessage(PREFIX, payload, "WHISPER", who)
      D("Sent SNAP_REQ to", who, "since", since)
    end)
  end
end

Network.MIN_SEND_INTERVAL = 8   -- seconds; prevents back-to-back duplicates
Network._lastSend = 0
Network._pending = nil

-- Optional: use this if you want to trigger a send "soon", coalescing bursts
function Network:ScheduleDelta(delay)
  if self._pending then return end
  self._pending = C_Timer.NewTimer(delay or 2, function()
    self._pending = nil
    self:SendDelta()
  end)
end

function Network:MarkDeadAndSend()
  local rec = BuildRecordFromPlayer()
  rec.dead = true
  rec.lowestHealth = 0  -- still set, but UI won't rely on this anymore

  local cache = addon:GetModule("Cache", true)
  if cache then cache:Upsert(rec) end

  seen[rec.name] = {
    level = rec.level or 0,
    class = rec.class or "UNKNOWN",
    version = rec.version or "0.0.0",
    LVersion = rec.LVersion or "0.0.0",
    lowestHealth = rec.lowestHealth or 0,
    elitesSlain = rec.elitesSlain or 0,
    enemiesSlain = rec.enemiesSlain or 0,
    xpGainedWithoutAddon = rec.xpGainedWithoutAddon or 0,
    preset = rec.preset or "Custom",
    last = rec.ts or ((GetServerTime and GetServerTime()) or time()),
    customSettings = rec.customSettings,
    guild = rec.guild or "",
    realm = rec.realm or "",
    faction = rec.faction or "",
    dead = true,
  }

  if addon.RefreshUIIfVisible then addon:RefreshUIIfVisible() end

  local payload = encode({ type = "DELTA", rec = rec })
  if payload then
    addon:SendCommMessage(PREFIX, payload, "GUILD")
    addon:SendCommMessage(PREFIX, payload, "YELL")
    D("Sent DEAD DELTA for", rec.name, "ts", rec.ts)
  end
end

function Network:SendOfflineDelta()
  local rec = BuildRecordFromPlayer()
  rec.offline = true

  local cache = addon:GetModule("Cache", true)
  if cache then cache:Upsert(rec) end

  seen[rec.name] = {
    level = rec.level or 0,
    class = rec.class or "UNKNOWN",
    version = rec.version or "0.0.0",
    LVersion = rec.LVersion or "0.0.0",
    lowestHealth = rec.lowestHealth or 100,
    elitesSlain = rec.elitesSlain or 0,
    enemiesSlain = rec.enemiesSlain or 0,
    xpGainedWithoutAddon = rec.xpGainedWithoutAddon or 0,
    preset = rec.preset or "Custom",
    last = 0,
    customSettings = rec.customSettings,
    guild = rec.guild or "",
    realm = rec.realm or "",
    faction = rec.faction or "",
  }

  if addon.RefreshUIIfVisible then addon:RefreshUIIfVisible() end

  local payload = encode({ type = "DELTA", rec = rec })
  if payload then
    addon:SendCommMessage(PREFIX, payload, "GUILD")
    addon:SendCommMessage(PREFIX, payload, "YELL")
    D("Sent OFFLINE DELTA for", rec.name, "ts", rec.ts)
  end
end

function Network:SendDelta()
  local now = (GetServerTime and GetServerTime()) or time()
  if now - (self._lastSend or 0) < self.MIN_SEND_INTERVAL then
    D("SendDelta skipped (cooldown)")
    return
  end
  self._lastSend = now

  local rec = BuildRecordFromPlayer()

  local cache = addon:GetModule("Cache", true)
  if cache then cache:Upsert(rec) end
  seen[rec.name] = {
    level = rec.level or 0,
    class = rec.class or "UNKNOWN",
    version = rec.version or "0.0.0",
    LVersion = rec.LVersion or "0.0.0",
    lowestHealth = rec.lowestHealth or 100,
    elitesSlain = rec.elitesSlain or 0,
    enemiesSlain = rec.enemiesSlain or 0,
    xpGainedWithoutAddon = rec.xpGainedWithoutAddon or 0,
    preset = rec.preset or "Custom",
    last = rec.ts or now,
    customSettings = rec.customSettings,
    guild = rec.guild or "",
    realm = rec.realm or "",
    faction = rec.faction or "",
  }
  
  if addon.RefreshUIIfVisible then addon:RefreshUIIfVisible() end

  local payload = encode({ type = "DELTA", rec = rec })
  if payload then
    addon:SendCommMessage(PREFIX, payload, "GUILD")
    addon:SendCommMessage(PREFIX, payload, "YELL")
    D("Sent DELTA for", rec.name, "ts", rec.ts)
  end
end

local SNAP_REPLY_COOLDOWN = 60    -- seconds per requesting sender
Network._snapCooldown = Network._snapCooldown or {}

local function canReplySnapshot(sender)
  local t = (GetServerTime and GetServerTime())
  local last = Network._snapCooldown[sender] or 0
  if t - last < SNAP_REPLY_COOLDOWN then return false end
  Network._snapCooldown[sender] = t
  return true
end

-- Handle incoming messages (from main's RegisterComm)
local snapBuffers = {}
function Network:OnCommReceived(prefix, msg, dist, sender)
    if prefix ~= PREFIX or not msg then return end
    local tbl = decode(msg)
    if not tbl or type(tbl) ~= "table" or not tbl.type then return end
    D("RECV", tbl.type, "from", sender, "dist", dist, "len", #msg)

    if tbl.type == "DELTA" and tbl.rec then
        if isDupe(tbl.rec) then
            D("DELTA duped", tbl.rec.name, tbl.rec.ts)
            return
        end
        local changed = (addon:GetModule("Cache", true) and addon:GetModule("Cache", true):Upsert(tbl.rec)) or false
        local markOffline = (tbl.rec.offline == true)
        seen[tbl.rec.name] = {
            level = tbl.rec.level or 0,
            class = tbl.rec.class or "UNKNOWN",
            version = tbl.rec.version or "0.0.0",
            LVersion = tbl.rec.LVersion or "0.0.0",
            lowestHealth = tonumber(string.format("%.2f", tbl.rec.lowestHealth or 100.00)),
            elitesSlain = tbl.rec.elitesSlain or 0,
            enemiesSlain = tbl.rec.enemiesSlain or 0,
            xpGainedWithoutAddon = tbl.rec.xpGainedWithoutAddon or 0,
            preset = tbl.rec.preset or "Custom",
            last = markOffline and 0 or (tbl.rec.ts or Now()),
            customSettings = tbl.rec.customSettings,
            guild = tbl.rec.guild or "",
            realm = tbl.rec.realm or "",
            faction = tbl.rec.faction or "",
            dead = tbl.rec.dead or false,
        }
        if changed and addon.RefreshUIIfVisible then
          addon:RefreshUIIfVisible()
        end

    elseif tbl.type == "SNAP_REQ" then
        if canReplySnapshot(sender) then
            D("Reply SNAP to", sender, "since", tbl.since)
            SendSnapshot(sender, tbl.since or 0)
        else
            D("SNAP_REQ throttled for", sender)
        end

    elseif tbl.type == "SNAP" and type(tbl.rows) == "table" then
      local cache = addon:GetModule("Cache", true)
      local changed, applied = false, 0
      for _, rec in ipairs(tbl.rows) do
        if not isDupe(rec) and cache and cache:Upsert(rec) then
          applied = applied + 1
          changed = true
          seen[rec.name] = {
            level = rec.level or 0,
            class = rec.class or "UNKNOWN",
            version = rec.version or "0.0.0",
            LVersion = rec.LVersion or "0.0.0",
            lowestHealth = tonumber(string.format("%.2f", rec.lowestHealth or 100.00)),
            elitesSlain = rec.elitesSlain or 0,
            enemiesSlain = rec.enemiesSlain or 0,
            xpGainedWithoutAddon = rec.xpGainedWithoutAddon or 0,
            preset = rec.preset or "Custom",
            last = rec.ts or Now(),
            customSettings = rec.customSettings,
            guild = rec.guild or "", realm = rec.realm or "", faction = rec.faction or "",
            dead = rec.dead or false,
          }
        end
      end
      if applied > 0 then self._snapGotData = true end
      D(("APPLIED SNAP rows %d changed %s"):format(applied, tostring(changed)))
      if changed and addon.RefreshUIIfVisible then addon:RefreshUIIfVisible() end
    end
end


