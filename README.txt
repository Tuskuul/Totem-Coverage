TOTEM COVERAGE v0.1.1-beta.16 | WoW Forever 1.60.1
================================================
TEST BUILD: Not yet tested in a running Forever client.

INSTALL
Extract the TotemCoverage folder to:
World of Warcraft\_forever_\Interface\AddOns\TotemCoverage\
Restart the game or /reload.

ENABLE WORLD NAMEPLATES
Enable Friendly Player Nameplates and Friendly Totems in the game's options.
(The latter may be under nameplate/minion settings depending on build.)
If the physical totems have no nameplates, the addon has nothing to attach to.

COMMANDS
/tc                  Show current status
/tc settings         Open nameplate settings
/tc diag on          Record API diagnostics; request native combat logging
/tc diag off         Stop addon diagnostics; stop combat log only if started by this addon
/tc diag clear       Clear SavedVariables diagnostic records (requires diag off)
/tc mode all         Display observed affected, missing and unknown party members
/tc mode missing     Display only confirmed missing buffs
/tc mode affected    Display only confirmed affected buffs
/tc scan             Force a scan

WHERE THE TWO LOGS GO
1. Game's native file: _forever_\Logs\WoWCombatLog*.txt
2. Addon file after /reload or logout:
   _forever_\WTF\Account\<account>\SavedVariables\TotemCoverage.lua
The second file is a Lua table, not plain-text .log. Both contain timestamps
for later offline comparison. Logs cannot be appended to files directly in Lua.
Enable Advanced Combat Logging in the game's Network options first.
Do NOT delete someone else's combat log: if already enabled, we leave it alone.

BEFORE TESTING
- In a five-player group, drop a Strength of Earth or Mana Spring totem.
- Observe floating names above the matching totem's nameplate.
- Move a party member out of range, then back in; note what changes.
- Test combat and a dungeon. Gray '?' means UNKNOWN, never falsely 'missing'.
- After a short test use /tc diag off then /reload; send both logs.

CURRENT CAVEATS
- Visible nameplates are matched to your ACTIVE totem's name, not yet
  cryptographically linked to your personal summoned totem. If another
  shaman drops the same named totem, it can be falsely matched. That is
  deliberately documented and is a primary diagnostic test.
- Windfury, periodic-heal and other totems may not have directly readable
  persistent party auras. Unsupported mappings show no extra names, not guessed data.
- Buff names are provisional English labels; ranks/localization may vary.
- Only player and party1-party4 are checked. Raid subgroups are not yet supported.
- Aura reads may become secret in combat; these are marked UNKNOWN.
- Requires totems with attached client nameplates and standard nameplate APIs.
- Diagnostics capped at 1,200 recent records; oldest entries auto-culled on load and during logging.
- If native combat logging is already running, this addon leaves it untouched.
- No source code copied from ShamanPower or Totem Nameplates.

DEBUG REPORT
After testing, send TotemCoverage.lua and WoWCombatLog*.txt. The 2 files
may contain character names, combat metadata and other identifying details.
Review/redact them before sharing if you wish.

OFFENSIVE TARGET ALPHA (v0.1.1-beta)
- Searing Totem nameplate shows direct target if the Forever unit-token API exposes it.
- Otherwise shows Target unknown; a missing unit token is not proof the totem is idle.
- /tctarget on | off controls the experimental display (ON by default).
- /tc diag on logs TARGET state changes for correlation with native combat logs.
- No restricted COMBAT_LOG_EVENT_UNFILTERED registration; no guessed last-hit target.
- If another shaman drops an identical totem, nameplate ownership is not yet confirmed.

NAMEPLATE DEFAULT
Totem nameplates default enabled. /tc settings toggles this preference.
If addon is listed but /tc is unknown, enable /console scriptErrors 1
then /reload and report first Lua error.

DIAGNOSTICS v0.1.1-beta.3
A separate read-only diagnostics module records raw active/name/start/duration/icon
for each totem slot, including nil/secret/error distinctions, observed nameplate
unit names, GUIDs, removal/addition events, combat status, and CVar visibility.
/tc scan takes a manual snapshot while diagnostics are enabled.
Change-only observations plus 20-second checkpoints reduce log volume.
Totem detection and overlays remain experimental: no direct live combat log reads.

