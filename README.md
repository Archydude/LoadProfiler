# Load Profiler

Find out which addons make your loading screen slow, and which ones make the game stutter while you play. Load Profiler times every addon as it loads at login, counts the frames each addon slows down while you play, and shows you ranked lists in one window.

Works on **Retail** (Midnight 12.1), **Mists of Pandaria Classic**, **TBC Anniversary**, **WoW Forever** and **Classic Era** (including Season of Discovery and Hardcore).

## Install
Copy the `!!LoadProfiler` folder to `World of Warcraft\<version>\Interface\AddOns\` (`_retail_`, `_classic_`, `_anniversary_`, `_classic_era_`...) and restart the game.

## Use
- Log in. A few seconds later, chat shows the total load time and the 5 slowest addons.
- `/lp`, or the pocket watch button on the minimap, opens the full list. Hover the button for the last login's slowest addons, right-click it for the options, and drag it to move it. On Retail, Load Profiler is also in the minimap's addon menu.
- The full list:
  - Load time and memory for every addon, slowest first.
  - **Search** shows only addons whose name contains what you type.
  - **Group by family** adds up related addons (all `DBM-*`, all `HandyNotes_*`, and so on).
  - **Show Blizzard** includes Blizzard's own modules.
  - **< Older / Newer >** pages through your last 10 sessions, so you can compare before and after turning addons off.
  - **Right-click an addon** to turn it off for this character, then press **Reload**. Right-click it again to turn it back on. The tooltip lists other addons that need it and won't load either. With Group by family on, a right-click turns off the whole family.
- The **While playing** tab shows what each addon costs during play:
  - **Per frame**: the addon's average time in each frame. At 60 fps the whole game has 16.7 ms for a frame.
  - **Over 10 ms**: frames where the addon alone took over 10 ms, most of a frame at 60 fps. These are the frames it most likely cost you.
  - **Over 50 ms**: frames where it alone took over 50 ms, a stutter you can see.
  - **Worst**: its slowest frame, as a range (10-50 ms, 100-500 ms...).
  - Click a column header to sort by it, and hover an addon for its counts at every frame time.
  - The top shows how long you played, all addons' time per frame and their share of the game's time, and how many frames took over 50 ms with how many of those all addons together caused.
  - The first entry is the session you're playing, and it updates live. **< Older** goes back through your last 10 play sessions and 20 boss fights, each fight saved on its own with kill or wipe.
  - Loading screens aren't counted, so a zone change doesn't show up as a stutter.
- `/lp reset` clears the history of both tabs.
- After an update, a What's New window shows what changed since the version you had. Tick **Don't show this after updates** in it to stop it opening, for all the addons that use it. `/whatsnew` shows the latest changes any time, and turns it back on.

The top of the window splits each login into three parts:
- **Addons loading**: running all addons' files and reading their saved data.
- **Login init**: all addons' startup code after loading, combined.
- **Game itself**: everything else (loading the world and your character). No addon can speed this up. To see your game's floor, log in once with only Load Profiler enabled.

## Options
Right-click the minimap button, type `/lp options`, or go to **Esc → Options → AddOns → Load Profiler**.

| Option | What it does |
|---|---|
| Show minimap button | On by default. `/lp minimap` also hides or shows it. |
| Minimap button position: Reset | Puts the button back where it started. |
| Chat summary | On by default. The total load time and the 5 slowest addons in chat after each login. |
| Saved history: Clear | Forgets all saved logins, play sessions and boss fights, like `/lp reset`. |

## Tips for accurate numbers
- **Compare cold logins, not `/reload`.** A reload reads cached files and is much faster. The window labels each session as "Cold login" or "/reload".
- **An addon's time includes its setup.** Many addons do their heavy setup the moment they finish loading, and that counts on them.
- **Login init can't be split per addon.** The game gives no way to see whose startup code ran when.
- Blizzard modules with a huge time are marked "mostly game loading". That gap is the world loading, not the module.
- Load Profiler's own cost is well under a millisecond.

## Reading the While playing numbers
- **The counts are per addon.** When several addons are a little slow in the same frame, the frame can still stutter without any single addon going over 10 ms. The line at the top that compares the game's slow frames with all addons' together catches that.
- **Family totals add up their addons** with Group by family on, so a frame where two of them were slow counts twice.
- **A play session is saved when you log out or `/reload`**, if it lasted at least a minute. Boss fights shorter than 10 seconds aren't saved.
- **The game measures this, not Load Profiler.** If the game's addon performance measuring is turned off, the tab says so and records nothing.
