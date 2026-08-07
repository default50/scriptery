# ff — Firefox managed-policy bypass launcher (macOS)

Launches Firefox with the machine's **managed preferences** temporarily moved
aside, so an enterprise-forced profile (managed `policies`) doesn't apply to the
session. It moves the managed-pref plists out of the way, flushes `cfprefsd`,
starts Firefox on a chosen profile, then puts everything back.

This is macOS-specific and requires root (to touch `/Library/Managed
Preferences`). It supports authenticating by **Touch ID**.

## Usage

```bash
./ff            # move prefs aside, launch Firefox, restore
./ff --debug    # also report whether policies are still forced after the flush
./ff --help
```

It can also be launched from Spotlight via a small wrapper app (see
[The FF.app wrapper](#the-ffapp-wrapper)).

## Requirements

- macOS with Firefox installed at `/Applications/Firefox.app`.
- Admin rights (the script uses `sudo` / a GUI elevation prompt).
- A Firefox profile matching `FF_PROFILE` (default `CruX`).
- Optional: Touch ID configured for `sudo` (see below) for fingerprint auth.

## Configuration knobs

Edit these at the top of the script:

- `FF_PROFILE` — Firefox profile to launch. Default `CruX`.
- `FF_BIN` — Firefox binary. Default
  `/Applications/Firefox.app/Contents/MacOS/firefox`.
- `SYS_PLIST` — system-level managed prefs. Default
  `/Library/Managed Preferences/org.mozilla.firefox.plist`.
- `USR_PLIST` — per-user managed prefs. Default
  `/Library/Managed Preferences/$USER/org.mozilla.firefox.plist`.
- `READ_DELAY` — seconds the prefs stay moved aside, long enough for Firefox
  to start and read policies. Default `10`; bump it if Firefox is slow to
  launch on your machine.

## How it works

Moving the managed-pref plist aside is **not** sufficient on its own. Firefox
reads these values via `CFPreferencesCopyAppValue`, and those values are served
(and cached in memory) by `cfprefsd`. So the flow has to be:

1. Move `SYS_PLIST` and `USR_PLIST` to `*.bak`.
2. `killall cfprefsd` so the cache is dropped and re-read from disk (now absent).
3. Launch Firefox and give it a few seconds to read policies.
4. Move the plists back and `killall cfprefsd` again so the rest of the system
   sees the managed prefs restored.

### Single elevation + marker synchronization

All the privileged work (steps 1–2 and 4) runs as **one** root shell
(`PRIV_SESSION`) launched in the background. That single elevation matters —
see [Authentication](#authentication-touch-id) for why. The sequence is:

- root session: move aside → flush → `touch` a marker file → `sleep READ_DELAY`
  → (on exit) restore → flush.
- main script: wait for the marker to appear, then launch Firefox **as the
  user** (never as root), then `wait` for the root session to finish restoring.

The marker file lives under the user's `TMPDIR` so the (unprivileged) main
script can clean it up afterward even though root created it.

### Restore is guaranteed

The root session installs traps so the plists are always put back, even if it's
interrupted:

- `trap '<restore>' EXIT` — restore on any exit.
- `trap 'exit 130' INT TERM` — turn a Ctrl-C / termination into an exit, which
  fires the EXIT trap.

If you ever see Firefox still honoring policy after a crash, check for leftover
`*.bak` files next to the plists and move them back manually.

### `--debug`

Prints whether `EnterprisePoliciesEnabled` still resolves in the managed-prefs
domain after the flush (via `defaults read`). Purely diagnostic; it never gates
the launch. Handy when the bypass doesn't seem to take effect.

## Authentication (Touch ID)

The script needs root twice (move aside, then restore) but is written to prompt
**at most once**. Two mechanisms are used depending on how it's launched:

### From a terminal

Uses `sudo`. Credentials are primed once up front with `sudo -v`, so the
backgrounded elevation doesn't need to prompt again. With Touch ID enabled for
`sudo`, this is a fingerprint prompt.

### From Spotlight / FF.app (no terminal)

A GUI-launched process has no controlling terminal, so plain `sudo` can't read a
typed password. The script tries, in order:

1. **`sudo` anyway** — `pam_tid` presents its own Touch ID *sheet*, which is a
   GUI prompt and needs no tty. If your fingerprint succeeds, no password field
   ever appears.
2. **`osascript … with administrator privileges`** — a password-only dialog,
   used only if the `sudo`/Touch ID attempt fails or is cancelled.

> Why not just always use `osascript`? Each `osascript … with administrator
> privileges` call authenticates independently (its 5-minute credential cache is
> per-process), so doing move-aside and restore as two separate `osascript`
> calls prompted for a password **twice**. Collapsing all privileged work into a
> single `sudo` elevation is what gets it down to one prompt — and lets Touch ID
> work.

### Enabling Touch ID for `sudo`

This is the external dependency that makes the fingerprint prompt appear. It is
**not** in this repo — it's a system PAM config change.

On macOS 14+ the update-safe location is `/etc/pam.d/sudo_local` (unlike editing
`/etc/pam.d/sudo` directly, which is reset by OS updates). `/etc/pam.d/sudo`
already does `auth include sudo_local`. To enable:

```bash
sudo cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local
sudo sed -i '' 's/^#auth/auth/' /etc/pam.d/sudo_local
```

Result (`cat /etc/pam.d/sudo_local`):

```text
auth       sufficient     pam_tid.so
```

Verify:

```bash
sudo -k && sudo -v   # should show a Touch ID prompt, not a password field
```

To undo: `sudo rm /etc/pam.d/sudo_local`.

Notes:

- Confirmed: `pam_tid` fires even when `sudo` is invoked from a GUI-launched
  process with no tty (i.e. the Spotlight/FF.app path), so Touch ID works there
  too.
- This survives OS updates because it lives in `sudo_local`. If the fingerprint
  prompt ever reverts to a password dialog on a new machine or after a wipe,
  re-run the two commands above.

## The FF.app wrapper

`FF.app` is a tiny launcher app whose only job is to run this script, so it can
be started from Spotlight or Finder instead of a terminal. It runs the exact
same `ff` logic — there is nothing app-specific to maintain inside it.

### Recreating it on a new machine

Use the bundled installer, which rebuilds the app from scratch with `osacompile`
and points it at the `ff` script next to it:

```bash
./install-ff-app.sh                       # installs /Applications/FF.app
./install-ff-app.sh ~/Applications/FF.app # or a custom location
```

It generates an AppleScript applet equivalent to:

```applescript
do shell script "/absolute/path/to/ff"
```

sets `LSUIElement` (no Dock icon), applies the bundled icon, and installs the
bundle (using `sudo` only if the destination isn't writable). The script path is
baked in at install time from wherever the repo lives, so re-run the installer
if you move the repo.

> An `.app` is a generated, code-signed bundle, so it isn't committed to the
> repo directly — the installer is the source of truth instead.

### The icon

The launcher's icon is preserved in the repo as **`ff-app.icns`** and applied by
the installer, which copies it over the applet's `applet.icns` (referenced by
`CFBundleIconFile`).

There's a catch: `osacompile` also ships an **asset catalog** (`Assets.car` plus
a `CFBundleIconName` key), and on modern macOS that asset-catalog icon *wins*
over `CFBundleIconFile`. So the installer also **removes `CFBundleIconName` and
`Assets.car`**, making `CFBundleIconFile` authoritative, then re-signs the
bundle ad-hoc (editing Info.plist / Resources invalidates the signature) and
runs `lsregister -f` to force LaunchServices to pick up the new icon.

`ff-app.icns` itself was extracted from the original app's Finder custom icon
(a `kHasCustomIcon` flag plus an `Icon\r` resource fork). Using `CFBundleIconFile`
instead of re-applying that resource-fork custom icon keeps the mechanism clean
and bundle-local. If an old icon still lingers after reinstall: `killall Dock
Finder`.

To update the icon, replace `ff-app.icns` (a 1024×1024 `.icns`) and re-run the
installer.

### The original applet (for reference)

The first version was an **Automator "Application"** (bundle id
`com.apple.automator.FF`, `LSUIElement`) with a single **Run Shell Script**
action:

```text
COMMAND_STRING = /path/to/scriptery/ff-scripts/ff
shell          = /bin/zsh
```

To recreate that flavor by hand: open **Automator** → **New** →
**Application** → add **Run Shell Script** → set shell to `/bin/zsh` and body
to the absolute path of `ff` → save as `FF.app` to `/Applications`. The
`osacompile` installer above is the reproducible equivalent and is preferred.

### Permissions

If the app appears to do nothing, check that it (or `osascript`) has the macOS
permissions needed to touch `/Library/Managed Preferences` — **Full Disk
Access** may be required (System Settings → Privacy & Security → Full Disk
Access). Touch ID on this path needs `pam_tid` enabled (see
[Authentication](#authentication-touch-id)).

## Troubleshooting

- **"policies still forced" / bypass has no effect** — run `./ff --debug`.
  Ensure `SYS_PLIST` / `USR_PLIST` paths match reality; managed prefs domains
  can differ by MDM.
- **Prompted for a password instead of Touch ID** — `pam_tid` isn't enabled;
  see [Enabling Touch ID for `sudo`](#enabling-touch-id-for-sudo).
- **Prompted twice** — indicates two separate elevations; the script is built to
  avoid this, so check for local edits that split the privileged work.
- **Leftover `*.bak` files** — a crash/kill before restore. Move
  `org.mozilla.firefox.plist.bak` back to `org.mozilla.firefox.plist` (both the
  system and per-user copies) and `sudo killall cfprefsd`.

## History / rationale

This started as a `policies.json` write/remove hack, which stopped working. The
current approach moves the *managed preferences* plists and flushes `cfprefsd`.
Along the way the auth handling grew to: one elevation instead of two (to avoid
a double prompt), a background-session + marker design (so Firefox still launches
as the user in between), interrupt-safe restore via traps, and Touch ID support
on both the terminal and GUI launch paths.
