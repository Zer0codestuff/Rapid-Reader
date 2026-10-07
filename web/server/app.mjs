import express from "express";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { fetchArticle } from "./article.mjs";

export const app = express();
app.disable("x-powered-by");
app.set("trust proxy", 1);
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", "data:", "blob:"],
        fontSrc: ["'self'"],
        connectSrc: ["'self'"],
        workerSrc: ["'self'", "blob:"],
        objectSrc: ["'none'"],
        frameAncestors: ["'none'"],
        upgradeInsecureRequests:
          process.env.NODE_ENV === "production" ? [] : null,
      },
    },
    crossOriginEmbedderPolicy: false,
  }),
);
app.use(express.json({ limit: "4kb" }));
app.get("/api/health", (_req, res) => res.json({ status: "ok" }));
let activeImports = 0;
app.post(
  "/api/article",
  rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 30,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    message: {
      error: "Too many article imports. Please try again in a few minutes.",
    },
  }),
  async (req, res) => {
    if (typeof req.body?.url !== "string" || req.body.url.length > 4096)
      return res.status(400).json({ error: "Enter a valid article URL." });
    if (activeImports >= 6)
      return res
        .status(503)
        .json({ error: "Article import is busy. Please try again shortly." });
    activeImports++;
    try {
      res
        .set("Cache-Control", "no-store")
        .json(await fetchArticle(req.body.url));
    } catch (error) {
      res
        .status(422)
        .json({
          error:
            error.name === "TimeoutError"
              ? "This website took too long to respond. Try pasting the article text."
              : error.message.includes("fetch failed")
                ? "This website could not be reached. Try pasting the article text."
                : error.message,
        });
    } finally {
      activeImports--;
    }
  },
);
app.use("/api", (_req, res) => res.status(404).json({ error: "Not found." }));
const dist = fileURLToPath(new URL("../dist/", import.meta.url));
app.use(
  express.static(dist, {
    setHeaders(res, file) {
      res.set(
        "Cache-Control",
        file.includes(`${path.sep}assets${path.sep}`)
          ? "public, max-age=31536000, immutable"
          : "no-cache",
      );
    },
  }),
);
app.get("/{*path}", (_req, res) =>
  res.set("Cache-Control", "no-cache").sendFile(path.join(dist, "index.html")),
);
app.use((error, _req, res, _next) =>
  res
    .status(error.status ?? 500)
    .json({
      error:
        error.status === 413
          ? "The request is too large."
          : "The request could not be processed.",
    }),
);
