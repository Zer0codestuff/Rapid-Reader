import { lookup } from "node:dns/promises";
import ipaddr from "ipaddr.js";
import { Agent, fetch } from "undici";
import { JSDOM, VirtualConsole } from "jsdom";
import { Readability } from "@mozilla/readability";

export function publicAddress(value) {
  try {
    let address = ipaddr.parse(value);
    if (address.kind() === "ipv6" && address.isIPv4MappedAddress())
      address = address.toIPv4Address();
    return address.range() === "unicast";
  } catch {
    return false;
  }
}
export function validateURL(value) {
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new Error("Enter a valid article URL.");
  }
  if (
    !["http:", "https:"].includes(url.protocol) ||
    url.username ||
    url.password ||
    (url.port && !["80", "443"].includes(url.port))
  )
    throw new Error("Use a public http or https article URL.");
  const host = url.hostname.replace(/^\[|\]$/g, "").toLowerCase();
  if (!host.includes(".") && !ipaddr.isValid(host))
    throw new Error("Use a public website URL.");
  if (
    /(^|\.)(localhost|local|internal|home|test|invalid)$/.test(host) ||
    (ipaddr.isValid(host) && !publicAddress(host))
  )
    throw new Error("Only public website URLs can be imported.");
  return url;
}
const blockTags = new Set([
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
function plainText(root) {
  let output = "";
  function visit(node) {
    if (node.nodeType === 3) {
      output += node.textContent ?? "";
      return;
    }
    if (blockTags.has(node.tagName)) output += "\n";
    node.childNodes.forEach(visit);
    if (blockTags.has(node.tagName)) output += "\n";
    if (node.tagName === "TD") output += " ";
  }
  visit(root);
  return output
    .replace(/\r\n?/g, "\n")
    .replace(/\u00a0/g, " ")
    .split("\n")
    .map((l) => l.trim())
    .join("\n")
    .replace(/[ \t]{2,}/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}
export function extractArticle(html, url) {
  const dom = new JSDOM(html, { url, virtualConsole: new VirtualConsole() });
  try {
    const document = dom.window.document;
    const originalTitle =
      document
        .querySelector('meta[property="og:title"]')
        ?.getAttribute("content") ||
      document.title ||
      new URL(url).hostname;
    document
      .querySelectorAll(
        "script,style,nav,noscript,iframe,form,button,svg,header,footer,aside,#pg-header,#pg-footer,.pg-boilerplate,[hidden]",
      )
      .forEach((e) => e.remove());
    const wiki = document.querySelector("#mw-content-text .mw-parser-output");
    if (wiki)
      wiki
        .querySelectorAll(
          ".navbox,.metadata,.mw-editsection,.sidebar,.toc,.vertical-navbox,.hatnote,.reference",
        )
        .forEach((e) => e.remove());
    let title = originalTitle,
      author;
    let root = wiki;
    if (!root) {
      const parsed = new Readability(document.cloneNode(true)).parse();
      if (parsed?.content) {
        const container = document.createElement("div");
        container.innerHTML = parsed.content;
        root = container;
        title = parsed.title || originalTitle;
        author = parsed.byline || undefined;
      }
    }
    root ??=
      document.querySelector('article,main,[role="main"]') ?? document.body;
    const text = plainText(root);
    if (!/[\p{L}\p{N}]/u.test(text))
      throw new Error(
        "This page has no readable article text. Try copying and pasting its text.",
      );
    return {
      title: title.trim().slice(0, 500),
      author: author?.slice(0, 500),
      text,
      url,
    };
  } finally {
    dom.window.close();
  }
}
export async function fetchArticle(value) {
  let url = validateURL(value);
  const signal = AbortSignal.timeout(15000);
  for (let redirect = 0; redirect <= 4; redirect++) {
    const hostname = url.hostname.replace(/^\[|\]$/g, "");
    const addresses = await lookup(hostname, { all: true });
    if (!addresses.length || addresses.some((a) => !publicAddress(a.address)))
      throw new Error("Only public website URLs can be imported.");
    // Pin the checked addresses to prevent DNS rebinding between lookup and fetch.
    const agent = new Agent({
      connect: {
        lookup: (_hostname, options, callback) => {
          const matches = addresses.filter(
            (a) => !options.family || a.family === options.family,
          );
          if (!matches.length)
            return callback(new Error("No public address found."));
          callback(
            null,
            options.all ? matches : matches[0].address,
            matches[0].family,
          );
        },
      },
    });
    try {
      const response = await fetch(url, {
        dispatcher: agent,
        signal,
        redirect: "manual",
        headers: {
          "User-Agent":
            "RapidReader/1.0 (+https://github.com/Zer0codestuff/Rapid-Reader)",
          Accept: "text/html,application/xhtml+xml,text/plain;q=0.9",
        },
      });
      if ([301, 302, 303, 307, 308].includes(response.status)) {
        const location = response.headers.get("location");
        await response.body?.cancel();
        if (!location || redirect === 4)
          throw new Error(
            "This website redirected too many times. Try its final article URL.",
          );
        url = validateURL(new URL(location, url).href);
        continue;
      }
      if (!response.ok) {
        await response.body?.cancel();
        throw new Error(
          `This website returned HTTP ${response.status}. Try copying and pasting the article text.`,
        );
      }
      const type = response.headers.get("content-type") ?? "";
      if (!/text\/(html|plain)|application\/xhtml\+xml/i.test(type)) {
        await response.body?.cancel();
        throw new Error(
          "This URL is not a web article. Download the document and import the file.",
        );
      }
      if (Number(response.headers.get("content-length")) > 5_000_000) {
        await response.body?.cancel();
        throw new Error("This article is too large. Try pasting its text.");
      }
      const chunks = [];
      let size = 0;
      for await (const chunk of response.body) {
        size += chunk.length;
        if (size > 5_000_000) {
          await response.body.cancel().catch(() => {});
          throw new Error("This article is too large. Try pasting its text.");
        }
        chunks.push(chunk);
      }
      const bytes = Buffer.concat(chunks);
      const charset =
        type.match(/charset\s*=\s*["']?([^\s;"']+)/i)?.[1] ?? "utf-8";
      let html;
      try {
        html = new TextDecoder(charset).decode(bytes);
      } catch {
        html = bytes.toString("utf8");
      }
      if (/text\/plain/i.test(type))
        return { title: url.hostname, text: html, url: url.href };
      return extractArticle(html, url.href);
    } finally {
      await agent.close();
    }
  }
  throw new Error("This article could not be imported.");
}
