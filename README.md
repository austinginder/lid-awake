# lid-awake

Keep a MacBook awake with the lid closed, even on battery.

`caffeinate` cannot do this. Closing the lid is a hardware event, not idle sleep. Lid Awake turns on macOS's `pmset disablesleep`, sets the battery sleep timer to never, and puts your previous timer back when you run it again.

## Install

The CLI is a bash script. The menu bar app is compiled on your Mac.

```bash
git clone https://github.com/austinginder/lid-awake.git
cd lid-awake
```

Run it from the clone:

```bash
./lid-awake
```

Or copy the CLI (and menu bar sources) onto your PATH:

```bash
sudo make install
```

That installs to `/usr/local/bin/lid-awake`. Homebrew users can install into the Homebrew prefix instead:

```bash
make install PREFIX="$(brew --prefix)"
```

Uninstall:

```bash
lid-awake menubar disable   # if you enabled the menu bar
sudo make uninstall
rm -rf ~/.lid-awake ~/Library/Caches/lid-awake
```

## Usage

```bash
lid-awake           # toggle on/off
lid-awake on        # stay awake with lid closed on battery
lid-awake off       # restore saved battery sleep settings
lid-awake status    # show current state
lid-awake version   # show the installed version
```

First run enables stay-awake (saves your current battery sleep timer, then `sleep 0` + `disablesleep 1`):

```
☕️ Lid-closed stay-awake ON (battery)
   sleep 0, disablesleep 1 — don't leave this on in a bag
```

Run it again to restore:

```
😴 Lid-closed stay-awake OFF
   Restored battery sleep to 5 min, disablesleep 0
```

`pmset` needs admin access. In Terminal that is `sudo`. From the menu bar, macOS shows a password dialog.

If something else turns `disablesleep` back off while Lid Awake is on, `lid-awake status` says the battery timer is still at 0, and `lid-awake off` puts your saved timer back.

## Menu bar

Nothing extra to download. This compiles a tiny native app with `clang` (Command Line Tools — Homebrew users already have them), installs it to `~/Applications`, and launches it. No notarization.

```bash
./lid-awake menubar enable
```

Look for the coffee-cup icon. Full color means stay-awake is on; gray means off. The menu can toggle it and optionally launch at login.

```bash
lid-awake menubar disable
```

## Updates

```bash
lid-awake update --check   # is there a newer release?
lid-awake update           # install it
```

`lid-awake update` downloads the latest [release](https://github.com/austinginder/lid-awake/releases) from GitHub, replaces the CLI and the menu bar sources wherever they are installed (with `sudo` if that folder needs it), and rebuilds the menu bar app if you use it. A git clone is left alone; update it with `git pull`, then `lid-awake menubar enable`.

Checking costs one HEAD request to GitHub, at most once a day:

- When you run `lid-awake` in a terminal, it checks in the background and mentions a new release after the command's own output. Set `LID_AWAKE_NO_UPDATE_CHECK=1` to turn that off.
- The menu bar app checks when it starts and once a day. Its version line becomes **Update Lid Awake to v…**, which runs `lid-awake update` in Terminal.

Nothing else is sent anywhere.

## Warning

A closed lid traps heat. Use this for a specific job, then turn it off. Do not leave it enabled in a bag.

`disablesleep` is a system-wide switch: while stay-awake is on, the Mac does not sleep at all, on battery or on power. The only per-power-source setting Lid Awake changes is the battery sleep timer, which it saves and restores. AC sleep settings are never touched.

## License

MIT. See [license](license).
