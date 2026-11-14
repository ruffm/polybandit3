// Play the assembled PolyBandit site in headless Chrome like a student:
// page loads, v86 boots, auto-login reaches the installer, an email (typed
// with a real Shift+2 for "@") is accepted, bandit1's banner appears, and
// nextlevel reaches bandit2.
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
  await waitFor(/ci-page@psu\.edu your email address\? \(y\/n\)/, 30000, "the email confirmation");
  await typeText("y\n");
  await waitFor(/Welcome to The PolyLinux Game/, 300000, "the bandit1 banner");
  await waitFor(/Level\s*:\s*bandit1/, 10000, "Level: bandit1");
  console.log(`bandit1 banner after ${secs()}`);
  await new Promise(r => setTimeout(r, 1500));
  await page.screenshot({ path: `${shots}/bandit1.png` });
  await typeText("nextlevel\n");
  await waitFor(/Level\s*:\s*bandit2/, 60000, "nextlevel to reach bandit2");
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
