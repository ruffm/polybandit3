#!/usr/bin/env python3
"""Boot a packaged PolyBandit image in QEMU and play it like a student.

  1. the kernel boots and reaches a login
  2. root's .profile runs install.sh, which asks for an email and confirmation
  3. the installer logs in as bandit1 and shows the level banner
  4. bandit1's answer (inhere.txt) matches the value derived from the email,
     the guest date and the lab's answer scheme
  5. `nextlevel` walks through every level up to the last one

--flavor picks the lab version:
  v3   polybandit3 bandit/ (original scheme, "Welcome to The PolyLinux Game")
  v31  polybandit3.1 (seed-v1 answers, exercise code, staged level readiness)
"""
import argparse, base64, functools, hashlib, re, shlex, sys, time
import pexpect

# Flush every line so progress shows up live in the Actions log.
print = functools.partial(print, flush=True)

EMAIL = "ci-test@psu.edu"
SYSTEM_PASSWORD = "systemPassword"      # installer default
LEVEL_PASSWORD_ROOT = "levelPassword"   # installer default

FLAVORS = {
    "v3": {
        "banner": "Welcome to The PolyLinux Game",
        "date_cmd": 'date +"%m-%d-%Y"',
        "readme_marker": "Instructions for this level",
    },
    "v31": {
        "banner": "PolyLinux: PolyBandit",
        "date_cmd": 'date +"%Y-%m-%d"',
        "readme_marker": "Exercise code:",
    },
}

STAGE = ["starting"]


def fail(msg, tail=""):
    # Annotations keep only the first line of ::error::, so keep it one line and
    # print the console tail as ordinary (collapsible) log lines.
    if tail:
        print("::group::Last console output")
        print(tail)
        print("::endgroup::")
    print(f"::error::boot test failed while {STAGE[0]}: {msg}")
    sys.exit(1)


