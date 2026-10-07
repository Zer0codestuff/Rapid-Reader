// RTF text extraction preserves paragraph breaks, Unicode and escaped characters.
export function rtfText(source: string) {
  if (!/^\s*\{\\rtf/.test(source))
    throw new Error("This file is not a valid RTF document.");
  const stack: { skip: boolean; uc: number }[] = [];
  let skip = false,
    uc = 1,
    fallback = 0,
    output = "";
  const decoder = new TextDecoder("windows-1252");
  const destinations = new Set([
    "fonttbl",
    "colortbl",
    "stylesheet",
    "info",
    "pict",
    "object",
    "header",
    "footer",
    "headerl",
    "headerr",
    "footerl",
    "footerr",
    "filetbl",
    "listtable",
    "listoverridetable",
    "generator",
    "fldinst",
    "datastore",
    "themedata",
    "colorschememapping",
  ]);
  const append = (char: string) => {
    if (fallback > 0) fallback--;
    else if (!skip) output += char;
  };
  for (let i = 0; i < source.length; i++) {
    const char = source[i];
    if (char === "{") {
      stack.push({ skip, uc });
      continue;
    }
    if (char === "}") {
      const previous = stack.pop();
      if (previous) {
        skip = previous.skip;
        uc = previous.uc;
      }
      continue;
    }
    if (char !== "\\") {
      if (char !== "\r" && char !== "\n") append(char);
      continue;
    }
    const next = source[++i];
    if (next === "\\" || next === "{" || next === "}") {
      append(next);
      continue;
    }
    if (next === "*") {
      skip = true;
      continue;
    }
    if (next === "'") {
      const byte = parseInt(source.slice(i + 1, i + 3), 16);
      if (Number.isFinite(byte)) append(decoder.decode(new Uint8Array([byte])));
      i += 2;
      continue;
    }
    if (next === "~") {
      append(" ");
      continue;
    }
    if (next === "_") {
      append("-");
      continue;
    }
    if (!/[a-z]/i.test(next ?? "")) continue;
    const match = source.slice(i).match(/^([a-z]+)(-?\d+)? ?/i)!;
    i += match[0].length - 1;
    const word = match[1],
      value = Number(match[2]);
    if (destinations.has(word)) {
      skip = true;
      continue;
    }
    if (word === "bin") {
      i += Math.max(0, value);
      continue;
    }
    if (word === "uc") {
      uc = Math.max(0, Math.min(10, value));
      continue;
    }
    if (word === "u") {
      if (!skip)
        output += String.fromCharCode(value < 0 ? value + 65536 : value);
      fallback = uc;
      continue;
    }
    if (skip) continue;
    if (word === "par" || word === "line") output += "\n";
    if (word === "tab") output += " ";
    if (word === "lquote" || word === "rquote") output += "'";
    if (word === "ldblquote" || word === "rdblquote") output += '"';
    if (word === "emdash" || word === "endash") output += "-";
    if (word === "bullet") output += "•";
  }
  return output;
}
