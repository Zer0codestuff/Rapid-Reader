import { chromium, webkit } from "playwright";
import { spawn } from "node:child_process";
import { readFile, mkdir } from "node:fs/promises";
import path from "node:path";
import assert from "node:assert/strict";
import JSZip from "jszip";

const externalURL = process.env.RAPID_READER_QA_URL;
const baseURL = externalURL || "http://127.0.0.1:4174";
const engine =
  process.env.RAPID_READER_QA_BROWSER === "webkit" ? webkit : chromium;
const evidence = path.resolve("../build/web-qa");
await mkdir(evidence, { recursive: true });
const server = externalURL
  ? undefined
  : spawn(process.execPath, ["server/index.mjs"], {
      env: { ...process.env, PORT: "4174" },
      stdio: "pipe",
    });
let serverOutput = "";
server?.stderr.on("data", (data) => {
  serverOutput += data;
});
for (let i = 0; i < 100; i++) {
  try {
    if ((await fetch(`${baseURL}/api/health`)).ok) break;
  } catch {
    /* Wait for the isolated server. */
  }
  if (i === 99) throw new Error(`The QA server did not start. ${serverOutput}`);
  await new Promise((r) => setTimeout(r, 100));
}
const browser = await engine.launch();
const context = await browser.newContext({
  viewport: { width: 1280, height: 800 },
  colorScheme: "dark",
  acceptDownloads: true,
});
const page = await context.newPage();
const errors = [];
page.on("pageerror", (error) => errors.push(error.message));

