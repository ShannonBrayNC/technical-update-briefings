import React from "react";
import DeckPreviewOptionB, { DeckPreviewFromSources } from "../components/DeckPreviewOptionB";
export default function TabFilmstripPreview() {
  return (
    <div className="min-h-screen p-6">
      <h1 className="text-2xl font-semibold mb-4">Deck Preview – Filmstrip (PR App)</h1>
      <div className="border rounded-xl bg-white shadow-sm">
        <DeckPreviewFromSources defaultView="filmstrip" />
      </div>
      <p className="text-sm text-zinc-600 mt-4">
        Replace the HTML under <code>public/tools/…</code> with your exports from the repo to smoke-test quickly.
      </p>
    </div>
  );
}
