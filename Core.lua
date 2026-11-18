-- Totem Coverage v0.1.0-test (WoW Forever, interface 16001)
-- Original implementation. No code from other addons is included.
local addonName = ...
local TC = CreateFrame("Frame")
local db
local plates = {}
local observedUnits = {} -- unit token -> last known plate and GUID
local lastKnownTotems = {} -- last confirmed totems, retained while data is secret
local lastStates = {}
local lastHeartbeat = 0
local lastScan = 0
local missingNotice = false
local VERSION = "0.1.1-beta.5"
local SCAN_INTERVAL = 1.5
local DIAG_LIMIT = 30000 -- safety ceiling; SavedVariables cannot append directly to disk
local colors = { yes = "|cff67e58a", no = "|cffff7474", unknown = "|cffb5b8be", na = "|cffb5b8be" }
local AURA_OPTIONS = {
  ["Strength of Earth"] = {"Strength of Earth"},
  ["Grace of Air"] = {"Grace of Air"},
  ["Stoneskin"] = {"Stoneskin"},
  ["Mana Spring"] = {"Mana Spring"},
  ["Windfury"] = {"Windfury Totem", "Windfury"},
  ["Tranquil Air"] = {"Tranquil Air"},
  ["Fire Resistance"] = {"Fire Resistance"},
  ["Frost Resistance"] = {"Frost Resistance"},
  ["Nature Resistance"] = {"Nature Resistance"},
  ["Flametongue"] = {"Flametongue Totem", "Flametongue"},
  ["Mana Tide"] = {"Mana Tide"},
}
local function safe(v)
  if v == nil then return "nil" end
  if issecretvalue and issecretvalue(v) then return "<secret>" end
  local ok, value = pcall(tostring, v)
  return ok and value or "<unreadable>"
end
local function allowed(v)
  return v ~= nil and not (issecretvalue and issecretvalue(v))
end
local function stamp()
  local clock = (GetTime and GetTime()) or 0
  local epoch = (GetServerTime and GetServerTime()) or 0
  return epoch, math.floor(clock * 1000 + .5)
end
local function say(msg)
  print("|cff63c8f7Totem Coverage|r: " .. msg)
