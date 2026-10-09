# Load Profiler: CurseForge upload sheet

What to type into each CurseForge field, ready to copy and paste. The steps for a first upload and for releasing an update are in [UPLOADING.md](../UPLOADING.md).

Update this sheet with every release: the zip, the display name and the changelog, and rewrite the description so it covers everything in the new version. The release script won't publish until the zip, display name and changelog name the new version.

## A. Project form

**Project name**
```
Load Profiler
```

**Summary**
```
Find out which addons make your loading screen slow. Times every addon at login, with memory use.
```

**Main category:** `Development Tools`
**Additional categories:** `Miscellaneous`

**License:** `MIT License`

**Logo / avatar:** `!!LoadProfiler\images\logo-400.png`

**Description** (paste everything between the lines; the editor accepts Markdown — if it shows a WYSIWYG editor, switch it to Markdown first)

---
```markdown
## Why is my loading screen so slow?

Load Profiler answers that. It times every addon as it loads at login and shows a ranked list, slowest first, with each addon's memory use.

### Features
- **Load time and memory for every addon**, sorted slowest first, with colored bars.
- **Login split into three parts:** addons loading, addons' startup code, and the game's own loading. You see how much of your loading screen your addons actually cost.
- **Search** the list by addon name.
- **Turn addons off right from the list:** right-click a slow addon to turn it off for this character, then reload. It warns you when other addons need it.
- **Group by family:** add up related addons (all DBM modules, all HandyNotes plugins...).
- **History:** keeps your last 10 logins, so you can compare before and after turning addons off.
- **Chat summary** of the 5 slowest addons after each login (can be turned off).
- **Minimap button:** click for the list, hover for the last login's slowest addons, right-click for options. Works with minimap button collectors.
- Practically free: its own cost is under a millisecond.

### How to use
1. Log in. Chat shows your total addon load time and the slowest addons.
2. Click the minimap button or type **/lp** to see the full list.
3. Right-click what you don't need on that character to turn it off, log in again and compare.

Tip: to see how fast WoW loads with no addons, log in once with only Load Profiler enabled.

### Commands
- **/lp**: open or close the window
- **/lp reset**: clear the history
- **/lp minimap**: hide or show the minimap button
- **/lp options**: open the options

### Good to know
- **Compare cold logins, not /reload.** A reload reads cached files and is much faster. Each session is labeled.
- **An addon's time includes its setup.** Many addons do heavy setup right after they load, and that counts on them.
- **Startup code can't be split per addon.** The game gives no way to see whose code ran when, so that part is shown as one total.

Works on **Retail**, **Mists of Pandaria Classic**, **TBC Anniversary**, **WoW Forever** and **Classic Era** (including Season of Discovery and Hardcore).

**Feedback and bug reports are welcome** in the comments.
```
---

**Source / Issues links:** leave empty unless you put the code on GitHub.

## B. Upload File form

**File:** `dist\LoadProfiler-1.2.0.zip`

**Display name**
```
Load Profiler 1.2.0
```

**Release type:** `Release`

**Game versions:** tick all of these
- Retail: `12.1.0` and `12.1.5`
- Mists of Pandaria Classic: `5.5.4`
- TBC Anniversary: `2.5.5` and `2.5.6`
- WoW Forever: `1.60.1` (if CurseForge lists it yet)
- Classic Era: `1.15.9` (covers Season of Discovery and Hardcore)

**Changelog** (paste only the newest part; 1.0.0 and 1.0.1 are already on CurseForge, so paste 1.1.0 too if it never went up)
```markdown
1.2.0
- Minimap button: click it to open the list, hover it for the last login's slowest addons, right-click it for the options. Drag it around the minimap; it works with minimap button collectors. On Retail, Load Profiler is also in the minimap's addon menu.
- Options page (right-click the minimap button, type /lp options, or Esc > Options > AddOns > Load Profiler): show or hide the minimap button (/lp minimap does it too), put it back where it started, turn the chat summary after each login on or off, and clear the saved logins.

1.1.0
- Now works on every current version of WoW, not just Retail: Mists of Pandaria Classic, TBC Anniversary, WoW Forever and Classic Era (including Season of Discovery and Hardcore).
- Turn addons off right from the list: right-click an addon to turn it off for this character, then press Reload. Right-click it again to turn it back on. With Group by family on, a right-click turns off the whole family. The tooltip warns when other addons need it and won't load either.
- Search box: type part of a name to show only the addons that match.
- Fixed: the setup an addon does right after it loads was counted on the next addon to load, so a small addon could show a big time that wasn't its own. It now counts on the addon that did it.
- Behind-the-scenes cleanup.
```

**Related projects:** none.
