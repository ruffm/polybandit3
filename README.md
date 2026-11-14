# PolyLinuxGame
 Polymorphic Lab built for Buildroot Linux

## Layout

| Folder | What it is |
|---|---|
| [`polybandit3.0/`](polybandit3.0/) | PolyBandit 3.0, the original thirteen-level game |
| [`polybandit3.1/`](polybandit3.1/) | PolyBandit 3.1, [giacobe/polybandit3.1](https://github.com/giacobe/polybandit3.1) kept as a git subtree |
| [`web/`](web/) | The v86 browser page and the landing page published to GitHub Pages |
| [`.github/`](.github/) | CI: image builds, tests, baseline releases, Pages deploy |
| [`legacy/`](legacy/) | Files from earlier PolyLinux labs (basic, file manipulation, TJ). Not built or packaged. |

Each game folder is exactly what gets copied into `/root` of its image;
nothing else in this repo is packaged.

### PolyBandit 3.0

`polybandit3.0/installbandit.sh` becomes `/root/install.sh`, which `.profile`
runs at login. It builds bandit levels 1–13 in parallel, waits for them, then
logs the student in as `bandit1`.

### PolyBandit 3.1 (subtree)

`polybandit3.1/` has its own history and GPL-3.0 license. Don't edit it here;
send changes upstream to giacobe/polybandit3.1 and pull them in with:

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
| `build (v3)` | `polybandit3.0/` | `installbandit.sh` | `polybandit3.*` |
| `build (v3.1)` | `polybandit3.1/` | `install.sh` | `polybandit3.1.*` |

Both package on the same kernel/base system (see [Baseline releases](#baseline-releases)),
so most runs only repackage. Each version is then tested:

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

### Baseline releases

The kernel and base rootfs (the Buildroot "baseline") are published as GitHub
releases so every lab build packages on a fixed, tested base instead of
rebuilding Buildroot. Release tags look like
`baseline-basic-compression-br2025.02.15-<confighash>`; each has `bzImage`,
`rootfs.cpio.gz`, `SHA256SUMS`, `baseline.json` (Buildroot version, builder
commit, config hash, the run that built it) and `baseline-manifest.tar.gz`
(configs, manifest, build logs).

1. **Build:** Actions → **Publish baseline** → Run workflow. It builds,
   checks the bare base boots, and publishes a **pre-release**.
2. **Test:** Actions → **Build PolyBandit images** → Run workflow with
   `baseline_tag` set to the new tag and **allow_prerelease_baseline** checked.
   Both versions must pass.
3. **Promote:** `gh release edit <tag> --prerelease=false --latest=false`
   (or untick "Set as a pre-release" on the release page).

Lab builds then use it automatically: with `BASELINE_TAG` blank in
`build_image.yml`, they look for a promoted release whose config hash matches
their Buildroot config, fall back to the Actions cache, and only build from
source if neither exists. Set `BASELINE_TAG` to pin an exact release. The job
summary of every run says which baseline it used.

Other repos can build on the same base:

```sh
gh release download <tag> -R ruffm/polybandit3 -D baseline/images -p bzImage -p rootfs.cpio.gz
scripts/03-package-payload.sh --baseline baseline ...   # from giacobe/buildroot-builder2
```

### Dependency updates

`.github/dependabot.yml` opens one PR a week when the GitHub Actions used here
have new versions. The v86 version is pinned separately (`V86_VERSION` and the
`copy/v86` commit in the workflow).
