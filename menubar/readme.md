# Lid Awake menu bar

A native, dependency-free macOS menu bar app. The coffee-cup icon is full
color when lid-closed stay-awake is on, and gray when it is off. The menu
toggles stay-awake, warns not to leave it on in a bag, can register itself to
launch at login, and shows its version, or an update when one is out.

## How it ships

There is no separate download. `lid-awake menubar enable` compiles
`Sources/main.m` locally with `clang`, assembles `~/Applications/Lid Awake.app`,
ad-hoc signs it, and launches it. Building on the user's machine avoids
notarization. Anyone with Homebrew already has the Command Line Tools this
needs.

- `lid-awake menubar enable` — install (or update/overwrite) and launch
- `lid-awake menubar disable` — quit, unregister the login item, and remove
  the app

The app shells out to the same `lid-awake` script that built it (path baked
in at compile time). Toggle from the menu bar uses macOS's admin-password
dialog instead of `sudo`.

Status is read via `lid-awake status --porcelain` (`state=on` / `state=off`,
plus `sleep=` and `version=`). When changing that contract, update
`Sources/main.m` alongside.

## Updates

The app's version is the CLI's `VERSION`, stamped into `Info.plist` at build
time. At launch, and then once a day by the wall clock (an `NSTimer` stops
counting while the Mac sleeps), it sends a HEAD request to
`github.com/austinginder/lid-awake/releases/latest` and reads the version from
the `releases/tag/v<version>` redirect. When that is newer, the version line
becomes **Update Lid Awake to v…**, which writes a `.command` file and opens
it in Terminal to run `lid-awake update`. The update can ask for a sudo
password and rebuilds (and so quits) this app, which is why it runs there and
not inside the app.
