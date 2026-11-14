# PolyLinuxGame
 Polymorphic Lab built for Buildroot Linux

## PolyBandit v3 image

The PolyBandit v3 game lives in [`bandit/`](bandit/). That folder is exactly
what gets copied into `/root` of the image; nothing else in this repo is packaged.

`bandit/installbandit.sh` becomes `/root/install.sh`, which `.profile` runs at
login. It builds bandit levels 1–13 in parallel, waits for them, then logs the
student in as `bandit1`.

`profile`, `.profile`, `nextlevel` and `prevlevel` also exist at the repo root
for the older labs; keep the two copies in sync when changing them.

### CI

`.github/workflows/build_image.yml` builds the image with
[giacobe/buildroot-builder2](https://github.com/giacobe/buildroot-builder2)
(pinned commit, `basic-compression` config, Buildroot 2025.02.15) on every push,
pull request and weekly, then:

- `.github/scripts/verify-image.sh` checks the image contains every required
  command and only the `bandit/` payload;
- `.github/scripts/boot-test.py` boots it in QEMU, enters a test email, checks
  bandit1's flag and walks `nextlevel` through bandit13.
- `.github/scripts/assemble-site.sh` builds the browser version (`web/index.html`
  plus [v86](https://github.com/copy/v86) and the image), and
  `.github/scripts/page-test.mjs` plays it in headless Chrome up to bandit2.

The kernel/base system is cached, so most runs only repackage `bandit/`.
Download `polybandit3.bzImage` and `polybandit3.rootfs.cpio.gz` from the run's
artifacts, or from the GitHub release when you push a `v*` tag.

### Play in the browser

Every push to `main` that passes CI publishes the browser version to GitHub
Pages at `https://ruffm.github.io/polybandit3/`. The page boots the image in
v86, logs in as root automatically and starts the installer. Nothing is sent
to a server; reloading the page starts over.

One-time setup: **Settings → Pages → Build and deployment → Source: GitHub Actions**.

To try a change before pushing, serve a locally assembled site:

```sh
bash .github/scripts/assemble-site.sh <dir with polybandit3.bzImage + .rootfs.cpio.gz> <copy/v86 checkout>/bios site
python3 -m http.server 8080 --directory site
```

### Dependency updates

`.github/dependabot.yml` opens one PR a week when the GitHub Actions used here
have new versions. The v86 version is pinned separately (`V86_VERSION` and the
`copy/v86` commit in the workflow).
