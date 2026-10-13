# Changelog

## [Unreleased]

The first release. Lid Awake keeps a MacBook awake with the lid closed, even on battery, from the command line or a native menu bar app, and now keeps itself up to date from GitHub.

### ✨ New Features

* **Lid-closed stay-awake:** `lid-awake` toggles macOS's `pmset disablesleep` and sets the battery sleep timer to never, then puts your previous timer back when you run it again. `on`, `off` and `status` do one thing each, and `status --porcelain` prints `state=`, `sleep=` and `version=` for scripts.
* **Menu bar app:** `lid-awake menubar enable` compiles a small native app with `clang` on your Mac, installs it to `~/Applications`, and launches it, so there is nothing to notarize or download. The coffee-cup icon is full color while stay-awake is on and gray while it is off, the menu toggles it (with the macOS password dialog instead of `sudo`), and it can launch at login. `lid-awake menubar disable` removes it.
* **Release zip:** every release carries `lid-awake.zip`, and https://github.com/austinginder/lid-awake/releases/latest/download/lid-awake.zip always fetches the newest. Unzip it, then `sudo make install` (or `make install PREFIX="$(brew --prefix)"`), or run `./lid-awake` from the folder.
* **`lid-awake update`:** downloads the new release's `lid-awake.zip` from GitHub (or its source tarball, should a release ever ship without one), checks it, replaces the CLI and the menu bar sources wherever they are installed (asking for `sudo` only when that folder needs it), and rebuilds the menu bar app. `lid-awake update --check` only reports. A git clone is left for `git pull`.
* **Update notices:** the CLI checks GitHub at most once a day with a single HEAD request that downloads nothing, in the background, and mentions a new release after a command run in a terminal (`LID_AWAKE_NO_UPDATE_CHECK=1` turns it off). The menu bar app checks at launch and once a day, and its version line turns into **Update Lid Awake to v…**, which runs the update in Terminal.
* **`lid-awake version`:** prints the installed version. The menu bar app is stamped with the same version, and `lid-awake menubar` says when the two differ.

### 🔒 Security & Bug Fixes

* **A cancelled password no longer loses your sleep timer:** turning stay-awake off deleted the saved battery timer before asking for the password, so cancelling the prompt meant the next `off` restored the default 5 minutes instead of yours. The saved timer is now kept until the change succeeds, and turning stay-awake on saves it only after the change succeeds.
* **A session cut short is put right:** if `disablesleep` is turned off some other way while stay-awake is on, the battery timer was left at 0 and `lid-awake off` answered "already OFF". `status` now says so, `off` restores the saved timer, and turning stay-awake on again keeps the saved timer instead of saving the 0.
* **`off` keeps a timer it didn't set:** with `disablesleep` turned on by hand and no saved timer, `off` now leaves a non-zero battery timer as it is instead of resetting it to 5 minutes.
* **Admin commands are quoted:** the password-dialog path now passes each argument through AppleScript's `quoted form of` instead of pasting them into one shell string.
* **The menu bar build handles any install path:** a path containing a quote or backslash no longer breaks compiling the app, and `menubar enable` refuses to run under `sudo`, which would have installed a root-owned app.

### 📖 Documentation

* **What "battery only" means:** `disablesleep` is system-wide, so while stay-awake is on the Mac does not sleep on battery or on power. The README now says so, and that the battery sleep timer is the only per-source setting Lid Awake changes.
