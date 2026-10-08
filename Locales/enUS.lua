--[[ NetherGoblin - Locales/enUS.lua
	The goblin's lines for the Scan Complete window. One headline is picked by what happened in
	the scan (first match wins: undercut, deals, very fast, very slow, nothing changed, normal),
	never one of the last ten shown; then the scan's real numbers; then a sign-off. ]]

local _, ns = ...

ns.QUIPS = {
	normal = {
		"Ka-ching! Scan's done, boss.",
		"Market's counted. Every copper accounted for. Unlike your bags.",
		"Done. I read every listing so you don't have to. You're welcome.",
		"Scan complete. The market is open, and so is your wallet.",
		"All prices logged. I'd say \"easy money,\" but you've seen your gold.",
		"Finished! Somebody's gotta do the math around here.",
		"Numbers crunched, gears greased, coffee cold. Your move.",
		"The ledger is fresh. Try not to spill anything on it.",
		"Scan's in. Time to buy low, sell high, and gloat often.",
		"Another flawless scan. I'd take a bow, but my back's bad.",
		"Every price, every stack, every bad decision on the AH. Logged.",
		"Done counting. If only your raid could count to three.",
		"Market data acquired. Greed levels: optimal.",
		"I've seen the prices. I've seen things, boss.",
		"Scan complete. Profit is a choice. Choose wisely.",
	},
	fast = {
		"Done already. Blink and you'd miss it. You blinked.",
		"That was quicker than a gnome running from a trade chat argument.",
		"Speed scan! Time is money, and I just saved you both.",
		"Finished before you finished reading this. Probably.",
	},
	slow = {
		"Finally. That market was bigger than my uncle's debt.",
		"Whew. Half the realm is selling Linen Cloth. Again.",
		"Long scan. Somebody listed their entire bank. Twice.",
		"Done. I aged three years in there. Pay me in gold.",
	},
	undercut = {
		"You've been undercut. I'm not saying it's personal, but it's personal.",
		"Somebody's cheaper than you. Let's go ruin their day.",
		"Undercut detected. Time to show 'em who's boss.",
		"Someone just knocked a copper off your price. A whole copper. The nerve.",
		"Undercut! Grab your coin purse, we're going to war.",
	},
	deals = {
		"Bargains spotted! Someone's practically giving it away. Take it.",
		"Deals on the board. Somebody didn't check the market. We did.",
		"Cheap stuff ahead. My nose for profit is twitching.",
		"Somebody sold low. Their loss, your lunch.",
	},
	quiet = {
		"Nothing moved. The market's as sleepy as a tauren after lunch.",
		"Same prices as last time. Even the market's bored.",
		"Quiet day. Too quiet. Somebody's plotting something.",
		"No changes. Go farm something, I'll keep watch.",
	},
	signoff = {
		"In gold we trust!",
		"Time is money, friend.",
		"Buy low. Sell high. Gloat always.",
		"Every copper counts. Especially yours.",
		"No refunds.",
		"The house always wins. Be the house.",
	},
}
