import JSZip from "jszip";
import { epubSections, parseHTML } from "./html";
import type { ImportedDocument } from "../core/types";
import { validateZip } from "./zip";

const directory = (path: string) => path.slice(0, path.lastIndexOf("/") + 1);
export function resolvePath(base: string, href: string) {
  const decoded = decodeURIComponent(href.split("#")[0]);
  const parts: string[] = [];
  for (const part of `${base}${decoded}`.split("/")) {
    if (part === "..") parts.pop();
    else if (part !== "." && part) parts.push(part);
  }
  return parts.join("/");
}
function xml(text: string) {
  const doc = new DOMParser().parseFromString(text, "application/xml");
  if (doc.querySelector("parsererror"))
    throw new Error("This document has invalid XML and could not be imported.");
  return doc;
}
const elements = (doc: Document | Element, name: string) =>
  Array.from(doc.getElementsByTagNameNS("*", name));
async function read(zip: JSZip, path: string) {
  const file = zip.file(path);
  if (!file) throw new Error(`The document is missing ${path}.`);
  const value = await file.async("string");
  if (value.length > 30_000_000)
    throw new Error("A document section is too large to import.");
  return value;
}
export async function importEPUB(file: File): Promise<ImportedDocument> {
  const zip = await JSZip.loadAsync(file);
  validateZip(zip);
  const container = xml(await read(zip, "META-INF/container.xml"));
  const opfPath = elements(container, "rootfile")[0]?.getAttribute("full-path");
  if (!opfPath) throw new Error("This EPUB is missing its package file.");
  const opf = xml(await read(zip, opfPath));
  const base = directory(opfPath);
  const manifest = new Map(
    elements(opf, "item").map((el) => [
      el.getAttribute("id")!,
      {
        href: el.getAttribute("href") ?? "",
        type: el.getAttribute("media-type") ?? "",
        properties: (el.getAttribute("properties") ?? "").split(/\s+/),
      },
    ]),
  );
  const title =
    elements(opf, "title")[0]?.textContent?.trim() ||
    file.name.replace(/\.epub$/i, "");
  const author = elements(opf, "creator")[0]?.textContent?.trim() || undefined;
  let entries: { path: string; fragment?: string; title: string }[] = [];
  const nav = [...manifest.values()].find((m) => m.properties.includes("nav"));
  const ncx = [...manifest.values()].find(
    (m) => m.type === "application/x-dtbncx+xml",
  );
  for (const item of [nav, ncx]) {
    if (!item) continue;
    const path = resolvePath(base, item.href);
    const source = await read(zip, path);
    let links: { href: string; title: string }[] = [];
    if (item === nav) {
      const doc = parseHTML(source);
      const toc =
        [...doc.querySelectorAll("nav")].find(
          (n) =>
            (n.getAttribute("epub:type") ?? "").split(/\s+/).includes("toc") ||
            n.getAttribute("role") === "doc-toc",
        ) ?? doc.querySelector("nav");
      links = [...(toc?.querySelectorAll("a[href]") ?? [])].map((a) => ({
        href: a.getAttribute("href")!,
        title: a.textContent?.trim() ?? "",
      }));
    } else {
      const doc = xml(source);
      links = elements(doc, "navPoint").map((p) => ({
        href: elements(p, "content")[0]?.getAttribute("src") ?? "",
        title: elements(p, "navLabel")[0]?.textContent?.trim() ?? "",
      }));
    }
    entries = links
      .filter((l) => l.title && l.href)
      .map((l) => {
        const [target, fragment] = l.href.split("#");
        return {
          title: l.title,
          path: target ? resolvePath(directory(path), target) : path,
          fragment: fragment ? decodeURIComponent(fragment) : undefined,
        };
      });
    if (entries.length) break;
  }
  const sections: ImportedDocument["sections"] = [];
  for (const ref of elements(opf, "itemref")) {
    if (ref.getAttribute("linear") === "no") continue;
    const item = manifest.get(ref.getAttribute("idref") ?? "");
    if (!item || !/html/.test(item.type)) continue;
    const path = resolvePath(base, item.href);
    const html = await read(zip, path);
    sections.push(
      ...epubSections(
        html,
        `Section ${sections.length + 1}`,
        entries.filter((e) => e.path === path),
      ),
    );
  }
  let cover: string | undefined;
  const coverID = elements(opf, "meta")
    .find((e) => e.getAttribute("name") === "cover")
    ?.getAttribute("content");
  const image =
    (coverID ? manifest.get(coverID) : undefined) ??
    [...manifest.values()].find((m) => m.properties.includes("cover-image")) ??
    [...manifest.values()].find(
      (m) => /^image\//.test(m.type) && /cover/i.test(m.href),
    );
  if (image && /^(image\/)(png|jpeg|webp|gif)$/.test(image.type)) {
    const entry = zip.file(resolvePath(base, image.href));
    if (entry) {
      const data = await entry.async("base64");
      if (data.length < 15_000_000) cover = `data:${image.type};base64,${data}`;
    }
  }
  return {
    title,
    author,
    sourceName: file.name,
    format: "epub",
    sections,
    cover,
  };
}
