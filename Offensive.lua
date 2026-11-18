-- Totem Coverage: experimental offensive totem target labels for WoW Forever.
-- Deliberately does NOT register restricted COMBAT_LOG_EVENT_UNFILTERED.
local frame = CreateFrame("Frame")
local overlays = {}
local last = {}
local elapsed = 0
local OFFENSIVE = { ["Searing Totem"] = true }
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
  title:SetText("|cffffd46bSearing Totem|r")
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
  for _, overlay in pairs(overlays) do overlay:Hide() end
  local db = TotemCoverageDB
  if not db or db.targetEnabled == false then return end
  if not activeSearing() then
    record("searing", "inactive")
    return
  end
  if not (C_NamePlate and type(C_NamePlate.GetNamePlates) == "function") then
    record("plates", "unavailable")
    return
  end
  local ok, plates = call(C_NamePlate.GetNamePlates)
  if not ok or not valid(plates) or type(plates) ~= "table" then
    record("plates", "unreadable")
    return
  end
  local count = 0
  for _, plate in ipairs(plates) do
    local token = plate.namePlateUnitToken
    if valid(token) and type(token) == "string" then
      local nOk, name = call(UnitName, token)
      if nOk and valid(name) and OFFENSIVE[name] then
        count = count + 1
        local overlay = makeOverlay(plate)
        local tOk, targetExists = call(UnitExists, token .. "target")
        local targetName, state = nil, "unknown"
        if tOk and valid(targetExists) and targetExists then
          local got, raw = call(UnitName, token .. "target")
          if got and valid(raw) and type(raw) == "string" and raw ~= "" then
            targetName, state = raw, "direct"
          end
        elseif tOk and valid(targetExists) and not targetExists then
          state = "none-or-unexposed"
        else
          state = "restricted"
        end
        overlay.target:SetText(targetName and ("|cffff7474→ " .. targetName .. "|r") or "|cffb5b8beTarget unknown|r")
        overlay:Show()
        record("plate:" .. token, name .. ":" .. state .. ":" .. (targetName or "?"))
      end
    end
  end
  record("matched-plates", tostring(count))
end
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TOTEM_UPDATE")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function() scan() end)
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
