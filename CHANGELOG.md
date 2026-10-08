# NetherGoblin changelog

## 1.4.0 - The full NetherUI theme

A /reload is enough after updating.

### Added
- **The full NetherUI window theme.** With "Follow NetherUI theme" on, NetherGoblin now
  wears Nether's whole window, as NetherSuite and NetherUI's own windows do: the drop
  shadow, patterned fill, inner and outer borders, the ornate corners (with NetherUI's
  "Ornate window frames" option), the Spectrum edge on the RGB themes, Nether's title plate
  with the name in the theme's accent and gem colours, Nether's button art, and raised
  panels and sunken wells inside. The tabs sit above the theme's border.
- **Full theme / Minimal theme** in Settings > Window & look, under "Follow NetherUI
  theme": two boxes, one ticked at a time. Minimal is the lighter look (flat theme panels
  and colours). Switching takes effect at once, no reload.

### Changed
- In the theme look, the item panel's and the Sell tab's brass name plate becomes a light
  band in the theme's accent colour with the name in its rarity colour and a drop shadow,
  and the coin chain becomes a thin line with an accent diamond.
- On Forever, gear in the item panel reads "Buyout only" instead of "Bids allowed".

### Fixed
- In the theme look the window could not be moved above the middle of the screen: it was
  still kept on screen by the goblin skin's tall crest. The limit now follows the look.

## 1.3.1 - No portrait in the theme look

A /reload is enough after updating.

