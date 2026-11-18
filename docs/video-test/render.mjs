// Offline renderer: scene.html -> out.webm. Steps window.seek(t) per frame, screenshots, pipes to ffmpeg.
// Usage: node render.mjs [scene.html] [out.webm]
import { createRequire } from "node:module";
import { spawn } from "node:child_process";
import { pathToFileURL } from "node:url";
import { resolve, dirname } from "node:path";
import { homedir } from "node:os";
import { readdirSync } from "node:fs";

// shortcut: borrows playwright-core from a sibling project; give this folder its own pinned install before real use.
const { chromium } = createRequire(import.meta.url)(
  resolve(homedir(), "projects/scout/node_modules/playwright-core")
);
const cache = resolve(homedir(), "Library/Caches/ms-playwright");
const shellDir = readdirSync(cache).find((d) => d.startsWith("chromium_headless_shell"));
const ffDir = readdirSync(cache).find((d) => d.startsWith("ffmpeg"));
const chrome = resolve(cache, shellDir, "chrome-headless-shell-mac-arm64/chrome-headless-shell");
const ffmpegBin = resolve(cache, ffDir, "ffmpeg-mac");

const scene = resolve(process.argv[2] ?? "scene.html");
const out = resolve(process.argv[3] ?? "out.webm");
const FPS = 30, W = 1280, H = 720;

const browser = await chromium.launch({ executablePath: chrome }); // sandbox stays on
const context = await browser.newContext({ viewport: { width: W, height: H }, serviceWorkers: "block" });
const blocked = [];
// Only the scene file itself may load; anything else is recorded and refused.
await context.route("**/*", (route) => {
  const url = route.request().url();
  if (url === pathToFileURL(scene).href) return route.continue();
  blocked.push(url);
  return route.abort();
});
const page = await context.newPage();
await page.goto(pathToFileURL(scene).href);
const duration = await page.evaluate(() => window.DURATION);
const frames = Math.round(duration * FPS);

const mp4 = out.endsWith(".mp4");
const encode = mp4
  ? ["-c:v", "libx264", "-crf", "18", "-preset", "medium", "-pix_fmt", "yuv420p", "-movflags", "+faststart"]
  : ["-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "22", "-row-mt", "1", "-pix_fmt", "yuv420p"];
// .mp4 needs the full Homebrew ffmpeg; .webm works with Playwright's bundled VP9-only build.
const ff = spawn(mp4 ? "/opt/homebrew/bin/ffmpeg" : ffmpegBin, [
  "-y", "-loglevel", "error", "-f", "image2pipe", "-c:v", "mjpeg", "-framerate", String(FPS), "-i", "pipe:0",
  ...encode, out,
], { stdio: ["pipe", "ignore", "inherit"] });
const done = new Promise((ok, bad) => ff.on("close", (c) => (c === 0 ? ok() : bad(new Error("ffmpeg exit " + c)))));

for (let i = 0; i < frames; i++) {
  await page.evaluate((t) => window.seek(t), i / FPS);
  const buf = await page.screenshot({ type: "jpeg", quality: 95 });
  if (!ff.stdin.write(buf)) await new Promise((r) => ff.stdin.once("drain", r));
}
ff.stdin.end();
await done;
await browser.close();
console.log(`${frames} frames -> ${out}; blocked requests: ${blocked.length}`, blocked);
