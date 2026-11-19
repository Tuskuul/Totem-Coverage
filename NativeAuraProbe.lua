-- Totem Coverage experimental native aura rendering for WoW Forever 1.60.1.
-- Isolated research branch. Opt-in ONLY: /tcnative on, /tcnative off.
-- This does NOT determine distance, caster ownership, or affected counts.
-- It delegates rendering to Blizzard AuraContainer; it never examines
-- secret aura payloads, aura-button visibility, or spell identities in Lua.
local addonName = ...
local P = CreateFrame("Frame")
local byPlate, byUnit = {}, {}
local enabled, queued = false, false
local MAX_PLATES = 12

local function note(message)
  print("|cff63c8f7Totem Coverage|r native probe: " .. message)
end
local function diag(message)
  if type(TotemCoverage_AppendDiagnostic) == "function" then
    TotemCoverage_AppendDiagnostic("NATIVE-AURA", message)
  end
end
local function restricted()
  return InCombatLockdown and InCombatLockdown()
end
local function canUse()
  return type(CreateFrame) == "function" and
    type(C_NamePlate) == "table" and
    type(C_NamePlate.GetNamePlateForUnit) == "function"
end
local function getPlate(unit)
  if not canUse() then return nil end
  local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
  if not ok or (issecretvalue and issecretvalue(plate)) then return nil end
  return plate
end
local function eligible(unit)
  if type(unit) ~= "string" then return false end
  local ok, attackable = pcall(UnitCanAttack, "player", unit)
  if not ok or (issecretvalue and issecretvalue(attackable)) then return false end
  if not attackable then return false end
  if type(UnitIsDeadOrGhost) == "function" then
    local aliveOK, dead = pcall(UnitIsDeadOrGhost, unit)
    if aliveOK and not (issecretvalue and issecretvalue(dead)) and dead then return false end
  end
  return true
end
local function initButton(button)
  -- Configure the button BEFORE handing it to the secure AuraContainer.
  button:SetSize(18, 18)
  local texture = button:CreateTexture(nil, "ARTWORK")
  texture:SetAllPoints(button)
  texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button:SetIcon(texture)
  button:EnableMouse(false)
end
local function newContainer(plate, offsetX, offsetY, filter, candidates, labelText)
  local ok, container = pcall(CreateFrame, "AuraContainer", nil, plate, "CustomAuraContainerTemplate")
  if not ok or not container then return nil, "container:" .. tostring(container) end
  local created, errorMessage = pcall(function()
    container:SetSize(120, 22)
    container:SetPoint("BOTTOM", plate, "TOP", offsetX, offsetY)
    container:SetFrameStrata("HIGH")
    container:EnableMouse(false)
    container:SetFlowLayoutAnchorPoint("LEFT")
    container:SetFlowLayoutGrowthDirection("RIGHT")
    container:AddAuraGroup("tcprobe", filter, {
      maxFrameCount = 4,
      initializeFrame = initButton,
      candidateFilters = candidates,
      layout = {elementWidth=18,elementHeight=18,elementSpacing=2,lineSpacing=2},
    })
    container:Hide()
  end)
  if not created then
    pcall(container.Hide, container)
    return nil, "configure:" .. tostring(errorMessage)
  end
  local title = plate:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  title:SetPoint("BOTTOM", container, "TOP", 0, 1)
  title:SetText(labelText)
  title:Hide()
  return {container=container,title=title}, nil
end
local function makePair(plate)
  local left, leftError = newContainer(plate, -60, 20, "HARMFUL|PLAYER", {}, "Player debuffs")
  local right, rightError = newContainer(plate, 60, 20, "HARMFUL|PLAYER",
    {includeSpellIDs={[3600]=true}}, "Earthbind ID 3600")
  if not left or not right then
    if left then pcall(left.container.Hide, left.container); pcall(left.title.Hide, left.title) end
    if right then pcall(right.container.Hide, right.container); pcall(right.title.Hide, right.title) end
    return nil, (leftError or rightError or "unknown")
  end
  return {left=left, right=right, unit=nil}