### Changed
- **In the NetherUI theme look the window has no goblin portrait** in its top-left corner;
  the portrait belongs to the goblin skin. The Scan Complete window keeps its goblin in
  either look (Settings > Window & look > "Keep the goblin on the Scan Complete window in
  the theme look", on by default).

## 1.3.0 - On NetherSuite's shelf

New files (Features/Suite.lua, Media/Banner.tga, Media/Logo.tga): a /reload is enough on a
fresh install of the zip; after copying files over an old folder, log out and in.

### Added
- **NetherGoblin joins NetherSuite** when the hub is installed: a tile with its banner on
  the home page, its own page in the hub (nether://nethergoblin) with status (which auction
  house's prices, how many items, the last scan, your auctions) and diagnostics, and every
  setting in the hub's search: a result opens the right page of NetherGoblin's settings
  window. The hub only reads; every change is still made here.

- **Which look?** The first time NetherGoblin runs beside NetherUI it asks, once, whether
  to wear NetherUI's theme (named in the question) or keep the goblin's own brass and
  leather. The answer lands in Settings > Window & look > "Follow NetherUI theme", where it
  can be changed any time.

### Changed
- README: the three ways Forever's auction house differs (no bidding, gear in whole silver,
  2 / 8 / 24 hour durations) and what NetherGoblin does about each.

## 1.2.9 - Icon edges in the frame's colour

A /reload is enough after updating.

### Changed
- **Category icons and the empty item panel take the frame's border colour** (the bronze of
  the goblin skin; the theme's border under "Follow NetherUI theme") instead of white. Goods
  keep their rarity edges everywhere: results, the item panel, your bags and your auctions.

## 1.2.8 - Hotfix: "?" in Your Auctions

A /reload is enough after updating.

### Fixed
- **Stacks you had listed showed as "?"** in the Auctions and Undercuts tabs. The game
  lists a commodity auction without an item link; the name now comes from the item key, or
  from the item itself (fetched, and filled in as soon as it arrives).

## 1.2.7 - Gear sells in whole silver on Forever

A /reload is enough after updating.

### Fixed
- **"Internal auction error." on gear, found.** WoW: Forever takes a gear buyout in whole
  silver only; any copper in it is refused with that message (13s 95c, 13s 50c and 15s 50c
  refused; 13s and 14s accepted; stacks of goods take copper as before). On Forever,
  suggested gear prices are now whole silver (the cheapest listing minus a silver, or your
  undercut if larger, rounded down), and a price typed with copper is rounded with a note
  before it posts.
- The status row now shows the game's exact red text when a post is refused.

## 1.2.6 - Hotfix: knowing Forever

A /reload is enough after updating.

### Fixed
- **Forever wasn't always recognised.** The client Forever is built on can report a modern
  interface number, so the "no bidding on Forever" rule from 1.2.5 could stay off. Forever
  is now known by its version string (1.60.x) first. /goblin diag shows "Forever true".

## 1.2.5 - Posting gear the way the game does

A /reload is enough after updating.

### Fixed
- **"Internal auction error." on gear, traced.** The game's own window posts an item with
  no starting bid and a buyout; WoW: Forever has no bidding at all (its listings carry no
  minimum bid), and a post that names a bid is refused by the client. On Forever a gear
  post now goes out exactly as the game's window sends it: no bid, the buyout. The Starting
  bid box is not shown on Forever (it stays for clients that bid).
- A refusal the auction house reports by code (the modern auction house's own error event)
  now shows its text in the status row at once.

### Changed
- The Duration buttons show the game's own hours for each choice (with the full text on
  hover) instead of Short / Medium / Long.

## 1.2.4 - Diagnostics: /goblin trace

A /reload is enough after updating.

### Fixed
- A refusal the client raises from inside the post call itself now shows as the reason in
  the status row at once, instead of "No answer from the auction house" eight seconds later.

### Added
- **/goblin trace** (toggles): prints every post the auction house is asked for, from this
  window or the game's own, with its arguments and return value, and every answer that
  follows with its timing. For finding out what this client wants in a post.

## 1.2.3 - Hotfix: posting gear

A /reload is enough after updating.

### Fixed
- **"Internal auction error." on gear** (Light Bow and the like). The game requires a
  starting bid on every item auction; only the buyout is optional. A gear post with the
  Starting bid box empty now goes out with the bid equal to the price, which is what
  "buyout only" means to the auction house.

## 1.2.2 - Posting fixes, starting bid

A /reload is enough after updating.

### Fixed
- **"Internal auction error." when posting.** Two causes, both closed: a buyout-only gear
  post could reach the game with its buyout missing (an argument-list gap), and a stack whose
  commodity status the game hadn't settled when the bags were listed was posted as if it were
  gear. The post now settles the kind first (the game, then the item key, then the stack size)
  and hands every argument over explicitly.
- When the game refuses a post with its red text, that text now shows in the status row and
  the Sell tab is freed up at once instead of waiting 8 seconds.

### Added
- **Starting bid** box in the Sell tab for gear (optional; empty posts buyout only). It can't
  be above the price each.

## 1.2.1 - Hotfix: coin tab mark

A /reload is enough after updating.

### Fixed
- **The coin was pasted over the tab's bottom edge.** It now sits behind the tab button,
  tucked under it, and is centred on the button.

## 1.2.0 - Coin tab mark, /goblin fields

A /reload is enough after updating (one new file, Media/Coin.tga).

### Changed
- **The chosen tab is marked by the bottom half of a gold coin** tucked under it, in place
  of the orange bar. With "Follow NetherUI theme" on, the mark is a slim accent-coloured
  bar with a soft glow instead.

### Added
- **/goblin fields** prints the raw data the game hands back for the first listing of the
  item open in the panel (field names, types and values). For checking why a listing shows
  no minimum bid on this client.

## 1.1.6 - Hotfix: scan bar text

A /reload is enough after updating.

### Changed
- **Scan bar text is white** with a dark shadow; the dark ink was hard to read on the green
  fill once a scan had completed. Under "Follow NetherUI theme" the vial takes the theme's
  positive colour, and if that fill is light the text goes back to black with a light shadow.

## 1.1.5 - Hotfix: item panel buttons

A /reload is enough after updating.

### Fixed
- **"Max" and ">" drawn on top of each other** (and "<" over "-") in the item panel before an
  item was picked: both the commodity quantity row and the gear auction stepper were showing.
  With no item selected neither is drawn now; picking an item shows the right one.

## 1.1.4 - Hotfix: scan popup wording

A /reload is enough after updating.

### Fixed
- **The scan popup said "Browse"** for the deals line; the tab is called Buy. It now reads
  "great deals waiting in Buy: take a look", and clicking that line opens the Buy tab while
  the auction house is open (the same way the undercut line opens Undercuts).

## 1.1.3 - Hotfix: WoW Token category

A /reload is enough after updating.

### Fixed
- **A "WoW Token" category appeared** at the bottom of the category list. It came from the
  game's own category table; Forever has no token, so the entry is left out.

## 1.1.2 - Hotfix: sub-category text

A /reload is enough after updating.

### Fixed
- **Sub-categories were grey**, which read as disabled. They are in the normal text colour
  now; the selected entry is gold and its parents are lit.

## 1.1.1 - Hotfix: category names

A /reload is enough after updating.

### Fixed
- **Category names were blank** in 1.1.0 (the rows drew everything but the words).
- **One open branch at a time.** Picking a category folds the others at its level, and the
  same inside a category: opening One-Handed folds Two-Handed.

## 1.1.0 - The game's own categories, a wider window

A /reload is enough after updating.

### Added
- **The full category tree.** The Buy tab now uses the game's own auction categories, the
  same table the game's window uses: Weapons opens to One-Handed, Two-Handed, Ranged and
  Miscellaneous; Two-Handed opens to Axes, Maces, Swords, Polearms, Staves and so on, and the
  same for every other category. Click a category to search it (and open it); click it again
  to fold it. Each level searches with exactly the filters the game's window sends.
- **A Lvl column** in the results (the level the item needs), sortable like the others.

### Changed
- **The window is 300 px wider** (at full size): the category column grew to fit the tree,
  and the results list to show whole names. The frame art re-tiles for it; every tab lays
  itself out from the window's width, so they all widened. Positions and sizes are kept.

## 1.0.5 - Level requirements

A /reload is enough after updating.

### Fixed
- **Level requirements show on search results.** Each row carries the level the item needs
  ("Lv 22", in grey, after the name; gear also shows its item level as "i27"), and the row's
  tooltip gets a "Requires Level" line, which the game's group tooltip leaves out.
- **The level range filter now works regardless of the server.** The range goes to the server
  with the search as before, and the rows shown are also held to it here; an item the game has
  not described yet is listed and re-checked the moment its description arrives.

## 1.0.4 - Rarity filters

A /reload is enough after updating.

### Added
- **Rarity filters** in the Buy tab's Filters panel: Poor, Common, Uncommon, Rare, Epic and
  Legendary, in their colours. Tick any number; the search returns items of those rarities
  (none ticked = all). They go to the server with the search, like the other filters.

## 1.0.3 - No room wasted at the top

A /reload is enough after updating.

### Fixed
- **The empty band above the search row is gone.** The content now starts right at the bottom
  edge of the top bar; the title plaque's spikes and red cloth hang over the header row, so
  Filters sits between them and Search just right of the cloth. 1.0.2 shipped frame tiles cut
  for one layout with positions from another, which left an even bigger gap than designed.
- **The search box's hint no longer spills past the box**, and typed text scrolls inside it.

## 1.0.2 - A tighter top

A /reload is enough after updating.

### Changed
- **Less empty space above the search row.** The title banner now sits on the top bar (the
  plaque's bottom edge meets the bar's), its name a touch further left in the plaque; the
  content starts right under it and the frame is shorter. The close and settings buttons
  moved left of the lantern's hanging cloth. The search box is just as wide as its hint.

## 1.0.1 - Minimap button

A /reload is enough after updating.

### Added
- **Minimap button** with the goblin's face. Left-click opens the settings; right-click runs a
  Quick Scan while the auction house is open, or says when the last scan was; Shift + drag
  slides it around the minimap (round or square). Its ring takes the theme's colour in the
  theme look. Settings > Other > "Minimap button" hides it.

## 1.0.0 - First release

Everything is new: the auction house window with its six tabs, Quick Scan, the price
database with 14-day trends, tooltips, shopping lists, history, undercut checks, the guild and
party price check (@ or $), the Scan Complete and Compatibility windows (placed in Edit Mode),
the goblin skin and the NetherUI theme skin, corner resizing, and the plugin API.
