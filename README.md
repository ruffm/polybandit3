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

The kernel/base system is cached, so most runs only repackage `bandit/`.
Download `polybandit3.bzImage` and `polybandit3.rootfs.cpio.gz` from the run's
artifacts, or from the GitHub release when you push a `v*` tag.
