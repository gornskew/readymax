# Claude Desktop Integration — moved to Basilisk

This guide now lives in the Basilisk repo, at
[`docs/CLAUDE_DESKTOP.md`](https://github.com/gornskew/basilisk/blob/devo/docs/CLAUDE_DESKTOP.md)
(origin of record: `gitlab.genworks.com:gornskew/basilisk`, mirrored to
[github.com/gornskew/basilisk](https://github.com/gornskew/basilisk)).

Wiring an MCP client is a **fleet-level** concern, not a Captain-level
one: the config being generated registers every server on the roster —
`skewed-emacs`, `gendl-ccl`, `gendl-sbcl`, and whatever the overlays add.
This repo knows about exactly one of those, so it cannot own the
document.

A stub is left here rather than a deletion because the old path was
linked from the README, from `lisply-mcp`, and from anywhere else people
bookmarked it.

**If you are looking for the MCP story that does still belong to this
repo**, it is host Emacs: running the lisply backend in your own Emacs
on the host, with no containers at all. See
[HOST_EMACS_MCP.md](HOST_EMACS_MCP.md).
