import { section, normalize } from "../core/text";
import type { ImportedDocument } from "../core/types";
import { getDocument, GlobalWorkerOptions } from "pdfjs-dist";
import workerURL from "pdfjs-dist/build/pdf.worker.min.mjs?url";

GlobalWorkerOptions.workerSrc = workerURL;
export function cleanPDFPages(pages: string[]): string[] {
  const lines = pages.map((p) =>
    p
      .split("\n")
      .map((l) => l.trim())
      .filter(Boolean),
  );
  const counts = new Map<string, number>();
  lines.forEach((page) => {
    for (const line of new Set([page[0], page.at(-1)]))
      if (line && line.length <= 100)
        counts.set(line, (counts.get(line) ?? 0) + 1);
  });
  const threshold = Math.max(3, Math.ceil(pages.length * 0.7));
  const margin = (line: string) =>
    (counts.get(line) ?? 0) >= threshold ||
    /^(?:Page\s+)?\d+(?:\s+(?:of|\/)\s*\d+)?$/i.test(line);
  return lines.map((page) => {
    const clean = [...page];
    if (clean.length && margin(clean[0])) clean.shift();
    if (clean.length && margin(clean.at(-1)!)) clean.pop();
    return normalize(
      clean
        .join("\n")
        .replace(/\u00ad\n/g, "")
        .replace(/\u00ad/g, "")
        .replace(/(\p{Ll})-\n(?=\p{Ll})/gu, "$1"),
    );
  });
}
export async function importPDF(
  file: File,
  progress?: (message: string) => void,
): Promise<ImportedDocument> {
  const task = getDocument({
    data: new Uint8Array(await file.arrayBuffer()),
    useSystemFonts: true,
  });
  let passwordProtected = false;
  task.onPassword = (_update: (password: string) => void) => {
    passwordProtected = true;
    void task.destroy();
  };
  let pdf;
  try {
    pdf = await task.promise;
  } catch (error) {
    if (passwordProtected || (error as Error).name === "PasswordException")
      throw new Error(
        "This PDF is password protected. Save an unlocked copy before importing.",
      );
    throw new Error("This PDF could not be read. Try exporting a new copy.");
  }
  try {
    if (pdf.numPages > 3000)
      throw new Error(
        "This PDF has more than 3,000 pages. Import it in smaller parts.",
      );
    const pages: string[] = [];
    for (let i = 1; i <= pdf.numPages; i++) {
      progress?.(`Reading PDF page ${i} of ${pdf.numPages}...`);
      const page = await pdf.getPage(i);
      const content = await page.getTextContent();
      let text = "",
        lastY: number | undefined;
      for (const item of content.items) {
        if (!("str" in item)) continue;
        const y = item.transform[5];
        if (lastY !== undefined && Math.abs(y - lastY) > 3) text += "\n";
        else if (text && !/\s$/.test(text) && !/^\s/.test(item.str))
          text += " ";
        text += item.str;
        if (item.hasEOL) text += "\n";
        lastY = y;
      }
      pages.push(text);
      page.cleanup();
      // Yield to allow import progress and cancellation UI to paint.
      if (i % 5 === 0) await new Promise((resolve) => setTimeout(resolve, 0));
    }
    const cleaned = cleanPDFPages(pages);
    const chapters: { page: number; title: string }[] = [];
    type Outline = {
      title: string;
      dest: string | unknown[] | null;
      items: Outline[];
    };
    const visit = async (items: Outline[]) => {
      for (const item of items) {
        try {
          const dest =
            typeof item.dest === "string"
              ? await pdf.getDestination(item.dest)
              : item.dest;
          if (dest?.length && item.title.trim()) {
            const ref = dest[0];
            const index =
              typeof ref === "number"
                ? ref
                : await pdf.getPageIndex(ref as { num: number; gen: number });
            if (index >= 0 && index < cleaned.length)
              chapters.push({ page: index, title: item.title.trim() });
          }
        } catch {
          /* Unresolvable outline entries do not prevent reading the PDF. */
        }
        await visit(item.items ?? []);
      }
    };
    await visit(((await pdf.getOutline()) ?? []) as Outline[]);
    chapters.sort((a, b) => a.page - b.page);
    const unique = chapters.filter(
      (c, i) => i === 0 || c.page !== chapters[i - 1].page,
    );
    if (unique.length && unique[0].page > 0)
      unique.unshift({ page: 0, title: "Opening" });
    const sections = unique.length
      ? unique.map((c, i) =>
          section(
            c.title,
            cleaned
              .slice(c.page, unique[i + 1]?.page ?? cleaned.length)
              .join("\n\n"),
          ),
        )
      : cleaned.map((p, i) => section(`Page ${i + 1}`, p));
    const info = (await pdf.getMetadata()).info as {
      Title?: string;
      Author?: string;
    };
    return {
      title: info?.Title?.trim() || file.name.replace(/\.pdf$/i, ""),
      author: info?.Author?.trim() || undefined,
      sourceName: file.name,
      format: "pdf",
      sections: sections.filter((s) => s.wordCount > 0),
    };
  } finally {
    await task.destroy();
  }
}
