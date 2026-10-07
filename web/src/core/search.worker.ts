import { searchDocument } from "./text";
import type { Section } from "./types";
self.onmessage = (
  event: MessageEvent<{ id: number; sections: Section[]; query: string }>,
) => {
  const { id, sections, query } = event.data;
  self.postMessage({ id, matches: searchDocument(sections, query) });
};
