# NetherGoblin

Version 1.4.3 - Interface 16001 (WoW: Forever 1.60.x) - All Rights Reserved (see LICENSE.txt)

Optimize your auctions. In gold we trust!

An auction house goblin for the Nether family. Works alone; talks to NetherUI when it is
installed (its theme can dress the window) and sits on NetherSuite's shelf when the hub is
there (its tile, its page, every setting in the hub's search). Nothing in it buys, posts or
cancels without a click of yours: that is the game's rule, and NetherGoblin keeps to it.

Built for WoW: Forever's auction house, which differs from the modern one in three ways
NetherGoblin follows: there is no bidding (every auction is buyout), a piece of gear sells in
whole silver only (stacks of goods take copper), and the durations are 2, 8 and 24 hours.

## What it does

- **Its own auction house window**, in the goblin's brass and leather, with the game's window
  tucked away behind it (`/goblin blizzard` brings the game's window back for one visit; a
  setting switches to it for good). Six tabs along the bottom: Buy, Sell, Auctions, Undercuts,
  Shopping, History.
- **Quick Scan.** One pass over the whole auction house: every item's lowest price and how many
  are listed, in a few seconds. The work is spread over frames (a few milliseconds each, less
  in combat or at a low frame rate), so the game never stutters. It runs on its own when you
  open the auction house and the prices are older than half an hour (setting).
- **Buy.** Search, the game's full category tree (Weapons > Two-Handed > Axes...), filters (exact name, usable only, rarity, level range), recent
  searches, and for the selected item: a 14-day price trend, the usual price, the lowest now,
  how many are listed and how many you carry, a deal meter, and buying. Stackable goods: pick a
  quantity, click Buyout once for the exact price, once more to buy. Gear: step through the
  auctions and Buyout (Bid too, on a client that bids). A Great / Good / Fair / Pricey badge
  on every result.
- **Sell.** What you carry that can be sold, what it sells for right now, a price filled in
  (the cheapest listing minus your undercut, or the usual price when none is listed; whole
  silver for gear on Forever), quantity, duration, deposit, what you keep after the cut, and
  Post. It asks first when a price is under what a vendor pays or far under the usual price.
- **Auctions and Undercuts.** Your auctions with sold ones marked, bids, time left; the ones
  someone has undercut, with "Check now" for an exact count from the live listings, and
  "Cancel next undercut" to clear them one click at a time (then repost from the Sell tab).
- **Shopping lists.** Lists of things to buy, each item with a most-you-will-pay price;
  "Search this list" looks them all up and marks the ones within your price. The star on the
  Buy tab adds the current search to a list.
- **History.** Everything you posted, bought, bid on or cancelled on this character, with the
  week's totals.
- **Tooltips.** The usual price, the lowest at the last scan (and how old that is), and the
  whole stack's value, on every item tooltip in the game.
- **Guild and party price checks.** Anyone types `@Linen Cloth`, `$[Linen Cloth]` or
  `@Linen Cloth x20` in guild or party chat and one NetherGoblin user answers by whisper: the
  one with the freshest price. Prices older than three days are never used. Quiet in instances.
- **The goblin talks.** When a scan finishes, his portrait and speech bubble pop up in the
  lower middle of the screen with a random line (about forty of them, picked by what the scan
  found: undercuts, bargains, a quick or a slow scan, a quiet market) and the scan's numbers.
  Hover keeps it open, a click closes it, the undercut line opens the Undercuts tab. It waits
  out combat. Jokes and the ka-ching sound each have a switch. A second window, in the middle
  of the screen, asks the questions that need an answer (another auction addon found: disable
  and reload, keep both, ask later). Both are placed in the game's Edit Mode.
- **Size and looks.** The window opens at 75% of its full size and is resized by dragging the
  gear on its bottom-right corner (50% up to what fits the screen; double-click for 75%);
  everything scales together, so the layout always fits. Size and position are remembered
  (account-wide, or per character). "Follow NetherUI theme" swaps the goblin brass for your
  NetherUI theme's panels, colours and animations; the first time NetherGoblin runs beside
  NetherUI it asks once which look you want.
- **Minimap button.** The goblin's face on the minimap: left-click for the settings, right-click
  for a Quick Scan at the auction house (or the last scan's numbers in chat), Shift + drag to
  move it. A switch in the settings hides it.
- **Rulesets.** Each auction house (PvE, PvP, RP, Hardcore, or a mix such as RP-PvP) keeps its
  own price book; they never blend.

## Commands

`/goblin` (or `/ng`) opens the settings. `/goblin scan`, `/goblin blizzard`,
`/goblin reset window`, `/goblin reset popups`, `/goblin diag`, `/goblin fields` (raw listing data for the item in the panel), `/goblin trace` (print every post and the game's answers; toggles).

## For other addons

`NetherGoblin:GetPrice(link)` and friends: see Docs/API.md. The price-check messages are in
Docs/PROTOCOL.md; the modules in Docs/ARCHITECTURE.md.
