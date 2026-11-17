# NOVA

A retro reasoning engine that runs entirely in one web page (`index.html`). It doesn't use any outside AI. It only reads public sources and does its own reasoning.

Why not Google? Google doesn't let web pages call its search directly, and its search API needs a private key. Putting a key in a public page would let anyone copy and misuse it.

- **Three models:** BLANK starts knowing nothing. SCHOLAR has a knowledge pack of about 4,500 facts and shows its reasoning. MINI gives quick answers from facts it knows directly.
- **Reasoning:** it chains facts together ("a tarantula is an arachnid" + "an arachnid has 8 legs"), compares things, and solves math and equations step by step.
- **Teach it:** type plain sentences like `cats are animals` or `x = 5`.
- **Read & Learn:** paste a paragraph and it pulls out the facts by itself.
- **Web search:** `search komodo dragon` (or `look up …`, `define …`). NOVA searches four open sources and reads each one itself:
  - **Wikipedia:** finds the right article and reads its summary.
  - **Simple English Wikipedia:** plain sentences that are easier for it to understand.
  - **Wikidata:** exact facts such as capitals, populations, heights, birth years and leaders.
  - **Wiktionary:** word meanings.

  With AUTO-LEARN on, NOVA searches by itself whenever it doesn't know something, then tries your question again. Each fact it learns this way is labelled with where it came from.

What you teach it is saved in your browser (localStorage).

## Putting it online with GitHub Pages

1. On GitHub, open this repository, then go to **Settings → Pages**.
2. Under **Build and deployment**, set **Source** to **Deploy from a branch**.
3. Pick the branch that contains this folder, choose the **/ (root)** folder, and press **Save**.
4. After a minute or two, NOVA is live at `https://jai696856.github.io/m/nova/`.

Web search works from that address, or from the file opened directly in a browser. It doesn't work from the claude.ai copy, because claude.ai blocks pages from going online.
