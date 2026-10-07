import { app } from "./app.mjs";
const port = Number(process.env.PORT) || 3001;
const server = app.listen(port, "0.0.0.0", () =>
  console.log(`Rapid Reader is listening on port ${port}`),
);
function shutdown() {
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 10000).unref();
}
process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
