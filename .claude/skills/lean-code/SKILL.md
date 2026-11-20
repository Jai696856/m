---
name: lean-code
description: Write minimal code and remove dead code you added, while spending fewer tokens. Use after making code changes, when asked to clean up, trim, or de-bloat your own work, or when the user says "lean", "remove useless code", or "save tokens".
---

# Lean Code

Two goals: ship only code that earns its place, and spend as few tokens as possible doing it.

## While writing

- Solve the asked problem only. No speculative features, options, flags, or "future-proofing".
- No wrappers, helpers, or abstractions used once. Inline them.
- No defensive checks for states that can't happen. Validate only at real boundaries (user input, I/O, network).
- No comments restating the code. Comment only the non-obvious *why*.
- No debug prints, placeholder TODOs, or commented-out code left behind.
- Reuse what the project already has before adding new code. Grep first.
- Prefer editing existing files over creating new ones.

## Cleanup pass (run on your own diff)

1. `git diff` (or `git diff HEAD` / `git diff --stat` first if large) — look only at lines you changed.
2. For each addition, delete it if any is true:
   - Unused: variable, import, parameter, function, signal, export with no caller (`grep -rn name`).
   - Unreachable: code after return, impossible branches, always-true/false conditions.
   - Duplicate: logic that already exists elsewhere — call that instead.
   - Leftover: debug logging, scratch files, test stubs not wired in, stale comments.
   - Over-built: config/abstraction with one call site — collapse it.
3. Never delete code you didn't add unless asked. Never delete tests to make things pass.
4. Run the project's existing tests/lint once after cleanup. If none, do a quick smoke check.
5. Report in one or two lines: what was removed and that checks passed (or didn't).

## Token discipline

- Read only what you need: use Grep/`grep -n` to locate, then Read with `offset`/`limit`. Don't read whole large files.
- Don't re-read a file you just edited; don't re-run a command whose output you already have.
- Batch independent tool calls in one turn.
- Don't spawn subagents unless asked.
- Use `edits`/Edit with small exact replacements, not full-file rewrites.
- Keep replies short: result first, no recap of the diff, no restating the plan, no option surveys.
- Skip narration between tool calls unless something changed direction.
