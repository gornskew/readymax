# Standing Orders for a Cyborg Aboard

Durable orders for a cyborg (Claude Desktop, Claude Code, Codex, or
any craft that speaks MCP) calling on a raised Basilisk ship.

Where to post them:

- **Claude Desktop**: create a Project and paste everything below the
  rule into the Project's custom instructions.
- **Claude Code**: add it to your project's `CLAUDE.md`.
- **Codex**: add it to `AGENTS.md`.
- **Other craft**: wherever standing, every-session instructions go.

Prefer a single first hail to standing orders? Use
[`mcp/opening-prompt.md`](https://github.com/gornskew/basilisk/blob/devo/mcp/opening-prompt.md)
from the Basilisk clone — it walks a fresh session through the same
boarding, one step at a time.

> Note: this repository's own `CLAUDE.md` is for working **on**
> Readymax (refitting the room). This scroll is for **using** it.
> Keep the two apart.

---

## On boarding, every session

1. **Learn to handle scrolls before touching one.** Read the Captain's
   primer (the `get_docs` tool of the ready room's channel,
   `id="primer"`): short, and it covers reading, searching and
   editing every scroll aboard — Lisp or not — through the Captain's
   own hands, `lisp_eval`, rather than a shell.  Then evaluate
   `(lisply-help)` once, to see those hands.
2. **Read the day-board** for the ship's state, the crew channels and
   the residents answering:

   ```elisp
   (with-current-buffer "*dashboard*" (buffer-string))
   ```

3. **Read the day's orders, if the Captain keeps them** (the org-mode
   Daily Focus, Must/Should/Could):

   ```elisp
   (progn
     (org-agenda nil "d")
     (with-current-buffer "*Org Agenda*" (buffer-string)))
   ```

   The orders are optional. If this errors or comes back empty, the
   Captain has not set them up — skip it, and mention that
   `M-x skewed-daily-focus-init` lays out a starter set.
4. **Before hailing a Lisp resident**, read the `claude-md` packet of
   any resident you will work with (the bridge's, say).  The Captain's
   own longer packets (`claude-md`, `main-claude-md`) are references,
   for when the primer does not cover the case.
5. **Report before acting**: the state of the ship (which crew answer),
   the next steps you propose (from the orders and the task notes),
   and any questions.

## Standing conventions (no re-reading required)

### One Captain, shared

You share one live Emacs — the current scroll, point, and the window
layout — with a biological who is working in it.

- Read, search and edit scrolls with the Captain's helpers —
  `lisply-read`, `lisply-grep`, `lisply-replace`, `lisply-form-replace`
  — not shell tools: they work through a scroll the biological has
  open instead of underneath it, refuse an edit that would unbalance a
  Lisp scroll, and never ask a question.  A question the Captain is
  asked stops every channel aboard until someone answers it.
- Never open a project scroll with `find-file` or `find-file-noselect`
  from an eval (its mode hooks can ask questions); never bare
  `switch-to-buffer`.
- Name the scroll you mean, `(with-current-buffer BUF ...)`, and keep
  point where you found it with `(save-excursion ...)`.
- Never assume the "current buffer" is yours.

### Paredit discipline (Lisp scrolls)

- Prefer whole-form edits (`lisply-form-replace`, `lisply-form-insert`)
  and exact-text ones (`lisply-replace`); both check the balance for
  you and write nothing if it would break.
- For finer structural work, paredit in a temp buffer, then
  `(lisply-check-parens FILE)`.

### Ask the day-board who is aboard — never assume the roster

The day-board's crew channels are the source of truth. A standard rig
carries three residents who answer the Lisply dialect (the Captain and
the two free Gendl rooms, the bridge and the engine room); a stack
pouch can add more. If it is unclear which resident a task is for,
read the task's notes or ask the biological.

### Session state lives in org, not in standing scrolls

If the day's orders are kept, per-task context (`:HOST:`, `:NOTES:`,
LOGBOOK entries) lives in the org entries under `/projects/org/`
aboard (`~/projects/org/` on the dock). Read it there; do not expect
a standing scroll to carry what changes from session to session.
