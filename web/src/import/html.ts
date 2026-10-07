import { normalize, section } from "../core/text";
import type { Section } from "../core/types";

const blocks = new Set([
  "P",
  "DIV",
  "SECTION",
  "ARTICLE",
  "LI",
  "BR",
  "H1",
  "H2",
  "H3",
  "H4",
  "H5",
  "H6",
  "BLOCKQUOTE",
  "TR",
  "PRE",
]);
export function cleanHTML(document: Document) {
  document
    .querySelectorAll(
      'script,style,nav,noscript,iframe,svg,form,button,#pg-header,#pg-footer,.pg-boilerplate,[hidden],[aria-hidden="true"]',
    )
    .forEach((el) => el.remove());
}
export function htmlText(root: Node): string {
  let output = "";
  const visit = (node: Node) => {
    if (node.nodeType === 3) {
      output += node.textContent ?? "";
      return;
    }
    const tag = (node as Element).tagName;
    if (blocks.has(tag)) output += "\n";
    node.childNodes.forEach(visit);
    if (blocks.has(tag)) output += "\n";
    if (tag === "TD" || tag === "TH") output += " ";
  };
  visit(root);
  return normalize(output);
}
export function parseHTML(html: string) {
  return new DOMParser().parseFromString(html, "text/html");
}
export function articleText(document: Document) {
  cleanHTML(document);
  const root =
    document.querySelector(
      '#mw-content-text .mw-parser-output, article, [role="main"], main',
    ) ?? document.body;
  root
    .querySelectorAll(
      "header,footer,aside,.navbox,.metadata,.mw-editsection,.sidebar,.toc,.vertical-navbox,.hatnote,.reference",
    )
    .forEach((el) => el.remove());
  return htmlText(root);
}
export function epubSections(
  html: string,
  fallbackTitle: string,
  entries: { fragment?: string; title: string }[],
): Section[] {
  const document = parseHTML(html);
  cleanHTML(document);
  const titles = new Map(
    entries.filter((e) => e.fragment).map((e) => [e.fragment!, e.title]),
  );
  let title =
    entries.find((e) => !e.fragment)?.title ??
    document.title.trim() ??
    fallbackTitle;
  if (!title) title = fallbackTitle;
  let output = "";
  const result: Section[] = [];
  const flush = () => {
    const value = section(title, output);
    if (value.wordCount > 0) result.push(value);
    output = "";
  };
  const visit = (node: Node) => {
    if (node.nodeType === 3) {
      output += node.textContent ?? "";
      return;
    }
    const element = node as Element;
    if (titles.has(element.id)) {
      flush();
      title = titles.get(element.id)!;
    }
    if (blocks.has(element.tagName)) output += "\n";
    node.childNodes.forEach(visit);
    if (blocks.has(element.tagName)) output += "\n";
    if (element.tagName === "TD") output += " ";
  };
  visit(document.body);
  flush();
  return result;
}
