-- Totem Coverage: experimental offensive totem target labels for WoW Forever.
-- Deliberately does NOT register restricted COMBAT_LOG_EVENT_UNFILTERED.
local frame = CreateFrame("Frame")
local overlays = {}
local knownUnits = {}
local last = {}
local elapsed = 0
local OFFENSIVE = { ["Searing Totem"] = true }
local EFFECTS = TotemCoverageEffects or {}
local function valid(v)
  return v ~= nil and not (issecretvalue and issecretvalue(v))
end
local function call(fn, ...)
  if type(fn) ~= "function" then return false, "unavailable" end
  return pcall(fn, ...)
end
local function record(key, value)
  if last[key] == value then return end
  last[key] = value
  local db = TotemCoverageDB
  if not db or not db.diag or type(db.records) ~= "table" then return end
  if #db.records >= 30000 then return end
  local clock = (GetTime and GetTime()) or 0
  local epoch = (GetServerTime and GetServerTime()) or 0
  db.records[#db.records + 1] = { epoch, math.floor(clock * 1000 + 0.5), "TARGET", key .. "=" .. value }
end
local function makeOverlay(plate)
  if overlays[plate] then return overlays[plate] end
  local f = CreateFrame("Frame", nil, plate)
  f:SetSize(190, 44)
  f:SetPoint("BOTTOM", plate, "TOP", 0, 141)
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  title:SetPoint("TOP", f, "TOP", 0, -2)
  title:SetWidth(190)
  local attack = EFFECTS["Searing Totem"]
  local radius = attack and attack.baseRadius
  title:SetText("|cffffd46bAttack reach: " .. (radius and (radius .. " yd") or "unverified") .. "|r")
  local target = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  target:SetPoint("TOP", title, "BOTTOM", 0, -3)
  target:SetWidth(190)
  f.target = target
  f:Hide()
  overlays[plate] = f
  return f
end
local function activeSearing()
  if type(GetTotemInfo) ~= "function" then return false end
  for slot = 1, 4 do
    local ok, active, name = call(GetTotemInfo, slot)
    if ok and valid(active) and active and valid(name) and name == "Searing Totem" then
      return true
    end
  end
  return false
end
local function scan()
  local db = TotemCoverageDB
  if not db then return end
  if db.targetEnabled == false then
    for _, overlay in pairs(overlays) do pcall(overlay.Hide, overlay) end
    return
  end
  local count = 0
  for unit, info in pairs(knownUnits) do
    local plate = info.plate
    local nOk, name = call(UnitName, unit)
    local isSearing = nOk and valid(name) and OFFENSIVE[name]
    local overlay = plate and overlays[plate]
    if isSearing and plate then
      count = count + 1
      if not overlay then
        local success, created = pcall(makeOverlay, plate)
        if success then overlay = created else record("overlay", "failed:" .. tostring(created)) end
      end
      if overlay then
        local tOk, exists = call(UnitExists, unit .. "target")
        local targetName, state = nil, "unknown"
        if tOk and valid(exists) and exists then
          local got, raw = call(UnitName, unit .. "target")
          if got and valid(raw) and type(raw) == "string" and raw ~= "" then
            targetName, state = raw, "direct"
          end
        elseif tOk and valid(exists) then state = "none-or-unexposed"
        else state = "restricted" end
        local shown, err = pcall(function()
          overlay.target:SetText(targetName and ("|cffff7474→ " .. targetName .. "|r") or
            "|cffb5b8beTarget unknown|r")
          overlay:Show()
        end)
        record("plate:" .. unit, shown and (name .. ":" .. state .. ":" .. (targetName or "?")) or
          ("display-error:" .. tostring(err)))
      end
    elseif overlay then
      pcall(overlay.Hide, overlay)
    end
  end
  record("matched-plates", tostring(count))
end
local function refreshUnit(unit)
  if not valid(unit) or type(unit) ~= "string" then return end
  local api = C_NamePlate and C_NamePlate.GetNamePlateForUnit
  if type(api) ~= "function" then return end
  local ok, plate = call(api, unit)
  if ok and valid(plate) then knownUnits[unit] = {plate=plate} end
end
local function removeUnit(unit)
  local info = knownUnits[unit]
  if info and overlays[info.plate] then pcall(overlays[info.plate].Hide, overlays[info.plate]) end
  knownUnits[unit] = nil
end
pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
pcall(frame.RegisterEvent, frame, "PLAYER_TOTEM_UPDATE")
pcall(frame.RegisterEvent, frame, "NAME_PLATE_UNIT_ADDED")
pcall(frame.RegisterEvent, frame, "NAME_PLATE_UNIT_REMOVED")
pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(_, event, unit)
  if event == "NAME_PLATE_UNIT_ADDED" then refreshUnit(unit)
  elseif event == "NAME_PLATE_UNIT_REMOVED" then removeUnit(unit)
  elseif event == "PLAYER_ENTERING_WORLD" then knownUnits = {} end
  scan()
end)
frame:SetScript("OnUpdate", function(_, dt)
  elapsed = elapsed + dt
  if elapsed >= 0.5 then elapsed = 0; scan() end
end)
SLASH_TCTARGET1 = "/tctarget"
SlashCmdList.TCTARGET = function(msg)
  local db = TotemCoverageDB
  if not db then return end
  local choice = (msg or ""):lower():match("^%s*(.-)%s*$")
  if choice == "on" then db.targetEnabled = true
  elseif choice == "off" then db.targetEnabled = false
  else
    print("Totem Coverage targets: /tctarget on | off (" .. (db.targetEnabled == false and "OFF" or "ON") .. ")")
    return
  end
  scan()
  print("Totem Coverage offensive target display " .. (db.targetEnabled and "ON" or "OFF"))
end