BETA.4 NAMEPLATE FIX
Unit tokens are obtained from NAME_PLATE_UNIT_ADDED, not frame.namePlateUnitToken.
GetNamePlateForUnit attaches the overlay to the observed physical nameplate.
Last confirmed totem state is retained during secret-data combat periods,
with known durations limiting retention. Earthbind shows its own name as
an initial visual confirmation. Offensive target labels use same event method.
This build is experimental; test in and out of combat before stable release.

BETA.5 DISPLAY UPDATE
/tc settings provides stacked (default) or inline party names.
/tc layout stacked or /tc layout inline changes the setting directly.
Party names use 14pt outlined text and are anchored just above the totem plate.
The existing game totem name stays visible: the addon does not duplicate it.
Earthbind and unmapped totems show no extra label or debug fallback.
Only readable, mapped party coverage states are displayed. Unknown values retain '?'.

BETA.7 EFFECT-BASED COVERAGE
Harmful totem effects use hostile visible nameplates and HARMFUL aura reads.
Earthbind detects the Earthbind debuff (spell 3600 or matching aura name).
The same stacked/inline layout works for ally buffs and enemy debuffs.
Affected names are green. All/Missing modes may also show confirmed
unaffected (red x), and All shows unreadable/secret status (gray ?).
Other totems retain beneficial aura tracking where a persistent aura exists.
Direct-damage, cleansing, threat, triggered and pulse-only totems are not
falsely represented as aura coverage; their effects need separate detectors.
This build detects observed auras, not verified caster ownership or distance.

BETA.8 COMBAT RESTRICTION FIX
Avoid querying unit auras during InCombatLockdown on Forever because
GetAuraDataByIndex can fail on secret data with a Lua taint error.
Coverage statuses during lockdown become UNKNOWN (gray ? in All mode);
previous YES matches are not misleadingly retained as verified current data.
Aura reads resume automatically after combat. No unverified enemy distance
or caster attribution is inferred from seeing the Earthbind debuff.

BETA.9 DYNAMIC ENEMY COUNTS AND IN-COMBAT SUMMON FALLBACK
Enemies of the same name and confirmed state are grouped: Vile Familiar x3.
Counts change whenever visible enemy GUIDs or aura statuses change, at the
existing 1.5 second scan cadence. Counts are NOT proximity predictions.
Unknown enemy entries are hidden by default; /tc unknown on makes them
visible in All mode. When all statuses are unknowable during combat, a
single 'Coverage unknown (combat)' note indicates the restricted data.
A visible recognized totem nameplate can serve as fallback when summoned
in combat with secret GetTotemInfo data. Its owner cannot be verified, so
this fallback can match another shaman's similarly named physical totem.
No combat-only guessed debuff counts or taint-causing aura reads.

BETA.10 OBSERVED ENEMY DISPLAY RESTORED
Confirmed debuff matches display green; visible hostile units with unavailable
or secret debuff information display gray with '?' (enabled by default).
Identical names are grouped by state and distinct observed GUID: e.g.
'Vile Familiar x3' (confirmed) and 'Vile Familiar x2 ?' (unverified).
Counts refresh as nameplates appear/disappear and accessible aura states change.
The gray number is the count of OBSERVED enemies, not guaranteed to be in
Earthbind range, slowed or owned by this totem. No guesswork on distance.
The 'Coverage unknown (combat)' generic placeholder is removed.
/tc unknown off disables unknown enemy names; /tc unknown on restores them.
The setting is also available in /tc settings and persists between sessions.
Missing mode still shows confirmed unaffected enemies only. No combat aura
polling is resumed; restricted reads remain skipped to avoid Lua taint.

BETA.11 DEAD ENEMY FILTER
Hostile nameplate targets confirmed dead (UnitIsDeadOrGhost or readable
zero UnitHealth) are excluded from all effect-count states immediately on
next scan. Unreadable/secret death information is not assumed dead.
This preserves the combat-safe unknown state for units that cannot be checked.

