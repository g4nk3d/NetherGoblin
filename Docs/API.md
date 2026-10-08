# NetherGoblin plugin API (version 1)

The global `NetherGoblin` is the whole public surface. Nothing else in the addon is a
promise; the modules may change between versions, this table will not without a version bump.

```lua
local G = NetherGoblin
if G and G.API_VERSION >= 1 then
    local p = G:GetPrice(itemLink)          -- or "item:2589", or an item ID
    -- p = { market = copper, lowest = copper, listed = count, age = seconds } or nil
    local mv = G:GetMarketValue(itemLink)   -- copper or nil
    local low = G:GetLowest(itemLink)       -- the last scan's lowest, or nil
    local hist = G:History(itemLink)        -- { { day, low, qty }, ... } oldest first
    local scan = G:LastScan()               -- { at = unix time, items = n, seconds = s }
    G:IsAuctionHouseOpen()
    G:FormatMoney(123456)                   -- "12g 34s 56c" with coin icons

    local plugin = G:RegisterPlugin("MyAddon", "1.0")
    plugin:On("SCAN_DONE", function(summary)
        -- summary = { items, seconds, newLows, deals, changed, undercut }
    end)
    plugin:On("AH_OPEN", function() end)
    plugin:On("AH_CLOSED", function() end)
    plugin:On("POSTED", function(info) end)      -- info.item.link, info.qty, info.unit
    plugin:On("BUY_DONE", function(info) end)    -- info.itemID, info.qty, info.total
    plugin:On("CANCELLED", function(auctionID) end)
    plugin:On("SKIN_CHANGED", function(mode) end) -- "goblin" | "theme"
end
```

`day` in a history row is days since 2020-01-01 (UTC). Prices are per unit, in copper, for
the auction house the player is on (each ruleset keeps its own book).

A plugin's listener that fails five times is switched off for the session, with one line in
chat; the core never stops because of a plugin. Plugins never need NetherGoblin's files: load
after it (`## OptionalDeps: NetherGoblin`) and check the global exists.
