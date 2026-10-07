import { describe, it, expect } from "vitest";
import JSZip from "jszip";
import { importFile, importText } from "../src/import";
import { rtfText } from "../src/import/rtf";
import { importEPUB } from "../src/import/epub";

describe("file imports", () => {
  it("uses the first pasted line as a title", () =>
    expect(importText("# My title\nSome content").title).toBe("My title"));
  it("extracts article text without navigation or executable HTML", async () => {
    const file = new File(
      [
        "<title>Real title</title><nav>Navigation noise</nav><main><h1>Heading</h1><p>Readable body.</p><script>alert(1)</script></main>",
      ],
      "article.html",
    );
    file.arrayBuffer = async () =>
      new TextEncoder().encode(
        await new Response(
          "<title>Real title</title><nav>Navigation noise</nav><main><h1>Heading</h1><p>Readable body.</p><script>alert(1)</script></main>",
        ).text(),
      ).buffer;
    const doc = await importFile(file);
    expect(doc.title).toBe("Real title");
    expect(doc.sections[0].text).toContain("Readable body.");
    expect(doc.sections[0].text).not.toContain("Navigation");
    expect(doc.sections[0].text).not.toContain("alert");
  });
  it("extracts RTF Unicode, escaped text and hides formatting tables", () => {
    expect(
      rtfText(
        "{\\rtf1{\\fonttbl{\\f0 Hidden font;}}Hello \\u233? world\\par Next \\'e9.}",
      ),
    ).toBe("Hello é world\nNext é.");
  });
  it("uses EPUB navigation fragments and skips nonlinear boilerplate", async () => {
    const zip = new JSZip();
    zip.file(
      "META-INF/container.xml",
      '<container><rootfiles><rootfile full-path="OPS/book.opf"/></rootfiles></container>',
    );
    zip.file(
      "OPS/book.opf",
      '<package xmlns:dc="http://purl.org/dc/elements/1.1/"><metadata><dc:title>Fixture book</dc:title><dc:creator>Author</dc:creator></metadata><manifest><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/><item id="body" href="body.xhtml" media-type="application/xhtml+xml"/><item id="skip" href="skip.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="body"/><itemref idref="skip" linear="no"/></spine></package>',
    );
    zip.file(
      "OPS/nav.xhtml",
      '<nav epub:type="toc"><ol><li><a href="body.xhtml#one">First chapter</a></li><li><a href="body.xhtml#two">Second chapter</a></li></ol></nav>',
    );
    zip.file(
      "OPS/body.xhtml",
      '<body><div id="pg-header">Gutenberg boilerplate</div><h2 id="one">One</h2><p>First body.</p><h2 id="two">Two</h2><p>Second body.</p></body>',
    );
    zip.file("OPS/skip.xhtml", "<p>Should not appear</p>");
    const data = await zip.generateAsync({ type: "uint8array" });
    const file = new File([data.buffer as ArrayBuffer], "book.epub");
    // JSZip accepts Uint8Array in both Node and browsers.
    const doc = await importEPUB(
      Object.assign(data, { name: file.name }) as unknown as File,
    );
    expect(doc.title).toBe("Fixture book");
    expect(doc.author).toBe("Author");
    expect(doc.sections.map((s) => s.title)).toEqual([
      "First chapter",
      "Second chapter",
    ]);
    expect(doc.sections[0].text).not.toContain("Gutenberg");
    expect(doc.sections[1].text).not.toContain("Should not appear");
  });
});
