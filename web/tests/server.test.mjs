// @vitest-environment node
import { describe, it, expect } from "vitest";
import {
  extractArticle,
  publicAddress,
  validateURL,
  fetchArticle,
} from "../server/article.mjs";

describe("article service", () => {
  it("rejects local, private, mapped and reserved addresses", () => {
    for (const address of [
      "127.0.0.1",
      "10.0.0.2",
      "192.168.1.1",
      "169.254.169.254",
      "0.0.0.0",
      "::1",
      "fc00::1",
      "fe80::1",
      "::ffff:127.0.0.1",
      "224.0.0.1",
    ])
      expect(publicAddress(address)).toBe(false);
    expect(publicAddress("1.1.1.1")).toBe(true);
    expect(publicAddress("2606:4700:4700::1111")).toBe(true);
  });
  it("rejects credentials, unsafe protocols, ports and internal hosts", () => {
    for (const url of [
      "file:///etc/passwd",
      "http://localhost/",
      "http://127.1/",
      "http://2130706433/",
      "http://[::1]/",
      "http://user:password@example.com",
      "https://example.com:8443/",
      "http://app.railway.internal/",
    ])
      expect(() => validateURL(url)).toThrow();
    expect(validateURL("https://example.com/article").href).toBe(
      "https://example.com/article",
    );
  });
  it("never fetches a private target", async () => {
    await expect(fetchArticle("http://192.168.1.1/")).rejects.toThrow("public");
  });
  it("extracts prose and paragraph breaks without script or navigation", () => {
    const html = `<html><title>Test article</title><body><nav>Navigation noise</nav><article><h1>Test article</h1><p>${"This is readable article text with complete sentences. ".repeat(10)}</p><p>Second paragraph remains separate.</p><script>window.evil = true</script></article><footer>Footer noise</footer></body></html>`;
    const result = extractArticle(html, "https://example.com/article");
    expect(result.title).toBe("Test article");
    expect(result.text).toContain("Second paragraph");
    expect(result.text).toContain("\n");
    expect(result.text).not.toContain("Navigation noise");
    expect(result.text).not.toContain("window.evil");
    expect(result.text).not.toContain("Footer noise");
  });
});
