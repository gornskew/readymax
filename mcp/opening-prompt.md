# Session Start - Bootstrap with Context

Suggested opening prompt for an AI agent connected to skewed-emacs via
MCP. Paste this (or adapt it) into a fresh session with Claude Desktop,
Claude Code, Codex, or any MCP-capable client.

## Step 1: Learn Basic Buffer Access (MCP Docs Essentials)
**First, read just enough to access the Dashboard:**

Call: `skewed-emacs:skewed-emacs__get_docs(id="claude-md")`

**Focus on these sections only (skip the rest for now):**
- "Basic MCP Usage Examples" -> Buffer Operations
- "How to access Emacs state"
- Look for examples like: `(with-current-buffer "*dashboard*" (buffer-string))`

You need ~5 minutes of elisp confidence to read buffers. Don't get
overwhelmed by paredit-mode/editing yet.

## Step 2: Review the Dashboard
**Now use your basic elisp skills to check current context:**

**Dashboard** (shows environment status, services, recent activity):
```elisp
(with-current-buffer "*dashboard*" (buffer-string))
```

**Daily Focus** (org-mode agenda of priorities, if the user has set it up
with `M-x skewed-daily-focus-init`):
```elisp
(progn
  (org-agenda nil "d")
  (with-current-buffer "*Org Agenda*" (buffer-string)))
```

The Daily Focus shows Must/Should/Could priorities. This tells you
what's in flight. If it is empty or errors, the user hasn't set it up —
that's fine; skip it.

## Step 3: Complete MCP Training
**Now read the full skewed-emacs MCP docs:**

Re-read: `skewed-emacs:skewed-emacs__get_docs(id="claude-md")` - this time completely

**Key sections:**
- File editing (paredit-mode for Lisp files!)
- Detecting unbalanced buffers
- Safe editing patterns
- Shared buffer state warnings

**If working with Gendl/Common Lisp backends, also read the docs for
that backend** (the Dashboard lists available Lisply backends, e.g.
gendl-ccl, gendl-sbcl, plus any commercial overlays the user has
installed):
```
gendl-ccl:gendl-ccl__get_docs(id="claude-md")
```

## Step 4: Present Options to the User
Based on the Dashboard (and Daily Focus if present), present:

1. **Current state** - which services/backends are up and healthy
2. **Suggested next steps** - informed by any priorities you found
3. **Questions** - anything unclear before starting work

## Quick Reference
- **Org files (if Daily Focus is set up)**: `/projects/org/projects.org` in-container
  (`~/projects/org/projects.org` on the host)
- **Navigate via agenda**: use `org-agenda-goto` from the *Org Agenda*
  buffer to jump to a task's full entry (look for :HOST:, :NOTES:, or
  LOGBOOK context)