end
local function hideEntry(entry)
  if not entry then return end
  for _, slot in ipairs({entry.left, entry.right}) do
    pcall(slot.container.Hide, slot.container)
    pcall(slot.title.Hide, slot.title)
  end
  entry.unit = nil
end
local function attach(unit)
  if not enabled or not eligible(unit) then return end
  if restricted() then queued = true; return end
  local plate = getPlate(unit)
  if not plate then return end
  local entry = byPlate[plate]
  if not entry then
    local n = 0
    for _ in pairs(byPlate) do n = n + 1 end
    if n >= MAX_PLATES then return end
    local reason
    entry, reason = makePair(plate)
    if not entry then diag("create-failed:" .. tostring(reason)); return end
    byPlate[plate] = entry
    diag("pair-created:" .. unit)
  end
  if entry.unit and entry.unit ~= unit then byUnit[entry.unit] = nil end
  local ok, err = pcall(function()
    entry.left.container:SetUnit(unit)
    entry.right.container:SetUnit(unit)
    entry.left.container:Show()
    entry.right.container:Show()
    entry.left.title:Show()
    entry.right.title:Show()
  end)
  if ok then
    entry.unit = unit
    byUnit[unit] = entry
    diag("attached:" .. unit)
  else
    queued = true
    diag("attach-failed:" .. tostring(err))
  end
end
local function refresh()
  if not enabled or restricted() then
    if restricted() then queued = true end
    return
  end
  queued = false
  if C_NamePlate and C_NamePlate.GetNamePlates then
    -- The API returns frames, not safe unit tokens. Do not fabricate tokens.
    -- Existing NAME_PLATE_UNIT_ADDED events establish token associations.
  end
  for unit in pairs(byUnit) do
    if eligible(unit) then attach(unit) else
      local entry = byUnit[unit]
      if entry then hideEntry(entry) end
      byUnit[unit] = nil
    end
  end
end
local function setEnabled(value)
  enabled = value and true or false
  if TotemCoverageDB then TotemCoverageDB.nativeAuraProbeEnabled = enabled end
  if enabled then
    note("ON: native auras on enemy plates; labels compare player debuffs and Earthbind ID filter. No range or counts.")
    refresh()
    note("New nameplates will get a probe. Leave combat and approach fresh enemies if nothing appears.")
  else
    for _, entry in pairs(byPlate) do hideEntry(entry) end
    for unit in pairs(byUnit) do byUnit[unit] = nil end
    note("OFF.")
  end
end
SLASH_TOTEMCOVERAGENATIVE1 = "/tcnative"
SlashCmdList.TOTEMCOVERAGENATIVE = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "on" then setEnabled(true)
  elseif msg == "off" then setEnabled(false)
  elseif msg == "status" or msg == "" then
    note((enabled and "ON" or "OFF") .. " | queued=" .. tostring(queued) ..
      " | Blizzard AuraContainer=" .. tostring(type(CreateFrame)=="function") ..
      " | test spell ID=3600; generic left, exact right")
  else note("Commands: /tcnative on | off | status") end
end

P:RegisterEvent("ADDON_LOADED")
P:RegisterEvent("NAME_PLATE_UNIT_ADDED")
P:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
P:RegisterEvent("PLAYER_REGEN_ENABLED")
P:RegisterEvent("PLAYER_ENTERING_WORLD")
P:SetScript("OnEvent", function(_, event, arg)
  if event == "ADDON_LOADED" then
    if arg ~= addonName then return end
    -- Never auto-start experimental UI on reload or from stale saved state.
    enabled = false
    if TotemCoverageDB then TotemCoverageDB.nativeAuraProbeEnabled = false end
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    attach(arg)
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    local entry = byUnit[arg]
    if entry then hideEntry(entry); byUnit[arg] = nil end
  elseif event == "PLAYER_ENTERING_WORLD" then
    for _, entry in pairs(byPlate) do hideEntry(entry) end
    for unit in pairs(byUnit) do byUnit[unit] = nil end
  elseif event == "PLAYER_REGEN_ENABLED" and queued then
    refresh()
  end
end)
