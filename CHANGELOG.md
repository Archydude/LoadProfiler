# Changelog

## 1.1.0
- Turn addons off right from the list: right-click an addon to turn it off for this character, then press Reload. Right-click it again to turn it back on. With Group by family on, a right-click turns off the whole family. The tooltip warns when other addons need it and won't load either.
- Search box: type part of a name to show only the addons that match.
- Fixed: the setup an addon does right after it loads was counted on the next addon to load, so a small addon could show a big time that wasn't its own. It now counts on the addon that did it.
- Now also works on TBC Anniversary and WoW Forever.
- Behind-the-scenes cleanup.

## 1.0.1
- Author name is now Archdude (in the addon list and the license). No changes to the addon itself.

## 1.0.0
- First release.
- Times every addon at login, with memory use, in a sortable window (`/lp`).
- Splits each login into addon loading, login init and the game's own loading.
- Group by addon family, show or hide Blizzard modules, and keep the last 10 sessions to compare.
- Chat summary of the 5 slowest addons after each login.
