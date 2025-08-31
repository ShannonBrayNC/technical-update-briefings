# PR: Tab Filmstrip (Teams Tab / Web Preview)

This adds a self-contained Vite app under `tab-filmstrip/` so you can smoke-test the **DeckPreview – Filmstrip** UI
without touching the main app. It also includes a ready `git-apply.diff` that adds this folder in one command.

## Quick run

```bash
cd tab-filmstrip
npm i
npm run dev
```

Sources are served from `public/tools/...`. Replace those files with your exported HTML.

## Use in your main app

1) Copy `src/components/DeckPreviewOptionB.tsx` into your app (or import from this folder).
2) Use it:

```tsx
import DeckPreviewOptionB, { DeckPreviewFromSources } from "tab-filmstrip/src/components/DeckPreviewOptionB";
<DeckPreviewFromSources defaultView="filmstrip" />
```

3) Ensure your app serves:
- `/tools/roadmap/RoadmapPrimarySource.html`
- `/tools/message_center/MessageCenterBriefingSuppliments.html`
- optional `/deck-images/*`

## Apply as a patch

```bash
git checkout -b feat/tab-filmstrip
git apply tab-filmstrip/git-apply.diff
git add -A
git commit -m "feat(tab): add filmstrip preview app + component"
git push -u origin feat/tab-filmstrip
```
