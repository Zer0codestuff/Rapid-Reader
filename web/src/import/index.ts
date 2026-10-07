import JSZip from "jszip";
import { normalize, splitSections } from "../core/text";
import type { ImportedDocument } from "../core/types";
import { articleText, parseHTML } from "./html";
import { importEPUB } from "./epub";
import { rtfText } from "./rtf";
import { validateZip } from "./zip";

export const supportedFiles =
  ".epub,.pdf,.docx,.rtf,.html,.htm,.xhtml,.md,.markdown,.txt,.text";
export function importText(text: string, title?: string): ImportedDocument {
  const body = normalize(text);
  const name =
    title?.trim() ||
    body
      .split("\n")[0]
      .replace(/^#{1,6}\s*/, "")
      .slice(0, 80) ||
    "Pasted text";
  return {
    title: name,
    sourceName: "Clipboard",
    format: "plainText",
    sections: splitSections(body, name),
  };
}
export async function importFile(
  file: File,
  progress?: (message: string) => void,
): Promise<ImportedDocument> {
  if (file.size > 100 * 1024 * 1024)
    throw new Error("Choose a file smaller than 100 MB.");
  const ext = file.name.split(".").at(-1)?.toLowerCase();
  const title = file.name.replace(/\.[^.]+$/, "");
  progress?.(`Reading ${file.name}...`);
  if (ext === "epub") return importEPUB(file);
  if (ext === "pdf") {
    const { importPDF } = await import("./pdf");
    return importPDF(file, progress);
  }
  if (ext === "docx") {
    const zip = await JSZip.loadAsync(file);
    validateZip(zip);
    const source = await zip.file("word/document.xml")?.async("string");
    if (!source) throw new Error("This Word document is missing its text.");
    const doc = new DOMParser().parseFromString(source, "application/xml");
    if (doc.querySelector("parsererror"))
      throw new Error("This Word document could not be read.");
    const paragraphText = (node: Node): string => {
      if (node.nodeType !== 1) return "";
      const element = node as Element;
      if (element.localName === "t") return element.textContent ?? "";
      if (element.localName === "tab") return " ";
      if (element.localName === "br" || element.localName === "cr") return "\n";
      return [...element.childNodes].map(paragraphText).join("");
    };
    const text = [...doc.getElementsByTagNameNS("*", "p")]
      .map(paragraphText)
      .join("\n\n");
    return {
      title,
      sourceName: file.name,
      format: "docx",
      sections: splitSections(text, title),
    };
  }
  const bytes = new Uint8Array(await file.arrayBuffer());
  let text = new TextDecoder().decode(bytes);
  if (text.includes("\ufffd"))
    text = new TextDecoder("windows-1252").decode(bytes);
  if (ext === "rtf")
    return {
      title,
      sourceName: file.name,
      format: "rtf",
      sections: splitSections(rtfText(text), title),
    };
  if (["html", "htm", "xhtml"].includes(ext ?? "")) {
    const doc = parseHTML(text);
    const name = doc.title.trim() || title;
    return {
      title: name,
      sourceName: file.name,
      format: "html",
      sections: splitSections(articleText(doc), name),
    };
  }
  if (!["txt", "text", "md", "markdown"].includes(ext ?? ""))
    throw new Error(
      `The .${ext ?? ""} format is not supported. Choose EPUB, PDF, Word, RTF, HTML, Markdown or plain text.`,
    );
  return {
    title,
    sourceName: file.name,
    format: ext === "md" || ext === "markdown" ? "markdown" : "plainText",
    sections: splitSections(text, title),
  };
}
export async function importArticle(
  value: string,
  signal?: AbortSignal,
): Promise<ImportedDocument> {
  if (!navigator.onLine)
    throw new Error(
      "Article import needs an internet connection. You can still import files or paste text offline.",
    );
  let url: URL;
  try {
    url = new URL(value.includes("://") ? value : `https://${value}`);
  } catch {
    throw new Error("Enter a valid article URL.");
  }
  if (!["http:", "https:"].includes(url.protocol))
    throw new Error("Use an http or https URL.");
  const response = await fetch("/api/article", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ url: url.href }),
    signal,
  });
  const data = await response.json();
  if (!response.ok)
    throw new Error(
      data.error ?? "This article could not be imported. Try pasting its text.",
    );
  return {
    title: data.title,
    author: data.author,
    sourceName: url.hostname,
    sourceURL: data.url,
    format: "webArticle",
    sections: splitSections(data.text, data.title),
  };
}
