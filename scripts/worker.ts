import { fetchAllUpdates } from "../packages/ingestion/src";
import fs from "node:fs/promises";
import path from "node:path";
import cron from "node-cron";

const OUT = path.resolve(".cache/updates.json");

async function runOnce() {
  const since = new Date(Date.now() - 1000 * 60 * 60 * 24 * 7).toISOString(); // 7 days
  const items = await fetchAllUpdates({ since, limit: 200 });
  await fs.mkdir(path.dirname(OUT), { recursive: true });
  await fs.writeFile(OUT, JSON.stringify({ generatedAt: new Date().toISOString(), items }, null, 2));
  console.log(`Wrote ${items.length} updates -> ${OUT}`);
}

if (process.env.ONE_SHOT === "1") {
  runOnce();
} else {
  cron.schedule("0 * * * *", runOnce); // hourly
  console.log("Worker scheduled hourly. Press Ctrl+C to exit.");
}
