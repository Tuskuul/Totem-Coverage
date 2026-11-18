-- Totem Coverage range and verification registry, WoW Forever 1.60.1.
-- Radius values are baseline spell descriptions, not live measured distances.
-- nil radius means unverified; talents, patches and ownership can vary.
-- 'verification' defines how evidence would be observed; it is NOT proof
-- that a live combat-safe API currently exposes this effect.
TotemCoverageEffects = {
  ["Earthbind Totem"] = {kind="hostile-debuff", baseRadius=10, target="enemies", verification="aura", auraNames={"Earthbind"}, spellIDs={[3600]=true}, note="Slow; range cannot be measured from nameplate observation"},
  ["Stoneclaw Totem"] = {kind="hostile-taunt", baseRadius=8, target="enemies", verification="event", auraNames=nil, spellIDs=nil, note="Taunt; no persistent aura confirmation"},
  ["Searing Totem"] = {kind="single-target-attack", baseRadius=20, target="enemy", verification="direct-target", auraNames=nil, spellIDs=nil, note="Attack reach; target API is experimental"},
  ["Magma Totem"] = {kind="hostile-pulse", baseRadius=8, target="enemies", verification="pulse", auraNames=nil, spellIDs=nil, note="Periodic fire damage; hits not independently verified"},
  ["Strength of Earth Totem"] = {kind="friendly-buff", baseRadius=30, target="group", verification="aura", auraNames={"Strength of Earth"}, spellIDs=nil, note="Persistent strength buff"},
  ["Stoneskin Totem"] = {kind="friendly-buff", baseRadius=30, target="group", verification="aura", auraNames={"Stoneskin"}, spellIDs=nil, note="Persistent physical mitigation buff"},
  ["Grace of Air Totem"] = {kind="friendly-buff", baseRadius=30, target="group", verification="aura", auraNames={"Grace of Air"}, spellIDs=nil, note="Persistent agility buff"},
  ["Windfury Totem"] = {kind="friendly-buff", baseRadius=30, target="group", verification="aura", auraNames={"Windfury Totem", "Windfury"}, spellIDs=nil, note="Weapon effect; aura presence may not fully prove application"},
  ["Flametongue Totem"] = {kind="friendly-buff", baseRadius=30, target="group", verification="aura", auraNames={"Flametongue Totem", "Flametongue"}, spellIDs=nil, note="Weapon effect; aura presence may not fully prove application"},
  ["Fire Resistance Totem"] = {kind="friendly-buff", baseRadius=30, target="group", verification="aura", auraNames={"Fire Resistance"}, spellIDs=nil, note="Resistance buff"},
  ["Frost Resistance Totem"] = {kind="friendly-buff", baseRadius=30, target="group", verification="aura", auraNames={"Frost Resistance"}, spellIDs=nil, note="Resistance buff"},
  ["Nature Resistance Totem"] = {kind="friendly-buff", baseRadius=30, target="group", verification="aura", auraNames={"Nature Resistance"}, spellIDs=nil, note="Resistance buff"},
  ["Windwall Totem"] = {kind="friendly-buff", baseRadius=30, target="group", verification="aura", auraNames={"Windwall"}, spellIDs=nil, note="Ranged damage mitigation"},
  ["Mana Spring Totem"] = {kind="friendly-pulse", baseRadius=30, target="group", verification="pulse", auraNames=nil, spellIDs=nil, note="Periodic mana restore; not a persistent aura guarantee"},
  ["Mana Tide Totem"] = {kind="friendly-pulse", baseRadius=30, target="group", verification="pulse", auraNames=nil, spellIDs=nil, note="Periodic mana restore; not a persistent aura guarantee"},
  ["Healing Stream Totem"] = {kind="friendly-pulse", baseRadius=30, target="group", verification="pulse", auraNames=nil, spellIDs=nil, note="Periodic heal; not a persistent aura guarantee"},
  ["Tremor Totem"] = {kind="friendly-pulse", baseRadius=30, target="group", verification="pulse", auraNames=nil, spellIDs=nil, note="Periodic fear/charm/sleep removal"},
  ["Poison Cleansing Totem"] = {kind="friendly-pulse", baseRadius=30, target="group", verification="pulse", auraNames=nil, spellIDs=nil, note="Periodic poison cleanse"},
  ["Disease Cleansing Totem"] = {kind="friendly-pulse", baseRadius=30, target="group", verification="pulse", auraNames=nil, spellIDs=nil, note="Periodic disease cleanse"},
  ["Grounding Totem"] = {kind="reactive-utility", baseRadius=nil, target="group", verification="trigger", auraNames=nil, spellIDs=nil, note="Intercepts eligible spells; range not verified"},
  ["Sentry Totem"] = {kind="remote-utility", baseRadius=nil, target="player", verification="vision", auraNames=nil, spellIDs=nil, note="Remote viewpoint; no fixed effect radius confirmed"},
}
