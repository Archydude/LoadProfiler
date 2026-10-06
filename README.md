# Load Profiler

Find out which addons make your loading screen slow. Load Profiler times every addon as it loads at login and shows you a ranked list, with memory use, in one window.

Works on Retail (Midnight), Mists of Pandaria Classic and Classic Era.

## Install
Copy the `!!LoadProfiler` folder to `World of Warcraft\<version>\Interface\AddOns\` and restart the game.

## Use
- Log in. A few seconds later, chat shows the total load time and the 5 slowest addons.
- `/lp` opens the full list:
  - Load time and memory for every addon, slowest first.
  - **Group by family** adds up related addons (all `DBM-*`, all `HandyNotes_*`, and so on).
  - **Show Blizzard** includes Blizzard's own modules.
  - **< Older / Newer >** pages through your last 10 sessions, so you can compare before and after turning addons off.
- `/lp reset` clears the history.

The top of the window splits each login into three parts:
- **Addons loading**: running all addons' files and reading their saved data.
- **Login init**: all addons' startup code after loading, combined.
- **Game itself**: everything else (loading the world and your character). No addon can speed this up. To see your game's floor, log in once with only Load Profiler enabled.

## Tips for accurate numbers
- **Compare cold logins, not `/reload`.** A reload reads cached files and is much faster. The window labels each session as "Cold login" or "/reload".
- **Some setup time shows on the next addon.** Many addons do their heavy setup the moment they finish loading. That time is counted on the addon that loads after them. If a tiny addon shows a big number, look at the one just before it in load order (that's alphabetical, plus dependencies).
- **Login init can't be split per addon.** The game gives no way to see whose startup code ran when.
- Blizzard modules with a huge time are marked "mostly game loading". That gap is the world loading, not the module.

## How it works
The folder name starts with `!!`, so the game loads it before almost every other addon. From then on it notes the time of every `ADDON_LOADED` event. The gap between two events is the time the game spent loading the second addon. Its own cost is well under a millisecond.

Results are saved in `WTF\Account\<account>\SavedVariables\!!LoadProfiler.lua` when you log out, if you want to look at the raw numbers.
