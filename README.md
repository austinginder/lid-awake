# lid-awake

Keep a MacBook awake with the lid closed, even on battery.

`caffeinate` cannot do this. Closing the lid is a hardware event, not idle sleep. This toggles macOS `pmset` `disablesleep` for **battery power only**, then restores your previous sleep timer when you run it again.

## Install

Nothing to compile. It is a bash script wrapping `pmset`.

```bash
git clone https://github.com/austinginder/lid-awake.git
cd lid-awake
chmod +x lid-awake
```

Run it from the clone:

```bash
./lid-awake
```

Or copy it onto your PATH:

```bash
sudo make install
```

That installs to `/usr/local/bin/lid-awake`. Homebrew users can install into the Homebrew prefix instead:

```bash
make install PREFIX="$(brew --prefix)"
```

Uninstall:

```bash
sudo make uninstall
```

## Usage

```bash
lid-awake           # toggle on/off
lid-awake on        # stay awake with lid closed on battery
lid-awake off       # restore saved battery sleep settings
lid-awake status    # show current state
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

`pmset` needs sudo, so macOS will ask for your password.

## Warning

A closed lid traps heat. Use this for a specific job, then turn it off. Do not leave it enabled in a bag.

Only battery settings are changed. AC power is left alone.

## License

MIT. See [license](license).
