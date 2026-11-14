#!/usr/bin/env python3
"""Boot a packaged PolyBandit image in QEMU and play it like a student.

  1. the kernel boots and reaches a login
  2. runs install.sh -> which asks for an email and confirmation
  3. the installer drops into bandit1 with the PolyLinux welcome banner
  4. bandit1's flag (inhere.txt) matches the value derived from the email,
     guest date and the installer's level password scheme
  5. `nextlevel` walks through every level up to the last one

"""
import argparse, base64, hashlib, re, shlex, sys, time
import pexpect

EMAIL = "ci-test@psu.edu"
SYSTEM_PASSWORD = "systemPassword"      # from installbandit.sh
LEVEL_PASSWORD_ROOT = "levelPassword"   # from installbandit.sh


def fail(msg):
    print(f"::error::boot test: {msg}")
    sys.exit(1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kernel")
    ap.add_argument("--initrd")
    ap.add_argument("--levels", type=int, default=13)
    ap.add_argument("--log", default="boot.log")
    ap.add_argument("--kvm", action="store_true")
    ap.add_argument("--boot-timeout", type=int, default=300)
    ap.add_argument("--cmd", help="override the spawned command (for self-testing)")
    a = ap.parse_args()

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

    print(f"spawning: {cmd}")
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
        vm.expect_exact(start + "\r\n", timeout=timeout)
        vm.expect_exact(end, timeout=timeout)
        return ansi.sub("", vm.before).strip()

    try:
        # 1-2: boot to the installer, logging in as root if a getty is in the way
        t_boot = time.time()
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
                fail("kernel panic during boot (see boot log)")
        print(f"reached installer after {time.time() - t_boot:.0f}s")
        vm.sendline(EMAIL)
        vm.expect(r"\(y/n\)")
        vm.sendline("y")

        # 3: installer finishes and logs us in as bandit1
        vm.expect_exact("Welcome to The PolyLinux Game", timeout=600)
        vm.expect(r"Level\s*:\s*bandit1")
        print("installer completed; logged in as bandit1")
        time.sleep(2)

        who = run("whoami")
        if who != "bandit1":
            fail(f"expected to be bandit1, got {who!r}")

        # 4: level 1 flag matches what the generator should have written
        guest_date = run('date +"%m-%d-%Y"')
        flag = run("cat inhere.txt")
        level_hash = hashlib.sha256(
            f"{EMAIL}{guest_date}{SYSTEM_PASSWORD}{LEVEL_PASSWORD_ROOT}1".encode()
        ).hexdigest()
        expected = base64.b64encode((level_hash + "\n").encode()).decode()[:20]
        if flag != expected:
            fail(f"bandit1 flag mismatch: got {flag!r}, expected {expected!r} "
                 f"(date {guest_date})")
        print(f"bandit1 flag OK ({flag})")

        # 5: walk the levels with nextlevel
        for n in range(2, a.levels + 1):
            vm.sendline("nextlevel")
            # su may prompt for the (empty) password depending on PAM/shadow setup
            if vm.expect([r"[Pp]assword: ?", rf"Level\s*:\s*bandit{n}\b"], timeout=60) == 0:
                vm.sendline("")
                vm.expect(rf"Level\s*:\s*bandit{n}\b", timeout=60)
            readme = run("cat README.txt")
            if "Instructions for this level" not in readme:
                fail(f"bandit{n} README.txt is missing its instructions header")
            print(f"bandit{n} OK")
        vm.sendline("nextlevel")  # past the last level: su should just fail
        time.sleep(1)
        print("boot test passed")
    except pexpect.TIMEOUT:
        tail = (vm.before or "")[-800:]
        fail(f"timed out; last console output:\n{tail}")
    except pexpect.EOF:
        fail("VM exited unexpectedly (see boot log)")
    finally:
        vm.terminate(force=True)
        log.close()


if __name__ == "__main__":
    main()
