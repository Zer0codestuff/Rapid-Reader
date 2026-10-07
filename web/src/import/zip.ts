import type JSZip from "jszip";

// JSZip 3 exposes the declared unpacked size on loaded entries before inflation.
// Bound it before reading XML or cover data, then also check the extracted text.
export function validateZip(zip: JSZip) {
  const entries = Object.values(zip.files);
  if (entries.length > 10000)
    throw new Error("This document contains too many files.");
  let total = 0;
  for (const entry of entries) {
    const size =
      (entry as unknown as { _data?: { uncompressedSize?: number } })._data
        ?.uncompressedSize ?? 0;
    if (size > 30_000_000)
      throw new Error("A file inside this document is too large to import.");
    total += size;
    if (total > 250_000_000)
      throw new Error(
        "This document is too large when unpacked. Import a smaller copy.",
      );
  }
}
