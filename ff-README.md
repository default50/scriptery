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

| Variable      | Default                                                    | Meaning |
|---------------|------------------------------------------------------------|---------|
| `FF_PROFILE`  | `CruX`                                                     | Firefox profile to launch. |
| `FF_BIN`      | `/Applications/Firefox.app/Contents/MacOS/firefox`         | Firefox binary. |
| `SYS_PLIST`   | `/Library/Managed Preferences/org.mozilla.firefox.plist`   | System-level managed prefs. |
| `USR_PLIST`   | `/Library/Managed Preferences/$USER/org.mozilla.firefox.plist` | Per-user managed prefs. |
| `READ_DELAY`  | `10`                                                       | Seconds the prefs stay moved aside — long enough for Firefox to start and read policies. Bump it if Firefox is slow to launch on your machine. |

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

```
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

`/Applications/FF.app` is a thin **Automator "Application" applet** (bundle id
`com.apple.automator.FF`, `LSUIElement` so it runs headless) whose single "Run
Shell Script" action just calls this script:

```
COMMAND_STRING = /Users/cruzseba/git/git-legacy/scriptery/ff
shell          = /bin/zsh
```

So the app and `./ff` run the exact same logic; there's nothing to maintain in
the app itself. If you move this script, update the applet's `COMMAND_STRING`
(open `FF.app` in Automator, or edit `FF.app/Contents/document.wflow`).

If the app ever appears to do nothing, check that it (or `osascript`) has the
macOS permissions needed to touch `/Library/Managed Preferences` — Full Disk
Access can be required.

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
