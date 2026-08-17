# SLIME, as vendored here

This directory is a **third-party** tree. It is not Gornskew's, it does
not carry the repository's AGPL notice, and nothing in it should ever be
stamped with one. This file records what it is, where it came from, and
what we changed — the three things a downstream recipient needs and that
a vendored snapshot otherwise loses.

## Upstream

- Project: SLIME — the Superior Lisp Interaction Mode for Emacs
  (<https://github.com/slime/slime>)
- Version: 2.28
- Exact commit: `a4f3471487db48f7289dc0ea019611d093e5ee7f` (also in `.gitref`)

## License

SLIME's own `README.md` says: *"All files, unless explicitly stated
otherwise, are public domain."* Seven files do state otherwise, and all
seven are **GPL version 2 or later**:

    slime.el
    slime-tests.el-hold
    contrib/slime-cl-indent.el
    lib/cl-lib.el
    lib/hyperspec.el
    lib/macrostep.el
    swank/clisp.lisp

The rest — including all of `swank/` apart from `clisp.lisp` — is public
domain, `swank.lisp` explicitly so.

**"or later" is the part that matters.** GPL-2-*only* code cannot be
combined with an AGPL-3.0 work; GPL-2-*or-later* can be taken up to
GPL-3, which AGPL-3.0 §13 then permits combining with. Every GPL file
here carries the "or later" clause — checked file by file, not assumed —
so vendoring this tree inside an AGPL-3.0 repository is sound. If a
future SLIME bump introduces a GPL-2-only file, that is a genuine
conflict and not a paperwork problem.

## Local modifications

One commit, `5176103` (2026-04-09, "tweaked slime for allegro"), touching
one file in this tree: **`swank/allegro.lisp`**. The file is public
domain upstream, so no license obligation attaches to modifying it; this
is recorded because a fork nobody documented is a fork nobody can
un-merge.

1. **`swank-compile-file` forces UTF-8.** `(setq external-format utf8-ef)`
   overrides whatever the caller passed, using the `utf8-ef` symbol-macro
   already defined at the top of the file. Deliberate.

2. **A debug print was left in**, on the line below it:

       (gdl:print-variables external-format)

   This is residue, and it is not inert. It prints on every
   `compile-file` through SLIME, and — because `gdl:` is resolved when
   the file is *read* — it makes this backend fail to load on any Allegro
   image that has no `GDL` package. That is fine for the Genworks GDL
   images this is normally used against, and a hard break for a bare
   Allegro. Tracked in `org/future.org`; left in place here rather than
   silently changed, since the surrounding `setq` is intentional and only
   the author knows whether the print still earns its keep.

3. **An arity change in the inspector**, same commit: the `:unsigned-*`
   branch calls `inspect::component-ref-v` with `type` commented out.

## Bumping SLIME

Re-apply the intentional part of (1) and (3), drop (2) unless it has been
re-justified, and re-run the GPL-2-only check described above.
