# Changelog

## 1.3.0
- New **While playing** tab: see which addons make the game stutter. For every addon, its average time per frame, how many frames it took over 10 ms and over 50 ms by itself, and its worst frame. Click a column header to sort by it, and hover an addon for its counts at every frame time.
- The top of the tab shows how long you played, all addons' time per frame and their share of the game's time, and how many frames took over 50 ms, with how many of those all addons together caused.
- The session you're playing updates live. Each play session is saved when you log out or reload, and each boss fight is saved on its own, marked kill or wipe. < Older goes back through the last 10 play sessions and 20 boss fights. Loading screens aren't counted.
- Bigger text in the window, so the list is easier to read. The window is a little larger to fit it.
- /lp reset and Clear in the options now clear both tabs' history.

## 1.2.0
- Minimap button: click it to open the list, hover it for the last login's slowest addons, right-click it for the options. Drag it around the minimap; it works with minimap button collectors. On Retail, Load Profiler is also in the minimap's addon menu.
- Options page (right-click the minimap button, type /lp options, or Esc > Options > AddOns > Load Profiler): show or hide the minimap button (/lp minimap does it too), put it back where it started, turn the chat summary after each login on or off, and clear the saved logins.

## 1.1.0
- Now works on every current version of WoW, not just Retail: Mists of Pandaria Classic, TBC Anniversary, WoW Forever and Classic Era (including Season of Discovery and Hardcore).
- Turn addons off right from the list: right-click an addon to turn it off for this character, then press Reload. Right-click it again to turn it back on. With Group by family on, a right-click turns off the whole family. The tooltip warns when other addons need it and won't load either.
- Search box: type part of a name to show only the addons that match.
- Fixed: the setup an addon does right after it loads was counted on the next addon to load, so a small addon could show a big time that wasn't its own. It now counts on the addon that did it.
- Behind-the-scenes cleanup.

## 1.0.1
- Author name is now Archdude (in the addon list and the license). No changes to the addon itself.

## 1.0.0
- First release.
- Times every addon at login, with memory use, in a sortable window (`/lp`).
- Splits each login into addon loading, login init and the game's own loading.
- Group by addon family, show or hide Blizzard modules, and keep the last 10 sessions to compare.
- Chat summary of the 5 slowest addons after each login.
