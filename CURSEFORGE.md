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
See which addons slow your loading screen and which ones make the game stutter while you play.
```

**Main category:** `Development Tools`
**Additional categories:** `Miscellaneous`

**License:** `MIT License`

**Logo / avatar:** `!!LoadProfiler\images\logo-400.png`

**Description** (paste everything between the lines; the editor accepts Markdown — if it shows a WYSIWYG editor, switch it to Markdown first)

---
```markdown
## Why is my game slow?

Load Profiler shows which addons make your loading screen slow and which ones make the game stutter while you play, each as a ranked list, slowest first.

### Loading screen
- **Load time and memory for every addon**, slowest first.
- **Login split into three parts:** addons loading, addons' startup code, and the game's own loading, so you see what your addons actually cost.
- **History** of your last 10 logins, to compare before and after turning addons off.
- **Chat summary** of the 5 slowest addons after each login.

### While playing
- **Every addon's time per frame**, how many frames it alone took over 10 ms (likely a lost frame) and over 50 ms (a stutter you can see), and its worst frame.
- **All addons together:** how many frames took over 50 ms, and in how many of them your addons together took over 50 ms.
- **The session you're playing updates live.** Play sessions are saved when you log out, and every boss fight is saved on its own, kill or wipe.
- Loading screens aren't counted.

### Both lists
- **Search** by addon name, and **group by family** (all DBM modules, all HandyNotes plugins...).
- **Turn addons off right from the list:** right-click one to turn it off for this character, then reload. It warns you when other addons need it.
- **Minimap button:** click for the window, hover for the last login's slowest addons, right-click for options. Works with minimap button collectors.

### How to use
1. Log in. Chat shows your total load time and the slowest addons.
2. Type **/lp** or click the minimap button. Play for a while, then open the While playing tab.
3. Right-click what you don't need, reload and compare.

### Good to know
- **Compare cold logins, not /reload.** A reload reads cached files and loads much faster.
- **While playing counts each addon on its own.** Several slightly slow addons can still add up to a stutter, and the all-addons line catches that.
- After an update, a What's New window shows what changed.

Works on **Retail**, **Mists of Pandaria Classic**, **TBC Anniversary**, **WoW Forever** and **Classic Era** (including Season of Discovery and Hardcore).

**Feedback and bug reports are welcome** in the comments.
```
---

**Source / Issues links:** leave empty unless you put the code on GitHub.

## B. Upload File form

**File:** `dist\LoadProfiler-1.4.0.zip`

**Display name**
```
Load Profiler 1.4.0
```

**Release type:** `Release`

**Game versions:** tick all of these
- Retail: `12.1.0` and `12.1.5`
- Mists of Pandaria Classic: `5.5.4`
- TBC Anniversary: `2.5.5` and `2.5.6`
- WoW Forever: `1.60.1` (if CurseForge lists it yet)
- Classic Era: `1.15.9` (covers Season of Discovery and Hardcore)

**Changelog** (paste only the newest part)
```markdown
1.4.0
- After an update, a What's New window shows what changed since the version you had. Tick **Don't show this after updates** to stop it opening, for all the addons that use it. Type **/whatsnew** to see the latest changes, or to turn it back on.
- Fixed: typing in the search box of the game's options (Esc > Options) could show the error "AddOn '!!LoadProfiler' tried to call the protected function 'IsUserOAuthed()'". The Reset and Clear buttons no longer come up in that search; they're still on Load Profiler's options page.
```

**Related projects:** none.
