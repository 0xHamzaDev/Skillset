import { readFileSync } from "node:fs";

export const GET = () =>
  new Response(readFileSync(new URL("../../../catalog/catalog.json", import.meta.url)), {
    headers: { "content-type": "application/json" },
  });