def expected_answer(flavor, email, guest_date, level):
    """Answer for one level, computed independently of the guest's scripts."""
    if flavor == "v3":
        h = hashlib.sha256(
            f"{email}{guest_date}{SYSTEM_PASSWORD}{LEVEL_PASSWORD_ROOT}{level}".encode()
        ).hexdigest()
        return base64.b64encode((h + "\n").encode()).decode()[:20]
    # v31: level_seed_v1 in polylinux-common.sh, answer_token in resources.sh
    fields = ["polylinux-seed-v1", "polybandit", email.strip().lower(), guest_date,
              SYSTEM_PASSWORD, f"{LEVEL_PASSWORD_ROOT}{level}", str(level)]
    seed = hashlib.sha256("".join(f + "\0" for f in fields).encode()).hexdigest()
    answer_hex = hashlib.sha256(f"{seed}:answer".encode()).hexdigest()
    b64 = base64.b64encode(answer_hex.encode()).decode().rstrip("=")
    return b64.replace("+", "-").replace("/", "_")[:20]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kernel")
    ap.add_argument("--initrd")
    ap.add_argument("--flavor", choices=sorted(FLAVORS), default="v3")
    ap.add_argument("--levels", type=int, default=13)
    ap.add_argument("--log", default="boot.log")
    ap.add_argument("--kvm", action="store_true")
    ap.add_argument("--boot-timeout", type=int, default=300)
    ap.add_argument("--level-ready-timeout", type=int, default=300,
                    help="v31: how long nextlevel may keep saying a level is being prepared")
    ap.add_argument("--cmd", help="override the spawned command (for self-testing)")
    a = ap.parse_args()
    fl = FLAVORS[a.flavor]

    if a.cmd:
        cmd = a.cmd
    else:
        if not (a.kernel and a.initrd):
            ap.error("--kernel and --initrd are required")
        cmd = " ".join([
            "qemu-system-i386", "-m", "512M", "-nographic", "-no-reboot",
            "-kernel", shlex.quote(a.kernel), "-initrd", shlex.quote(a.initrd),
            "-append", shlex.quote("console=ttyS0 panic=-1"),
            "-netdev", "user,id=n0", "-device", "e1000,netdev=n0",
        ] + (["-enable-kvm", "-cpu", "host"] if a.kvm else []))

    print(f"flavor {a.flavor}; spawning: {cmd}")
    log = open(a.log, "w", encoding="utf-8", errors="replace")
    vm = pexpect.spawn("/bin/sh", ["-c", cmd], encoding="utf-8",
                       codec_errors="replace", timeout=60, dimensions=(50, 200))
    vm.logfile_read = log
    marker = [0]

    ansi = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]|\r")

    def run(command, timeout=60):
        """Run a shell command in the guest; return its cleaned output."""
        marker[0] += 1
        start, end = f"__CS{marker[0]}__", f"__CE{marker[0]}__"
        # Markers are split with '' so the echoed command line can't match them.
        vm.sendline(f"echo {start[:4]}''{start[4:]}; {command}; echo {end[:4]}''{end[4:]}")
        # The serial console ends lines with \r\r\n, so allow any number of \r.
        vm.expect(re.escape(start) + r"\r*\n", timeout=timeout)
        vm.expect_exact(end, timeout=timeout)
        return ansi.sub("", vm.before).strip()

    try:
        # 1-2: boot to the installer, logging in as root if a getty is in the way
        t_boot = time.time()
        STAGE[0] = "booting to the installer prompt"
        while True:
            i = vm.expect([r"login: ?", r"[Pp]assword: ?",
                           r"Enter your email address", r"Kernel panic.*"],
                          timeout=a.boot_timeout)
            if i == 0:
                vm.sendline("root")
            elif i == 1:
                vm.sendline("")
            elif i == 2:
                break
            else:
                vm.expect([pexpect.TIMEOUT, pexpect.EOF], timeout=5)
                fail("kernel panic during boot", ansi.sub("", vm.after + (vm.before or ""))[-1500:])
        print(f"reached installer after {time.time() - t_boot:.0f}s")
        STAGE[0] = "answering the installer prompts"
        vm.sendline(EMAIL)
        vm.expect(r"\(y/n\)")
        vm.sendline("y")

        # 3: installer finishes and logs us in as bandit1
        STAGE[0] = "waiting for the installer to log in as bandit1"
        # Fail fast if the installer dies (shell error or its own ERROR:/die
        # message) instead of waiting out the timeout for a banner that won't come.
        i = vm.expect([re.escape(fl["banner"]),
                       r"install\.sh: line \d+: [^\r\n]+",
                       r"ERROR: [^\r\n]+"], timeout=600)
        if i:
            fail(f"installer error: {vm.after.strip()}")
        vm.expect(r"Level\s*:\s*bandit1\b")
        print("installer completed; logged in as bandit1")
        time.sleep(2)

        STAGE[0] = "checking bandit1"
        who = run("whoami")
        if who != "bandit1":
            fail(f"expected to be bandit1, got {who!r}")

        # 4: level 1 answer matches what the generator should have written
        guest_date = run(fl["date_cmd"])
        flag = run("cat inhere.txt")
        expected = expected_answer(a.flavor, EMAIL, guest_date, 1)
        if flag != expected:
            fail(f"bandit1 answer mismatch: got {flag!r}, expected {expected!r} "
                 f"(date {guest_date})")
        print(f"bandit1 answer OK ({flag})")
        if a.flavor == "v31":
            code = format(int(guest_date.replace("-", "")), "X")
            if f"Exercise code: {code}" not in run("cat README.txt"):
                fail(f"README.txt does not show exercise code {code} for {guest_date}")
            print(f"exercise code OK ({code})")

        # 5: walk the levels with nextlevel
        for n in range(2, a.levels + 1):
            STAGE[0] = f"moving to bandit{n} with nextlevel"
            level = rf"Level\s*:\s*bandit{n}\b"
            su_error = r"su: [^\r\n]+"
            preparing = r"is still being prepared"
            broken = r"could not be prepared[^\r\n]*"
            deadline = time.time() + a.level_ready_timeout
            while True:
                vm.sendline("nextlevel")
                # su may prompt for the (empty) password depending on PAM/shadow setup
                i = vm.expect([r"[Pp]assword: ?", level, su_error, preparing, broken], timeout=60)
                if i == 0:
                    vm.sendline("")
                    i = vm.expect([level, su_error], timeout=60) + 1
                if i == 1:
                    break
                if i == 2:
                    fail(f"nextlevel failed: {vm.after.strip()}")
                if i == 4:
                    fail(f"bandit{n} {vm.after.strip()}")
                if time.time() > deadline:
                    fail(f"bandit{n} was still being prepared after {a.level_ready_timeout}s")
                time.sleep(3)   # i == 3: level not ready yet; try again
            readme = run("cat README.txt")
            if fl["readme_marker"] not in readme:
                fail(f"bandit{n} README.txt is missing {fl['readme_marker']!r}")
            print(f"bandit{n} OK")
        vm.sendline("nextlevel")  # past the last level: should just refuse
        time.sleep(1)
        print("boot test passed")
    except pexpect.TIMEOUT:
        tail = ansi.sub("", vm.before or "")[-1500:]
        fail("timed out (full console in the boot-log artifact)", tail)
    except pexpect.EOF:
        fail("VM exited unexpectedly (see the boot-log artifact)", ansi.sub("", vm.before or "")[-1500:])
    finally:
        vm.terminate(force=True)
        log.close()


if __name__ == "__main__":
    main()
