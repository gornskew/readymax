# Standing Project Instructions for AI Clients

Durable instructions for an AI agent (Claude Desktop, Claude Code, Codex,
or any MCP-capable client) connected to a running skewed-emacs stack.

Where to put them:

- **Claude Desktop**: create a Project and paste everything below the
  horizontal rule into the Project's custom instructions.
- **Claude Code**: add it to your project's `CLAUDE.md`.
- **Codex**: add it to `AGENTS.md`.
- **Other clients**: wherever standing, every-session instructions live.

Prefer a one-shot first message instead of standing instructions? Use
[`mcp/opening-prompt.md`](../mcp/opening-prompt.md) — it walks a fresh
session through the same bootstrap interactively.

> Note: this repository's own `CLAUDE.md` is for working **on**
> skewed-emacs (development). This document is for **using** it. Keep
> them separate.

---

## At the start of each session

1. **Learn buffer access first.** Call the skewed-emacs docs tool
   (`get_docs` with `id="claude-md"`) and skim just enough to read
   buffers safely — Buffer Operations and "How to access Emacs state".
2. **Read the Dashboard** for environment status, services, and
   available backends:

   ```elisp
   (with-current-buffer "*dashboard*" (buffer-string))
   ```

3. **Read the Daily Focus, if present** (org-mode agenda of
   Must/Should/Could priorities):

   ```elisp
   (progn
     (org-agenda nil "d")
     (with-current-buffer "*Org Agenda*" (buffer-string)))
   ```

   Daily Focus is optional. If it errors or is empty, the user hasn't
   set it up — skip it, and mention that `M-x skewed-daily-focus-init`
   creates a starter setup.
4. **Before editing files or using a Lisp backend, finish the training.**
   Re-read the full skewed-emacs docs (editing patterns, paredit,
   unbalanced-buffer detection), and read the `claude-md` docs of any
   backend you'll work with (e.g. `gendl-ccl`).
5. **Present options before diving in**: current state (which services
   are healthy), suggested next steps (from priorities/task notes), and
   any questions.

## Durable conventions (no doc re-read required)

### Shared-Emacs safety

You share one live Emacs — current buffer, point, and window state —
with an active human user.

- Target buffers explicitly:
  `(with-current-buffer (find-file-noselect "/path/file") ...)` —
  never bare `find-file` / `switch-to-buffer`.
- Preserve point with `(save-excursion ...)` around any motion.
- For read-only access prefer
  `(with-temp-buffer (insert-file-contents "/path/file") ...)`.
- Never assume the "current buffer" is yours.

### Paredit discipline (Lisp files)

- Make sure `paredit-mode` is enabled in the buffer before editing.
- Prefer structural edits; keep parens balanced at every step.
- Run `(check-parens)` before `(save-buffer)`; if it signals, fix the
  imbalance before saving.

### Discover backends from the Dashboard — never assume the set

The Dashboard's "Lisply Backends" section is the source of truth. A
vanilla install has three (skewed-emacs itself plus two free Gendl
backends); overlays can add more. If it's unclear which backend a task
targets, check the task's notes or ask the user.

### Session state lives in org, not in static docs

If Daily Focus is set up, per-task context (`:HOST:`, `:NOTES:`,
LOGBOOK entries) lives in the org entries under `/projects/org/`
in-container (`~/projects/org/` on the host). Read it from there;
don't expect documentation to carry session-specific state.
