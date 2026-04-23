# Known Issues

This document tracks known limitations and edge cases in **Multishot Midnight**.
None of the issues below cause crashes or data loss.

---

## Watermark Persistence (Rare)
In some situations, the watermark overlay may remain visible briefly after a screenshot is taken.

- This does **not** affect screenshots themselves
- The issue is cosmetic only
- A forced hide safeguard is in place
- A full lifecycle cleanup is planned

Status: Tracked, non-blocking

---

## Limited Delve Completion Detection
Delve completion detection relies on available scenario and encounter signals.

- Works reliably for most Delves
- Some edge cases may not fire a screenshot
- Will improve as Blizzard exposes more stable Delve APIs

Status: Expected behavior for 12.0.x

---

## Screenshot Timing Variance
Screenshot timing may differ slightly depending on latency, UI state, or combat lockdown.

- This is expected behavior
- Delay options help mitigate most cases

Status: By design

---

If you encounter issues not listed here, please open an issue on GitHub with:
- Event type (Boss kill, PvP end, etc.)
- Instance type (Raid, Dungeon, Delve, BG)
- Any error messages (if present)

GitHub Issues:  
https://github.com/wildwynd/Multishot-Midnight/issues
