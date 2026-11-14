# PolyLinuxGame
 Polymorphic Lab built for Buildroot Linux

## PolyBandit v3 image

(For PolyBandit 3.1, see [below](#polybandit-31-subtree).)

The PolyBandit v3 game lives in [`bandit/`](bandit/). That folder is exactly
what gets copied into `/root` of the image; nothing else in this repo is packaged.

`bandit/installbandit.sh` becomes `/root/install.sh`, which `.profile` runs at
login. It builds bandit levels 1–13 in parallel, waits for them, then logs the
student in as `bandit1`.

`profile`, `.profile`, `nextlevel` and `prevlevel` also exist at the repo root
for the older labs; keep the two copies in sync when changing them.

### PolyBandit 3.1 (subtree)

[`polybandit3.1/`](polybandit3.1/) is
[giacobe/polybandit3.1](https://github.com/giacobe/polybandit3.1) kept as a git
subtree, with its own history and GPL-3.0 license. Don't edit it here; pull
Nick's updates with:

```sh
git subtree pull --prefix polybandit3.1 https://github.com/giacobe/polybandit3.1 main
```

### CI

`.github/workflows/build_image.yml` builds two images on every push, pull
request and weekly, one per version, with
[giacobe/buildroot-builder2](https://github.com/giacobe/buildroot-builder2)
(pinned commit, `basic-compression` config, Buildroot 2025.02.15):

| Check | Folder packaged into `/root` | Installer | Image files |
|---|---|---|---|
| `build (v3)` | `bandit/` | `installbandit.sh` | `polybandit3.*` |
| `build (v3.1)` | `polybandit3.1/` | `install.sh` | `polybandit3.1.*` |

Both share one cached kernel/base system, so most runs only repackage. Each
version is then tested:

- `polybandit3.1/test.sh` (3.1 only) runs the lab's own contract checks;
- `.github/scripts/verify-image.sh` checks the image has every required
  command and that `/root` matches the packaged folder byte for byte;
- `.github/scripts/boot-test.py --flavor v3|v31` boots it in QEMU, enters a
  test email, checks bandit1's answer (and 3.1's exercise code) and walks
  `nextlevel` through bandit13;
- `.github/scripts/assemble-site.sh` builds the browser version (`web/index.html`
  plus [v86](https://github.com/copy/v86) and the image), and
  `.github/scripts/page-test.mjs` plays it in headless Chrome up to bandit2.

Download the images from the run's artifacts, or from the GitHub release when
you push a `v*` tag.

### Play in the browser

Every push to `main` where both versions pass publishes them to GitHub Pages:

- `https://ruffm.github.io/polybandit3/` — landing page (`web/landing.html`)
- `https://ruffm.github.io/polybandit3/v3.1/`
- `https://ruffm.github.io/polybandit3/v3/`

Each page boots its image in v86, logs in as root automatically and starts the
installer. The 3.1 page also shows a **Submit answers** button linked to the
`form_url` in `polybandit3.1/lab.json`. Nothing is sent to a server; reloading
the page starts over.

One-time setup: **Settings → Pages → Build and deployment → Source: GitHub Actions**.

To try a change before pushing, serve a locally assembled site:

```sh
VERSION_NAME=v3.1 LAB_JSON=polybandit3.1/lab.json \
  bash .github/scripts/assemble-site.sh <image dir> polybandit3.1 <copy/v86 checkout>/bios site
python3 -m http.server 8080 --directory site
```

### Dependency updates

`.github/dependabot.yml` opens one PR a week when the GitHub Actions used here
have new versions. The v86 version is pinned separately (`V86_VERSION` and the
`copy/v86` commit in the workflow).