async function epub(title, text, chapters = false) {
  const zip = new JSZip();
  zip.file(
    "META-INF/container.xml",
    '<container><rootfiles><rootfile full-path="book.opf"/></rootfiles></container>',
  );
  zip.file(
    "book.opf",
    `<package xmlns:dc="http://purl.org/dc/elements/1.1/"><metadata><dc:title>${title}</dc:title><dc:creator>Reader QA</dc:creator></metadata><manifest><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/><item id="cover" href="cover.png" media-type="image/png" properties="cover-image"/><item id="body" href="body.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="body"/></spine></package>`,
  );
  zip.file(
    "nav.xhtml",
    chapters
      ? '<nav epub:type="toc"><a href="body.xhtml#first">First chapter</a><a href="body.xhtml#second">Second chapter</a></nav>'
      : '<nav epub:type="toc"><a href="body.xhtml">Long chapter</a></nav>',
  );
  zip.file(
    "body.xhtml",
    `<html><body>${chapters ? `<h2 id="first">First chapter</h2><p>${text}</p><h2 id="second">Second chapter</h2><p>Another chapter with a different passage.</p>` : `<p>${text}</p>`}</body></html>`,
  );
  zip.file("cover.png", await readFile("public/icon.png"));
  return {
    name: `${title}.epub`,
    mimeType: "application/epub+zip",
    buffer: await zip.generateAsync({ type: "nodebuffer" }),
  };
}
function pdf() {
  const stream =
    "BT /F1 12 Tf 50 740 Td (Readable PDF text for validation.) Tj ET";
  const objects = [
    "<< /Type /Catalog /Pages 2 0 R /Outlines 6 0 R >>",
    "<< /Type /Pages /Count 1 /Kids [3 0 R] >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
    `<< /Length ${stream.length} >>\nstream\n${stream}\nendstream`,
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    "<< /Type /Outlines /First 7 0 R /Last 7 0 R /Count 1 >>",
    "<< /Title (PDF chapter) /Parent 6 0 R /Dest [3 0 R /Fit] >>",
  ];
  let source = "%PDF-1.4\n";
  const offsets = [0];
  objects.forEach((object, i) => {
    offsets.push(Buffer.byteLength(source));
    source += `${i + 1} 0 obj\n${object}\nendobj\n`;
  });
  const xref = Buffer.byteLength(source);
  source += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n${offsets
    .slice(1)
    .map((o) => `${String(o).padStart(10, "0")} 00000 n \n`)
    .join(
      "",
    )}trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`;
  return {
    name: "Readable.pdf",
    mimeType: "application/pdf",
    buffer: Buffer.from(source),
  };
}
const document = new JSZip();
document.file(
  "word/document.xml",
  '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Word document body.</w:t><w:br/><w:t>Second line.</w:t></w:r></w:p></w:body></w:document>',
);
const fixtures = [
  await epub(
    "Browser reading fixture",
    "A café is a quiet place to read. ".repeat(80),
    true,
  ),
  pdf(),
  {
    name: "Word.docx",
    mimeType:
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    buffer: await document.generateAsync({ type: "nodebuffer" }),
  },
  ...[
    [
      "Rich.rtf",
      "{\\rtf1\\ansi Rich text with caf\\u233?.\\par A second paragraph.}",
    ],
    [
      "Article.html",
      "<title>HTML fixture</title><nav>Noise</nav><article><p>Readable HTML prose without navigation.</p></article>",
    ],
    [
      "Markdown.md",
      "# First chapter\n\nMarkdown body.\n\n## Second chapter\n\nAnother paragraph.",
    ],
    ["Plain.txt", "Plain text body for browser validation."],
  ].map(([name, text]) => ({
    name,
    mimeType: "text/plain",
    buffer: Buffer.from(text),
  })),
];

try {
  await page.goto(baseURL);
  await page.getByRole("heading", { name: "A little more focus." }).waitFor();
  await page.locator("input[type=file]").first().setInputFiles(fixtures);
  await page
    .getByText("7 documents added to your library.", { exact: true })
    .waitFor();
  await page
    .locator(".book-button")
    .filter({ hasText: "Browser reading fixture" })
    .click();
  await page
    .getByRole("button", { name: "Search document", exact: true })
    .click();
  await page
    .getByRole("searchbox", { name: "Search in document" })
    .fill("cafe");
  await page.getByText("80 matches", { exact: true }).waitFor();
  await page.locator(".search-results button").first().click();
  assert.match(await page.locator(".rsvp-word").textContent(), /café/);
  await page.getByRole("button", { name: "Notes", exact: true }).click();
  await page.locator("#note-text").fill("Saved at café.");
  await page.getByRole("button", { name: "Add note", exact: true }).click();
  await page
    .locator(".note-actions")
    .getByRole("button", { name: "Edit", exact: true })
    .click();
  await page.locator("#note-text").fill("Edited note at café.");
  await page.getByRole("button", { name: "Save note", exact: true }).click();
  await page.getByRole("button", { name: "Done", exact: true }).click();
  await page
    .getByRole("button", { name: "Favorite document", exact: true })
    .click();
  await page
    .getByRole("button", { name: "Start reading", exact: true })
    .click();
  await page.mouse.move(700, 320);
  await page.waitForTimeout(3000);
  assert.equal(
    await page
      .locator(".controls-area")
      .evaluate((e) => getComputedStyle(e).opacity),
    "0",
  );
  await page.keyboard.press("Space");
  await page
    .locator(".reader-modes")
    .getByRole("button", { name: "Text", exact: true })
    .click();
  await page.locator(".full-text-body").waitFor();
  const point = await page.locator(".full-text-body").evaluate((root) => {
    const range = new Range();
    const start = root.textContent.indexOf("quiet");
    range.setStart(root.firstChild, start);
    range.setEnd(root.firstChild, start + 5);
    const bounds = range.getBoundingClientRect();
    return { x: bounds.x + bounds.width / 2, y: bounds.y + bounds.height / 2 };
  });
  await page.mouse.click(point.x, point.y);
  assert.deepEqual(
    await page.evaluate(() =>
      [...CSS.highlights.get("reader-current")].map((r) => r.toString()),
    ),
    ["quiet"],
  );
  await page
    .getByRole("button", { name: "Reading statistics", exact: true })
    .click();
  await page.waitForFunction(
    () =>
      Number(
        (
          document.querySelector(".stats-grid strong")?.textContent ?? "0"
        ).replaceAll(",", ""),
      ) > 0,
  );
  assert.ok(
    Number(
      (
        await page.locator(".stats-grid strong").first().textContent()
      ).replaceAll(",", ""),
    ) > 0,
  );
  await page.getByRole("button", { name: "Done", exact: true }).click();
  console.log(
    "PASS imports, chapter search, notes, favorite, timing, controls, text selection and statistics",
  );

  await page.getByRole("button", { name: "Settings", exact: true }).click();
  await page.getByRole("tab", { name: "Your library", exact: true }).click();
  const downloadPromise = page.waitForEvent("download");
  await page
    .getByRole("button", { name: "Export backup", exact: true })
    .click();
  const backup = await downloadPromise;
  const backupData = await readFile(await backup.path());
  const backupJSON = JSON.parse(backupData);
  assert.equal(backupJSON.books.length, 7);
  assert.ok(backupJSON.books.some((b) => b.notes.length === 1 && b.isFavorite));
  await page.getByRole("button", { name: "Done", exact: true }).click();
  await page
    .getByRole("button", { name: "More options for Plain", exact: true })
    .click();
  await page
    .getByRole("menuitem", { name: "Delete document", exact: true })
    .click();
  await page.getByRole("button", { name: "Cancel", exact: true }).click();
  assert.equal(await page.locator(".book-button").count(), 7);
  await page
    .getByRole("button", { name: "More options for Plain", exact: true })
    .click();
  await page
    .getByRole("menuitem", { name: "Delete document", exact: true })
    .click();
  await page.getByRole("button", { name: "Delete", exact: true }).click();
  await page.getByText("Document deleted.", { exact: true }).waitFor();
  await page.getByRole("button", { name: "Settings", exact: true }).click();
  await page.getByRole("tab", { name: "Your library", exact: true }).click();
  await page
    .locator("dialog input[type=file]")
    .setInputFiles({
      name: "backup.json",
      mimeType: "application/json",
      buffer: backupData,
    });
  await page
    .getByText("Backup restored. Existing documents and progress were kept.", {
      exact: true,
    })
    .waitFor();
  await page.getByRole("button", { name: "Done", exact: true }).click();
  assert.equal(await page.locator(".book-button").count(), 7);
  console.log("PASS backup download, cancellation, deletion and restore");

  await page
    .locator(".reader-modes")
    .getByRole("button", { name: "RSVP", exact: true })
    .click();
  await page
    .locator("input[type=file]")
    .first()
    .setInputFiles(
      await epub(
        "Long chapter validation",
        "A quiet reader keeps every word in place. ".repeat(3500),
      ),
    );
  await page
    .getByRole("heading", { name: "Long chapter validation", exact: true })
    .waitFor();
  const timing = await page.evaluate(
    () =>
      new Promise((resolve) => {
        const start = performance.now();
        const observer = new MutationObserver(() => {
          const text = document.querySelector(".full-text-body");
          if (text) {
            observer.disconnect();
            resolve({
              milliseconds: performance.now() - start,
              elements: text.querySelectorAll("*").length,
              characters: text.textContent.length,
            });
          }
        });
        observer.observe(document.querySelector(".reader"), {
          childList: true,
          subtree: true,
        });
        document.querySelector(".reader-modes button:last-child").click();
      }),
  );
  assert.equal(timing.elements, 0);
  assert.equal(timing.characters, 146999);
  console.log(
    `PASS 28,000-word text render: ${timing.milliseconds.toFixed(2)} ms, ${timing.elements} word elements`,
  );
  await page
    .locator(".reader-modes")
    .getByRole("button", { name: "RSVP", exact: true })
    .click();
  await page
    .getByRole("button", { name: "Reading options", exact: true })
    .click();
  await page.getByRole("button", { name: "Sepia", exact: true }).click();
  await page.getByRole("button", { name: "Done", exact: true }).click();
  await page.setViewportSize({ width: 390, height: 844 });
  await page.waitForTimeout(300);
  assert.equal(
    await page.evaluate(
      () => document.documentElement.scrollWidth > innerWidth,
    ),
    false,
  );
  await page.screenshot({
    path: path.join(evidence, `${engine.name()}-mobile.png`),
  });
  await page.getByRole("button", { name: "Show library", exact: true }).click();
  await page.waitForTimeout(300);
  assert.equal(
    await page
      .locator(".sidebar")
      .evaluate((e) => getComputedStyle(e).visibility),
    "visible",
  );
  await page.getByRole("button", { name: "Hide library", exact: true }).click();
  await page.setViewportSize({ width: 740, height: 560 });
  assert.equal(
    await page.evaluate(
      () => document.documentElement.scrollWidth > innerWidth,
    ),
    false,
  );
  await page.setViewportSize({ width: 1280, height: 800 });
  await page
    .getByRole("button", { name: "Reading options", exact: true })
    .click();
  await page.getByRole("button", { name: "Light", exact: true }).click();
  await page.getByRole("button", { name: "Done", exact: true }).click();
  await page.screenshot({
    path: path.join(evidence, `${engine.name()}-light.png`),
  });
  await page
    .getByRole("button", { name: "Reading options", exact: true })
    .click();
  await page.getByRole("button", { name: "Dark", exact: true }).click();
  await page.getByRole("button", { name: "Done", exact: true }).click();
  await page.screenshot({
    path: path.join(evidence, `${engine.name()}-desktop.png`),
  });
  console.log("PASS mobile, small viewport, drawer, Light, Dark and Sepia");

  await page.evaluate(async () => {
    await navigator.serviceWorker.ready;
    window.__qaBeforeReload = true;
  });
  if (engine === webkit && !server) {
    console.log(
      "SKIP external WebKit offline navigation: Playwright offline emulation blocks its service worker",
    );
  } else {
    if (engine === webkit) {
      // WebKit offline emulation fails before the service worker runs. Stop the
      // isolated server instead, so the real network failure exercises its cache.
      const stopped = new Promise((resolve) => server.once("exit", resolve));
      server.kill("SIGTERM");
      await stopped;
    } else await context.setOffline(true);
    await page.reload();
    await page
      .getByRole("heading", { name: "Long chapter validation", exact: true })
      .waitFor();
    assert.equal(await page.evaluate(() => window.__qaBeforeReload), undefined);
    if (engine !== webkit) {
      assert.equal(await page.evaluate(() => navigator.onLine), false);
      await page
        .getByText("Offline. Your saved library is available.", { exact: true })
        .waitFor();
    }
    await page
      .locator("input[type=file]")
      .first()
      .setInputFiles({
        name: "Offline.txt",
        mimeType: "text/plain",
        buffer: Buffer.from("A document imported while completely offline."),
      });
    await page.getByRole("heading", { name: "Offline", exact: true }).waitFor();
    console.log(
      `PASS ${engine === webkit ? "server stopped" : "offline"} reload, persisted library and local file import`,
    );
  }
  assert.deepEqual(errors, []);
  console.log(`PASS ${engine.name()} browser QA, no uncaught errors`);
} finally {
  await context.close();
  await browser.close();
  server?.kill("SIGTERM");
}
