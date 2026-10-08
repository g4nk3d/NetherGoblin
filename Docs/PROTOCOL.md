# NetherGoblin price-check protocol (version 1)

Addon message prefix `NGpc`, sent on the same channel the question came from (GUILD or PARTY).

A question is any guild or party line starting with `@` or `$` followed by an item link or an
exact item name, optionally `x<count>` (`@[Linen Cloth]x20`, `$Linen Cloth x 20`).

Every NetherGoblin client that saw the line and knows the item (a price under three days old):

1. waits `0.15 + 2.2 * (age / 3 days) + random(0..0.25)` seconds (fresher prices wait less);
2. if no claim for that question arrived meanwhile, sends a claim: `1|C|<hash>`
   (`1` = protocol version, `hash` = 8 hex digits of the channel, sender and text);
3. waits 0.5 s more; when another claim arrived in that time, the client whose full name
   (`Name-Realm`) sorts first answers and the other stays quiet;
4. whispers the asker one line: `NetherGoblin: [link] x20: 1g 44s (7s 20c each) - usual 7s 85c
   - seen 2 h ago - PvP auction house`.

Clients that see a claim before their own wait is over stay quiet. Claims are forgotten after
12 s, so a question asked again is answered again. One answer per asker every 4 s, one every
1.5 s overall. Nothing is sent in instances or while the game blocks addon chat. Messages
longer than 64 characters, with a newer protocol version, or malformed are dropped and
counted (`/goblin diag`). Nothing received is ever run as code; names are never split.
