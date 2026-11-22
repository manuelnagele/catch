# Catch

Fishing on **WoW: Forever**, made calm: one button to fish, a cast bar you can read at a glance, every catch counted and
valued, and where the fish are. A [Deadbeat](https://github.com/manuelnagele/deadbeat) module.

## What you get

- **One fishing button** (keyboard and controller at once): each press puts your fishing pole on if you hold something
  else, then your best lure if there's none, then casts; while the bobber is out, it reels in. A **done fishing** key
  (and an icon) stops the cast and puts your weapon and off-hand back on.
- **Cast bar**, only while a cast runs: a strip of dusk water lit amber, a float riding the head, your **bite window**
  (when your fish usually bite, learned from your casts) as a warm haze; the float dips inside it.
- **Lure timer** beside the cast bar: a ring that drains, red in the last 2 minutes, greyed when the lure is gone.
  Click it to put on your best lure.
- **Every catch** rises above the bar as a card (icon in its quality colour, name, worth); rare and record catches
  sparkle. A **creel** under the bar counts your fish and the session's worth; quiet adventurer quotes drift by.
- **On the bar** while you fish: the water you're at, the take, gold per hour, your fishing skill. The tooltip: what
  bites here (chance, value, share).
- **Fishing panel** under the bar: catch feed, where the gold comes from, catches per minute, value over time.
- **Map:** hotspots where you've caught (bronze → gold by value per catch, pools ringed) and the zone's waters ranked
  by expected gold per catch. Works on the world map and OpenMap.
- **Fishing mode:** while you fish, the rest of the UI fades; it comes back when you move, fight or stop.
- **Sounds:** its own soft sounds (bobber lands, bite window, catches) and ambience (lakeside, dusk), all switchable.

**Values** are vendor prices. If you have a price addon that provides `ForeverMarketPrices` (`c` and `g` tables of
item ID → copper), Catch uses those market prices instead.

## Settings

The gear on Deadbeat's bar → **Catch** (switches, the fishing and done-fishing keys, resets) and **Catch · Sounds**
(pick each sound, ambience). Right-click the cast bar to open the sounds. Commands: `/catch` (panel) · `keys` ·
`sounds` · `map` · `reset` · `debug`.

## Install

Copy the `Catch` folder into `World of Warcraft/_forever_/Interface/AddOns/`. Best with
[Deadbeat](https://github.com/manuelnagele/deadbeat); OpenMap supported.

## Credits

Drop tables and zone skill bases: FishMate (MIT, © 2026 AndreiBerkut, see
`LICENSE-FishMate`), from wowforever.ninja; they cover 16 zones so far, everywhere else Catch measures your catches.
The one-button approach follows FishMate's. Sounds and textures are Catch's own (`tools/make_sounds.py`,
`tools/make_textures.py`).

## Development

```
luajit tests/run.lua     # the fishing math
luajit tests/smoke.lua   # the whole addon on Deadbeat (needs ../deadbeat and ../deadbeat-spec)
```
Releases: push a tag `vX.Y.Z` matching the TOC's version; CI packages the zip onto GitHub Releases.
`deploy/` is the author's Linux setup that keeps a game install in sync with this repo (optional).

License: MIT (FishMate's data: MIT, `LICENSE-FishMate`).
