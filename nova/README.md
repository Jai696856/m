# NOVA

A retro reasoning engine that runs entirely in one web page (`index.html`). It doesn't use any outside AI.

- **Three models:** BLANK starts knowing nothing. SCHOLAR has a knowledge pack of about 4,500 facts and shows its reasoning. MINI gives quick answers from facts it knows directly.
- **Reasoning:** it chains facts together ("a tarantula is an arachnid" + "an arachnid has 8 legs"), compares things, and solves math and equations step by step.
- **Teach it:** type plain sentences like `cats are animals` or `x = 5`.
- **Read & Learn:** paste a paragraph and it pulls out the facts by itself.
- **Wikipedia:** `look up komodo dragon`, or turn on AUTO-LEARN. Then, when it doesn't know something, it looks the subject up and tries your question again.

What you teach it is saved in your browser (localStorage).

## Putting it online with GitHub Pages

1. On GitHub, open this repository, then go to **Settings → Pages**.
2. Under **Build and deployment**, set **Source** to **Deploy from a branch**.
3. Pick the branch that contains this folder, choose the **/ (root)** folder, and press **Save**.
4. After a minute or two, NOVA is live at `https://jai696856.github.io/m/nova/`.

Wikipedia lookups work from that address, or from the file opened directly in a browser. They don't work from the claude.ai copy, because claude.ai blocks pages from going online.
