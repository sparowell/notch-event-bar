# Notch Event Bar

A macOS app that shows where you are in your day: the event that is running, how much of it is left, and what comes next. It lives in the menu bar and in a panel that opens under the notch.

Reworked from [NotchBar](https://github.com/Periicles/Notchapp) by Periicles (MIT). The original licence is kept in `LICENSE`.

## What it shows

- **Menu bar:** time left in the running event, then `→ next event in 35 min`. Optionally a mini progress bar in place of the icon and a limit on how many words of a title are shown.
- **Panel** (hover the notch): title, time range with duration, a progress bar, elapsed and remaining time, and what follows.
- **Breaks:** the gap between two events gets its own bar, measured from the end of the last event or from the start of your day.
- **Nested meetings:** a meeting inside a longer event (a work block, say) appears as a capsule on the bar, with its name and a countdown.
- **Join:** a button appears two minutes before a meeting with a Zoom, Meet, Teams or Webex link, and stays while it runs.
- **Settings:** which calendars to track, start of the day, notifications, colours and thickness of the capsules, emoji instead of words for elapsed and remaining.

Events are read from the macOS Calendar through EventKit, so a Google calendar works once it is added to Calendar.app. The app only goes online when you press Check for Updates.

## Install

1. Download `NotchEventBar.dmg` from [Releases](https://github.com/sparowell/notch-event-bar/releases/latest) and drag the app to Applications.
2. The app is signed ad hoc and not notarized, so macOS blocks it on first launch. Lift the block once:

```bash
xattr -dr com.apple.quarantine /Applications/NotchEventBar.app
```

3. Open it and allow full access to Calendars. Pick the calendars to track in the settings (the gear in the panel, or the menu bar icon).

Requires macOS 14 or later.

## Build from source

Needs the full Xcode.

```bash
swift build
swift test
scripts/package.sh        # dist/NotchEventBar.app and .dmg
```

To update a local install: `git pull`, `scripts/package.sh`, replace the app in `/Applications`.

## Releases

Tags of the form `v0.5.0` (numeric only) trigger `.github/workflows/release.yml`, which builds and publishes the dmg.

## Licence

MIT, see `LICENSE`.
