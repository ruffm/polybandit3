// Play the assembled PolyBandit site in headless Chrome like a student:
// page loads, v86 boots, auto-login reaches the installer, an email (typed
// with a real Shift+2 for "@") is accepted, bandit1's README appears, and
// nextlevel reaches bandit2. Works for both PolyBandit 3 and 3.1 (3.1's
// nextlevel may answer "still being prepared" at first; that is retried).
// Usage: node page-test.mjs <url> [screenshot-dir]
import puppeteer from "puppeteer-core";
import fs from "node:fs";

const url = process.argv[2];
const shots = process.argv[3] || ".";
fs.mkdirSync(shots, { recursive: true });
const chrome = process.env.CHROME_PATH || "/usr/bin/google-chrome";

const browser = await puppeteer.launch({
  executablePath: chrome,
  headless: true,
  args: ["--no-sandbox", "--disable-dev-shm-usage"],
});
const page = await browser.newPage();
await page.setViewport({ width: 1100, height: 760 });
const errors = [];
page.on("pageerror", e => errors.push(String(e)));

const t0 = Date.now();
const secs = () => `${((Date.now() - t0) / 1000).toFixed(0)}s`;
const screenText = () => page.$eval("#screen_container > div", el => el.innerText);
async function waitFor(re, ms, what) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    if (re.test(await screenText())) return;
    await new Promise(r => setTimeout(r, 1000));
  }
  throw new Error(`timed out waiting for ${what}`);
}
async function typeText(text) {
  for (const ch of text) {
    if (ch === "@") {   // puppeteer sends "@" without Shift; press it for real
      await page.keyboard.down("Shift");
      await page.keyboard.press("Digit2");
      await page.keyboard.up("Shift");
    } else if (ch === "\n") {
      await page.keyboard.press("Enter");
    } else {
      await page.keyboard.type(ch);
    }
    await new Promise(r => setTimeout(r, 25));
  }
}

let ok = false;
try {
  await page.goto(url, { waitUntil: "load" });
  await waitFor(/Enter your email/, 240000, "the installer prompt (boot + auto-login)");
  console.log(`installer prompt on screen after ${secs()}`);
  await page.click("#screen_container");
  await typeText("ci-page@psu.edu\n");
  await waitFor(/ci-page@psu\.edu.*\(y\/n\)/, 30000, "the email confirmation");
  await typeText("y\n");
  await waitFor(/Level\s*:\s*bandit1\b/, 300000, "bandit1's README (Level: bandit1)");
  console.log(`bandit1 banner after ${secs()}`);
  await new Promise(r => setTimeout(r, 1500));
  await page.screenshot({ path: `${shots}/bandit1.png` });
  const until = Date.now() + 240000;
  for (;;) {
    await typeText("nextlevel\n");
    // Wait for one of the two outcomes before deciding, so a slow su can't
    // make us type nextlevel twice and skip past bandit2.
    await waitFor(/Level\s*:\s*bandit2\b|still being prepared/, 60000, "nextlevel to answer");
    if (/Level\s*:\s*bandit2\b/.test(await screenText())) break;
    if (Date.now() > until) throw new Error("bandit2 was still being prepared after 240s");
    // 3.1: level not ready yet. Clear the message (and let clear finish before
    // typing again, or keystrokes get split), then retry.
    await new Promise(r => setTimeout(r, 3000));
    await typeText("clear\n");
    await new Promise(r => setTimeout(r, 1500));
  }
  console.log(`nextlevel reached bandit2 after ${secs()}`);
  ok = errors.length === 0;
  if (!ok) console.log(`::error::page test: JavaScript errors on the page: ${errors.join(" | ")}`);
} catch (e) {
  console.log("::group::Screen at failure");
  console.log(await screenText().catch(() => "(no screen)"));
  console.log("::endgroup::");
  console.log(`::error::page test failed: ${e.message}`);
} finally {
  await page.screenshot({ path: `${shots}/final.png` }).catch(() => {});
  await browser.close();
}
console.log(ok ? "page test passed" : "page test FAILED");
process.exit(ok ? 0 : 1);
