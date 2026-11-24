"""Print the demo notification list (ii's notifications.json format), timed relative to now."""
import json, time
now = int(time.time() * 1000)
def n(i, app, icon, s, b, mins, actions=()):
    return {"notificationId": 9000 + i, "appName": app, "appIcon": icon, "summary": s, "body": b,
            "time": now - mins * 60000, "urgency": "1", "image": "", "actions": list(actions)}
print(json.dumps([
    n(1, "Calendar", "x-office-calendar", "Design review in 10 min", "Room 3 · lok bar & sidebar polish", 3,
      [{"identifier": "open", "text": "Open"}, {"identifier": "snooze", "text": "Snooze"}]),
    n(2, "Builds", "utilities-terminal", "Build passed", "dots-hyprland-asus · main · 2m 14s", 12),
    n(3, "Mail", "mail-unread", "Weekly digest", "3 new issues in end-4/dots-hyprland", 26),
    n(4, "Mail", "mail-unread", "Release notes", "Quickshell 0.3 is out", 41),
    n(5, "Updates", "system-software-update", "12 updates available", "Run pacman -Syu when convenient", 58)], indent=2))