end
local function log(kind, detail)
  if not db or not db.diag then return end
  local d = db.records
  if #d >= DIAG_LIMIT then
    if not db.limitNotice then
      db.limitNotice = true
      say("Diagnostic limit reached. /reload to save; /tc diag clear to reset.")
    end
    return
  end
  local epoch, ms = stamp()
  d[#d + 1] = { epoch, ms, kind, detail or "" }
end
local function observation(key, value)
  if lastStates[key] ~= value then
    lastStates[key] = value
    log("CHANGE", key .. "=" .. value)
  end
end
local function apiCall(fn, ...)
  if type(fn) ~= "function" then return false, "unavailable" end
  local ok, a, b, c, d, e = pcall(fn, ...)
  if not ok then return false, safe(a) end
  return true, a, b, c, d, e
end
local function currentTotems()
  if type(GetTotemInfo) ~= "function" then
    observation("GetTotemInfo", "unavailable")
    return lastKnownTotems
  end
  local out, restricted = {}, false
  for slot = 1, 4 do
    local ok, active, name, start, duration, icon = apiCall(GetTotemInfo, slot)
    if ok and (not allowed(active) or not allowed(name)) then
      restricted = true
      observation("totem:" .. slot, "secret")
    elseif ok and allowed(active) and active and allowed(name) and type(name) == "string" and name ~= "" then
      out[#out + 1] = {slot=slot,name=name,start=allowed(start) and start or nil,
        duration=allowed(duration) and duration or nil,icon=allowed(icon) and icon or nil}
      observation("totem:" .. slot, name)
    elseif ok then
      observation("totem:" .. slot, "inactive")
    else
      observation("totem:" .. slot, "error:" .. safe(active))
    end
  end
  if restricted then
    -- Secret combat data must not erase a confirmed noncombat totem.
    -- Expiry is enforced below when timing information is available.
    local now = GetTime and GetTime() or 0
    local retained = {}
    for _, t in ipairs(lastKnownTotems) do
      if type(t.start) ~= "number" or type(t.duration) ~= "number" or
        t.duration <= 0 or now < t.start + t.duration + 1 then
        retained[#retained+1] = t
      end
    end
    lastKnownTotems = retained
    return retained
  end
  lastKnownTotems = out
  return out
end
local function baseName(name)
  if not allowed(name) or type(name) ~= "string" then return nil end
  return (name:gsub("%s+[Tt]otem$", ""))
end
local function candidates(totemName)
  local base = baseName(totemName)
  return base and AURA_OPTIONS[base] or nil
end
local function roster()
  local units = { "player" }
  if IsInRaid and IsInRaid() then
    -- v0.1 focuses on the shaman's immediate party; raid subgroup selection needs verification.
    return units
  end
  for i = 1, 4 do
    local unit = "party" .. i
    local ok, exists = apiCall(UnitExists, unit)
    if ok and allowed(exists) and exists then units[#units + 1] = unit end
  end
  return units
end
local function auraStatus(unit, want)
  if not want then return "na", "no-verified-buff-map" end
  if not (C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function") then
    return "unknown", "aura-api-unavailable"
  end
  local count = 0
  for i = 1, 80 do
    local ok, aura = apiCall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
    if not ok then return "unknown", "aura-call-failed:" .. safe(aura) end
    if not allowed(aura) then return "unknown", "aura-secret" end
    if aura == nil then return "no", "not-found" end
    if type(aura) ~= "table" then return "unknown", "aura-unexpected-type" end
    local name = aura.name
    if not allowed(name) then return "unknown", "aura-name-secret" end
    for j = 1, #want do
      if name == want[j] then return "yes", "matched:" .. safe(name) end
    end
    count = count + 1
  end
  return "unknown", "aura-scan-limit:" .. count
end
local function displayName(unit)
  local ok, name = apiCall(UnitName, unit)
  if not ok or not allowed(name) or type(name) ~= "string" or name == "" then return unit end
  return name
end
local function coverageLines(totem)
  local names = candidates(totem.name)
  local lines = {}
  local units = roster()
  for _, unit in ipairs(units) do
    local name = displayName(unit)
    local status, reason = auraStatus(unit, names)
    local marker = status == "yes" and "" or (status == "no" and " x" or " ?")
    if status ~= "na" and (db.mode == "all" or (db.mode == "missing" and status == "no") or (db.mode == "affected" and status == "yes")) then
      lines[#lines + 1] = colors[status] .. name .. marker .. "|r"
    end
    observation("aura:" .. totem.slot .. ":" .. unit,
      status .. ":" .. reason .. ":" .. safe(totem.name))
  end
  return lines, names ~= nil
end
local function plateFor(unit)
  if C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function" then
    local ok, plate = apiCall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and allowed(plate) then return plate end
    observation("nameplate-api", ok and "secret" or safe(plate))
  end
  return nil
end
local function ensureOverlay(plate)
  if plates[plate] then return plates[plate] end
  local ok, overlay = pcall(CreateFrame, "Frame", nil, plate)
  if not ok or not overlay then
    observation("create-overlay", "failed:" .. safe(overlay))
    return nil
  end
  -- Keeping all frame changes protected prevents one secure-combat failure
  -- from breaking the rest of the addon.
  local setup, err = pcall(function()
    overlay:SetSize(260, 100)
    overlay:SetPoint("BOTTOM", plate, "TOP", 0, 8)
    overlay:SetFrameStrata("HIGH")
    overlay:SetFrameLevel(plate:GetFrameLevel() + 2)
    local lines = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lines:SetPoint("BOTTOM", overlay, "BOTTOM", 0, 0)
    lines:SetWidth(260)
    lines:SetJustifyH("CENTER")
    lines:SetJustifyV("BOTTOM")
    lines:SetSpacing(3)
    local font = (GameFontNormal and select(1, GameFontNormal:GetFont())) or STANDARD_TEXT_FONT
    if font then lines:SetFont(font, 14, "OUTLINE") end
    lines:SetShadowOffset(1, -1)
    overlay.lines = lines
    overlay:Hide()
  end)
  if not setup then
    observation("setup-overlay", "failed:" .. safe(err))
    return nil
  end
  plates[plate] = overlay
  log("PLATE", "overlay-created")
  return overlay
end
local function unitName(unit)
  local ok, name = apiCall(UnitName, unit)
  if ok and allowed(name) and type(name) == "string" then return name end
  return nil
end
local function resolveUnit(unit)
  if not allowed(unit) or type(unit) ~= "string" then return nil end
  local plate = plateFor(unit)
  local guidOk, guid = apiCall(UnitGUID, unit)
  if not guidOk or not allowed(guid) then guid = nil end
  if plate then
    observedUnits[unit] = {plate=plate, guid=guid, name=unitName(unit)}
    observation("unit-plate:" .. unit, "resolved:" .. safe(guid) .. ":" .. safe(observedUnits[unit].name))
  else
    observation("unit-plate:" .. unit, "frame-unavailable")
  end
  return observedUnits[unit]
end
local function removeUnit(unit)
  local record = observedUnits[unit]
  if record and record.plate and plates[record.plate] then
    pcall(plates[record.plate].Hide, plates[record.plate])
  end
  observedUnits[unit] = nil
  observation("unit-plate:" .. safe(unit), "removed")
end
local function updatePlates()
  local totems = currentTotems()
  local lookup = {}
  for _, t in ipairs(totems) do lookup[t.name] = t end
  local matched = 0
  -- Never infer unit tokens from plate.namePlateUnitToken: unavailable
  -- on Forever. Discover them through NAME_PLATE_UNIT_ADDED instead.
  for unit, info in pairs(observedUnits) do
    local plate = info.plate
    local name = unitName(unit)
    if name and name ~= info.name then
      -- nameplate unit IDs are recycled; refresh GUID and matching.
      info = resolveUnit(unit) or info
      plate = info.plate
    end
    local totem = name and lookup[name]
    local overlay = plate and plates[plate]
    if totem and name ~= "Searing Totem" and plate then
      matched = matched + 1
      overlay = overlay or ensureOverlay(plate)
      if overlay then
        local lines, mapped = coverageLines(totem)
        local layout = db.nameLayout == "inline" and "inline" or "stacked"
        local separator = layout == "inline" and "  |  " or "\n"
        local showNames = mapped and #lines > 0
        local shown, err = pcall(function()
          if showNames then
            overlay.lines:SetText(table.concat(lines, separator))
            overlay:Show()
          else
            -- No fabricated coverage, duplicated totem title, or debug fallback.
            overlay.lines:SetText("")
            overlay:Hide()
          end
        end)
        observation("overlay:" .. unit, shown and (showNames and ("shown:" .. name .. ":" .. layout .. ":" .. #lines) or ("hidden:no-verified-display:" .. name)) or ("failed:" .. safe(err)))
      end
    elseif overlay then
      pcall(overlay.Hide, overlay)
    end
  end
  observation("plate-matches", tostring(matched))
end
function TotemCoverage_RefreshDisplay()
  if db then updatePlates() end
end
local function heartbeat()
  if not db.diag then return end
  local now = (GetTime and GetTime()) or 0
  if now - lastHeartbeat < 30 then return end
  lastHeartbeat = now
  local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")
  local logging = (type(LoggingCombat) == "function") and LoggingCombat() or "unavailable"
  log("HEARTBEAT", "combat=" .. safe(inCombat) .. " native=" .. safe(logging) ..
    " records=" .. #db.records .. " plates=" .. safe(C_NamePlate and C_NamePlate.GetNamePlates ~= nil))
end
local function nativeLogging(enable)
  if type(LoggingCombat) ~= "function" then
    say("Native LoggingCombat API unavailable. Use /combatlog manually.")
    log("NATIVE", "api-unavailable")
    return
  end
  local ok, active = apiCall(LoggingCombat)
  if not ok or not allowed(active) then
    log("NATIVE", "read-failed:" .. safe(active))
    return
  end
  if enable and not active then
    local started, result = apiCall(LoggingCombat, true)
    if started then db.nativeOwned = true end
    log("NATIVE", "start=" .. safe(started) .. " result=" .. safe(result))
  elseif not enable and db.nativeOwned then
    local stopped, result = apiCall(LoggingCombat, false)
    log("NATIVE", "stop=" .. safe(stopped) .. " result=" .. safe(result))
    if db.nameLayout ~= "inline" then db.nameLayout = "stacked" end
    db.nativeOwned = false
  else
    log("NATIVE", "already-active-or-not-owned:" .. safe(active))
  end
end
local function status()
  say("v" .. VERSION .. " | diagnostics " .. (db.diag and "ON" or "OFF") ..
    " | records " .. #db.records .. " | mode " .. db.mode)
  say("Friendly totem plates require Friendly Player Nameplates enabled in WoW's options.")
end
local function command(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "diag on" then
    if not db.diag then
      db.diag = true
      db.session = (db.session or 0) + 1
      lastStates = {}
      log("SESSION", "start:" .. db.session .. " version=" .. VERSION)
      log("API", "GetTotemInfo=" .. safe(type(GetTotemInfo)) ..
        " GetNamePlates=" .. safe(C_NamePlate and type(C_NamePlate.GetNamePlates)) ..
        " AuraByIndex=" .. safe(C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex)))
      nativeLogging(true)
    end
    say("Diagnostics ON. Native combat logging requested. /reload or logout to save addon records.")
  elseif msg == "diag off" then
    if db.diag then
      nativeLogging(false)
      log("SESSION", "stop:" .. safe(db.session))
      db.diag = false
    end
    say("Diagnostics OFF. /reload or logout to write SavedVariables.")
  elseif msg == "diag clear" then
    if db.diag then say("Turn diagnostics off before clearing."); return end
    db.records = {}
    db.limitNotice = false
    lastStates = {}
    say("Saved diagnostic records cleared (save with /reload).")
  elseif msg == "diag" or msg == "status" or msg == "" then
    status()
  elseif msg == "mode all" or msg == "mode missing" or msg == "mode affected" then
    db.mode = msg:match("mode (%a+)")
    say("Name display mode: " .. db.mode)
    updatePlates()
  elseif msg == "layout stacked" or msg == "layout inline" then
    db.nameLayout = msg:match("layout (%a+)")
    say("Party name layout: " .. db.nameLayout)
    updatePlates()
  elseif msg == "settings" then
    if type(TotemCoverage_ShowSettings) == "function" then TotemCoverage_ShowSettings() end
  elseif msg == "scan" then
    updatePlates()
    if type(TotemCoverage_ProbeNow) == "function" then TotemCoverage_ProbeNow() end
    say("Forced totem/nameplate scan; check saved diagnostics for details.")
  else
    say("Commands: /tc diag on | off | clear, /tc mode all | missing | affected, /tc layout stacked | inline, /tc settings, /tc scan")
  end
end
SLASH_TOTEMCOVERAGE1 = "/tc"
SLASH_TOTEMCOVERAGE2 = "/totemcoverage"
SlashCmdList.TOTEMCOVERAGE = command
local function safeRegister(event)
  local ok, err = pcall(TC.RegisterEvent, TC, event)
  if not ok then say("Event " .. event .. " unavailable: " .. tostring(err)) end
end
safeRegister("ADDON_LOADED")
safeRegister("PLAYER_ENTERING_WORLD")
safeRegister("PLAYER_TOTEM_UPDATE")
safeRegister("NAME_PLATE_UNIT_ADDED")
safeRegister("NAME_PLATE_UNIT_REMOVED")
safeRegister("GROUP_ROSTER_UPDATE")
safeRegister("UNIT_AURA")
safeRegister("PLAYER_REGEN_DISABLED")
safeRegister("PLAYER_REGEN_ENABLED")
TC:SetScript("OnEvent", function(_, event, arg)
  if event == "ADDON_LOADED" then
    if arg ~= addonName then return end
    TotemCoverageDB = TotemCoverageDB or {}
    db = TotemCoverageDB
    if type(db.records) ~= "table" then db.records = {} end
    if db.mode ~= "all" and db.mode ~= "missing" and db.mode ~= "affected" then db.mode = "all" end
    db.diag = false -- never silently resume massive logging after a reload
    db.nativeOwned = false
    -- Recover already visible plates if the addon was enabled after login.
    -- If frames lack unit tokens, event tracking populates them as they appear.
    say("Loaded. /tc diag on to capture paired API and combat logs; /tc status for help.")
    return
  end
  if not db then return end
  if event == "UNIT_AURA" then
    if not allowed(arg) or type(arg) ~= "string" then return end
    if arg ~= "player" and not arg:match("^party[1-4]$") then return end
  end
  if event == "NAME_PLATE_UNIT_ADDED" then
    resolveUnit(arg)
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    removeUnit(arg)
  elseif event == "PLAYER_ENTERING_WORLD" then
    for unit in pairs(observedUnits) do removeUnit(unit) end
  end
  if db.diag and event ~= "UNIT_AURA" then
    log("EVENT", event .. " unit=" .. safe(arg))
  end
  updatePlates()
end)
TC:SetScript("OnUpdate", function(_, elapsed)
  if not db then return end
  lastScan = lastScan + elapsed
  if lastScan >= SCAN_INTERVAL then
    lastScan = 0
    updatePlates()
    heartbeat()
  end
end)
