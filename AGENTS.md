# Alive-echo

A single static HTML "keep-alive" page (`index.html`) that autoplays a silent looping audio clip and reloads every 20 minutes to defeat idle timers. `Button.yaml` is a Home Assistant Lovelace iframe card that embeds the GitHub Pages deployment. There is no build system, package manager, or backend.

## Cursor Cloud specific instructions

- Serve locally with `python3 -m http.server 8000` from the repo root, then open `http://localhost:8000/` (do not `file://` open it, so behavior matches the GitHub Pages deployment). Python 3 is preinstalled; there are no dependencies to install.
- Audio autoplay is blocked by the browser until the user interacts. The page handles this by retrying `forcePlay()` on `click`/`touchstart`; a single click flips the centered status text from "Touch to Start"/"Blocked - Tap again" to "Running" (dark green). This is the core behavior to verify.
- There is no lint, test, or build tooling configured in this repo.
- `Button.yaml` points at the deployed GitHub Pages URL (`Giorgio866.github.io/Alive-echo`), not localhost; testing that card requires a real Home Assistant instance with `card_mod` and is optional.
