# Alarm Timer

A small macOS menu bar app for timers and alarms. Type `5m Tea` or `9:30am Standup`, press Return, and a countdown tile appears in a floating window. The soonest countdown also shows in the menu bar.

Requires macOS 13 (Ventura) or later.

## Using it

Click the timer icon in the menu bar to show or hide the window. Type an entry in the field and press Return (or click **Start**).

### What you can type

| Type | Examples | Result |
| --- | --- | --- |
| Duration | `5m`, `90s`, `1h30m`, `1h 30m`, `2 hours`, `20` (plain number = minutes) | Timer that counts down from now |
| Clock time | `9:30am`, `2pm`, `14:30`, `9:30` | Alarm at the next time that clock reading comes up |

- Text after the time becomes a label: `5m Flip Pancakes`, `3pm Call Sam`.
- A time without am/pm (`9:30`) means whichever 9:30 comes next.
- A time that has already passed today goes off tomorrow.
- Entering something that would go off at the same second as a running timer is ignored (you'll hear a beep).

### Drag a meeting from Outlook

Drag a meeting from Outlook's calendar onto the window to set an alarm for its start time, labeled with the meeting's subject. The tiles are outlined while a meeting is over the window. Meetings that have already started and all-day events are skipped.

### When time's up

The tile flashes red and the alarm sound repeats until you click anywhere in the window. Clicking clears the finished timers. Use the circled **×** on a tile to cancel a timer early.

### Menus and settings

Right-click (or Control-click) the menu bar icon for:

- **Stop All** – cancel every timer
- **Sound** – pick from 10 alarm sounds (each plays as a preview)
- **Tile Size** – Small, Medium or Large
- **Open at Login** – on by default after the first launch
- **Quit Alarm Timer**

Right-clicking the window offers **Sound** and **Tile Size** too.

### Things it remembers

- Running timers survive quitting, restarts and reboots. A timer that ran out while the app was closed rings when it opens again.
- The window's position and width. Its height always fits the tiles.
- Your sound and tile size choices.

## Building

You need the Swift toolchain (the Xcode Command Line Tools are enough).

```sh
./build.sh          # builds AlarmTimer.app in the project folder
./build.sh --run    # builds and opens it
./install.sh        # builds, runs the self-test, and installs to /Applications
```

`install.sh` also puts a copy of the app and a zip of it in `install/` (not committed), quits any running copy, and opens the newly installed one.

### Tests

There's no Xcode project, so tests are built into the app:

```sh
AlarmTimer.app/Contents/MacOS/AlarmTimer --self-test
```

They cover entry parsing, countdown formatting, the timer list, saving and restoring timers, reading Outlook meetings, and window sizing. `install.sh` runs them and stops if any fail.

## Project layout

| Path | What's there |
| --- | --- |
| `Sources/AlarmTimer/` | The app's Swift source |
| `EntryParser.swift` | Turns typed text into a timer or alarm |
| `TimerModel.swift` | Running timers, the clock, ringing, and saving |
| `TimerWindowController.swift` | The floating window and its placement |
| `TimerRowView.swift`, `CountdownView.swift` | One countdown tile |
| `OutlookMeeting.swift`, `MeetingDropView.swift` | Outlook drag and drop |
| `AppDelegate.swift` | Menu bar icon and menus |
| `AlarmSound.swift`, `TileSize.swift`, `LoginItem.swift` | Settings |
| `SelfTest.swift` | The `--self-test` checks |
| `icon/` | App icon and the script that draws it (`make-icon.sh`) |
| `Info.plist` | App bundle settings (runs as a menu bar app with no Dock icon) |
