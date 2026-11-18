-- Totem Coverage diagnostics (WoW Forever). Read-only observation; no restricted combat-log event.
local F = CreateFrame("Frame")
local elapsed, heartbeat = 0, 0
local last, wasEnabled = {}, false
local LIMIT = 30000
local function safe(value)
  if value == nil then return "nil" end
  if issecretvalue and issecretvalue(value) then return "<secret>" end
  local ok, str = pcall(tostring, value)
  if not ok then return "<unreadable>" end
  return str:sub(1, 170)
end
local function readable(value)
  return value ~= nil and not (issecretvalue and issecretvalue(value))
end
local function call(fn, ...)
  if type(fn) ~= "function" then return false, "unavailable" end
  return pcall(fn, ...)
end
local function store(kind, detail)
  local db = TotemCoverageDB
  if not db or not db.diag or type(db.records) ~= "table" then return end
  if #db.records >= LIMIT then return end
  local ok, time = call(GetTime)
  local ms = ok and readable(time) and math.floor(time * 1000 + .5) or 0
  ok, time = call(GetServerTime)
  local epoch = ok and readable(time) and time or 0
  db.records[#db.records + 1] = {epoch, ms, kind, detail}
end
local function changed(key, result)
  if last[key] == result then return end
  last[key] = result
  store("PROBE", key .. " " .. result)
end
local function totemSlot(i)
  local ok, active, name, start, duration, icon = call(GetTotemInfo, i)
  if not ok then
    changed("totem-slot:" .. i, "call-failed:" .. safe(active))
    return
  end
  local activeType = active == nil and "nil" or (readable(active) and safe(active) or "<secret>")
  local str = "active=" .. activeType .. " name=" .. safe(name) ..
    " start=" .. safe(start) .. " duration=" .. safe(duration) .. " icon=" .. safe(icon)
  changed("totem-slot:" .. i, str)
end
local function unitProbe(unit, note)
  if not readable(unit) or type(unit) ~= "string" then
    changed("unit-invalid:" .. safe(note), safe(unit))
    return
  end
  local ok, exists = call(UnitExists, unit)
  local existence = ok and safe(exists) or ("error:" .. safe(exists))
  local nOk, name = call(UnitName, unit)
  local gOk, guid = call(UnitGUID, unit)
  local dOk, dead = call(UnitIsDeadOrGhost, unit)
  local status = "exists=" .. existence ..
    " name=" .. (nOk and safe(name) or "error:" .. safe(name)) ..
    " guid=" .. (gOk and safe(guid) or "error:" .. safe(guid)) ..
    " dead=" .. (dOk and safe(dead) or "error:" .. safe(dead))
  changed("unit:" .. unit, status)
end
local function nameplates()
  local api = C_NamePlate and C_NamePlate.GetNamePlates
  if type(api) ~= "function" then
    changed("nameplates", "API-unavailable")
    return
  end
  local ok, plates = call(api)
  if not ok or not readable(plates) or type(plates) ~= "table" then
    changed("nameplates", ok and "unreadable" or ("call-failed:" .. safe(plates)))
    return
  end
  local count, tokens, missing = 0, {}, 0
  for _, plate in ipairs(plates) do
    count = count + 1
    local pOk, token = pcall(function() return plate.namePlateUnitToken end)
    if pOk and readable(token) and type(token) == "string" then
      tokens[#tokens+1] = token
      unitProbe(token, "enumeration")
    else
      missing = missing + 1
      changed("plate-no-token", "count=" .. missing .. " token=" .. (pOk and safe(token) or "error"))
    end
  end
  table.sort(tokens)
  changed("plate-roster", "count=" .. count .. " missing-token=" .. missing .. " units=" .. table.concat(tokens, ","))
end
local function environment()
  local ok, combat = call(InCombatLockdown)
  changed("combat-lockdown", ok and safe(combat) or "unavailable")
  ok, combat = call(UnitAffectingCombat, "player")
  changed("player-combat", ok and safe(combat) or "unavailable")
  local get = (C_CVar and C_CVar.GetCVar) or GetCVar
  for _, key in ipairs({"nameplateShowFriendlyPlayerTotems","nameplateShowFriends","nameplateShowFriendlyNPCs"}) do
    local available, value = call(get, key)
    changed("cvar:" .. key, available and safe(value) or "unavailable")
  end
  changed("api", "totem=" .. safe(type(GetTotemInfo)) ..
    " plates=" .. safe(type(C_NamePlate and C_NamePlate.GetNamePlates)) ..
    " plateForUnit=" .. safe(type(C_NamePlate and C_NamePlate.GetNamePlateForUnit)) ..
    " GUID=" .. safe(type(UnitGUID)))
end
local function snapshot(reason)
  if not (TotemCoverageDB and TotemCoverageDB.diag) then return end
  if reason then store("SNAPSHOT", reason) end
  environment()
  for i = 1, 4 do totemSlot(i) end
  nameplates()
end
function TotemCoverage_ProbeNow()
  snapshot("manual /tc scan")
end
local function eventHandler(_, event, arg)
  if event == "NAME_PLATE_UNIT_ADDED" then
    store("PLATE-ADDED", "unit=" .. safe(arg))
    unitProbe(arg, event)
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    store("PLATE-REMOVED", "unit=" .. safe(arg))
  elseif event == "PLAYER_TOTEM_UPDATE" then
    store("TOTEM-EVENT", "slot=" .. safe(arg))
  elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    store("COMBAT-EVENT", event)
  end
  snapshot()
end
for _, event in ipairs({"PLAYER_TOTEM_UPDATE", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
  "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD"}) do
  pcall(F.RegisterEvent, F, event)
end
F:SetScript("OnEvent", eventHandler)
F:SetScript("OnUpdate", function(_, delta)
  elapsed = elapsed + delta
  if elapsed < 1.5 then return end
  elapsed = 0
  local enabled = TotemCoverageDB and TotemCoverageDB.diag
  if not enabled then
    if wasEnabled then last = {} end
    wasEnabled = false
    return
  end
  if not wasEnabled then
    last = {}
    heartbeat = 0
    snapshot("diagnostics-start")
  end
  wasEnabled = true
  heartbeat = heartbeat + 1.5
  if heartbeat >= 20 then
    store("SNAPSHOT", "periodic-20s")
    heartbeat = 0
  end
  snapshot()
end)