BETA.12 DEAD-UNIT COUNT DIAGNOSTICS
When /tc diag on is enabled, each visible hostile GUID gets a change-only
enemy-decision entry: nameplate unit, name, dead flag, readable health state,
death determination, aura state and included/excluded display decision.
The enemy-count entry records observed, confirmed-dead, included and hidden
totals and the precise displayed lines for each Earthbind scan that changes.
These records let us correlate death transitions with x3 -> x2 displays.
Dead units never contribute to included counts. No full-health logging and
no new restricted combat aura reads. Diagnostic output is saved on /reload.

BETA.13 FAST CORPSE UPDATE
Reduced recurring display refresh from 1.5 seconds to 0.4 seconds.
UNIT_HEALTH and UNIT_FLAGS changes on observed nameplates also trigger a
recount where client events are available. A confirmed dead Creature GUID
is latched for the current world session so a recycled unit token cannot
briefly bring its corpse back into the count. The GUID memory clears on
PLAYER_ENTERING_WORLD. Gray enemy totals remain visible nameplate counts,
not enemies proven in Earthbind range. Combat aura checks stay disabled.

BETA.14 TOTEM EFFECT PROFILE FOUNDATION
New TotemEffects.lua registry: 21 known physical totems with provisional
baseline radius, effect kind, target category, verification method and notes.
Range data is reference only; addon does not measure true unit-to-totem
distance and does not silently infer auras or hits.
Earthbind: base 10 yd slow; confirmed debuffs stay green; observed, unknown
mobs are gray with a prominent "Observed; range unverified" label.
Gray counts DO NOT mean targets inside Earthbind's slow.
Searing: its separate target module is retained and now labels its
20 yd attack reach; direct unit-token target exposure is still experimental.
Magma (8 yd AoE), Stoneclaw (8 yd taunt), friendly pulse and utility
totems show effect/radius plus "Recipients unverified" rather than
fabricated affected counts. Friendly persistent buff totems continue
using aura observations with mappings supplied by the registry.
/tc range Earthbind (or /tc range Magma etc.) displays registry values.
Fire Nova is cast from an existing fire totem; talents are not automatically
factored into any base radii. No new combat aura calls or protected APIs.
Nameplate auto-enable, its checkbox, stacked/inline and unknown toggles
remain unchanged and saved.

BETA.15 AUTOMATIC DIAGNOSTIC LOG CULL
All addon modules now write through a shared bounded logger.
At login, old beta history is automatically trimmed to the latest 1,200
entries; during diagnostics, the oldest 250 entries are dropped whenever
the ceiling is reached. This prevents the SavedVariables log from growing
without limit, while retaining the most recent investigation records.
Diagnostics remain OFF by default after reload. /tc diag size reports the
current saved record count; /tc diag clear still wipes everything manually
when logging is OFF. /reload or logout is required to write the culled file.
Note: if one session produces >1,200 entries, early session markers may be
pruned; the latest events are favored over long historical session retention.
Native WoWCombatLog files are managed by the client, not this cull.

BETA.16 VERIFIED-FIRST EARTHBIND DISPLAY AND GUID REVALIDATION
The primary Earthbind overlay now lists only positively observed Earthbind
debuff auras. This does NOT establish caster ownership or totem-to-NPC range.
Missing debuffs never count as "unaffected inside range": generic nameplates
cannot establish Earthbind's 10 yd proximity. Combat-secret or unreadable
auras display a single "Earthbind status unknown" line rather than inflated
coverage totals. /tc unknown on explicitly opts into gray visible-enemy
names and counts, labeled "range unverified". Legacy show-unknown default
is migrated to OFF once, after which user choices persist.
Enemy counts require readable GUIDs, and live nameplate GUIDs, display names,
and plate frames are revalidated on each scan to handle recycled tokens,
including same-named creatures. Confirmed dead GUID exclusions stay active.
All existing friendly-nameplate controls and diagnostic culling remain.
