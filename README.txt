TOTEM COVERAGE v0.1.0-test | WoW Forever 1.60.1
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
  persistent party auras. Unsupported mappings say 'No buff mapping'.
- Buff names are provisional English labels; ranks/localization may vary.
- Only player and party1-party4 are checked. Raid subgroups are not yet supported.
- Aura reads may become secret in combat; these are marked UNKNOWN.
- Requires totems with attached client nameplates and standard nameplate APIs.
- Diagnostics capped at 30,000 records to avoid unbounded SavedVariables growth.
- If native combat logging is already running, this addon leaves it untouched.
- No source code copied from ShamanPower or Totem Nameplates.

DEBUG REPORT
After testing, send TotemCoverage.lua and WoWCombatLog*.txt. The 2 files
may contain character names, combat metadata and other identifying details.
Review/redact them before sharing if you wish.
