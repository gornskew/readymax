# Skewed Emacs + Gendl Docker Development Environment

This file provides guidance to Claude Code (claude.ai/code) or other AI agents when working with the integrated Skewed Emacs and Gendl development environment.

## Overview

This setup provides a complete Lisp development environment with:
- **Skewed Emacs Container**: Custom Emacs configuration with MCP integration
- **Gendl Container**: 3D CAD/modeling system with Common Lisp REPL and MCP integration
- **Network Integration**: Containers communicate via Docker network for SLIME connections
- **MCP Services**: Both containers expose services via Model Context Protocol for external tool integration

## MCP Integration

The containers are now wrapped as MCP (Model Context Protocol) services, providing seamless integration with Claude Code and other MCP-enabled tools.

### Available MCP Services

**Emacs Lisp Evaluation Service:**
- **Service Name**: `mcp__skewed-emacs__skewed-emacs__lisp_eval`
- **Purpose**: Evaluate Emacs Lisp code remotely
- **Usage**: `mcp__skewed-emacs__skewed-emacs__lisp_eval(code="(+ 1 2 3)")`

**Gendl Common Lisp Services (included with skewed-emacs):**
- `mcp__gendl_ccl__gendl_ccl__lisp_eval` — Gendl on Clozure CL (port 9080)
- `mcp__gendl_sbcl__gendl_sbcl__lisp_eval` — Gendl on SBCL (port 9090)

**Commercial Genworks GDL Services (via supplemental overlay repos):**
- `mcp__genworks_gdl_smp__genworks_gdl_smp__lisp_eval` — GDL with NURBS (port 9098)
- `mcp__genworks_gdl_enterprise_smp__genworks_gdl_enterprise_smp__lisp_eval` — Enterprise variant
- These are not included in skewed-emacs. Licensed users receive a supplemental
  repo to clone as a sibling directory, then run its `./install` script to
  add Docker Compose and MCP config overlays into skewed-emacs.

**Ping Services:**
- `mcp__skewed_emacs__skewed_emacs__ping_lisp` - Check Emacs availability
- `mcp__gendl_ccl__gendl_ccl__ping_lisp` - Check Gendl CCL availability
- `mcp__gendl_sbcl__gendl_sbcl__ping_lisp` - Check Gendl SBCL availability

### MCP vs Raw HTTP

**Previous Approach (Deprecated):**
```bash
# Raw HTTP calls (no longer recommended)
curl -X POST http://localhost:7080/lisply/lisp-eval -d '{"code": "(+ 1 2 3)"}'  # only from inside container
```

**Current Approach (Recommended):**
```python
# Through MCP services (seamless with Claude Code)
mcp__skewed_emacs__skewed_emacs__lisp_eval(code="(+ 1 2 3)")
```


### Verification Commands

Check if workarounds are active:
```bash
# Test current environment via MCP
mcp__skewed_emacs__skewed_emacs__lisp_eval(code='(list (getenv "SHELL") shell-file-name (getenv "PATH"))')

# Test native compilation settings
mcp__skewed_emacs__skewed_emacs__lisp_eval(code='native-comp-jit-compilation')

# Test assembler accessibility
mcp__skewed_emacs__skewed_emacs__lisp_eval(code='(shell-command-to-string "which as")')
```

## Quick Start

### 1. Start the Environment

```bash
# The stack lives in the Basilisk repo, not this one.
cd ~/projects/basilisk

# Start the full container stack
./basilisk up

# Verify services are running via MCP
mcp__skewed_emacs__skewed_emacs__ping_lisp()      # Should return "pong"
mcp__gendl_ccl__gendl_ccl__ping_lisp()            # Should return "pong"
```

### 2. Connect to Development Environment

```bash
# Connect to Emacs in the container
docker exec -it skewed-emacs emacsclient -t

# From within Emacs, connect to Gendl SLIME
# M-x slime-connect RET gendl-ccl RET 4200 RET
```

## Container Details

### Skewed Emacs Container (`skewed-emacs`)
- **Base**: Custom Emacs configuration
- **Network Name**: `skewed-emacs` (accessible as `skewed-emacs:7080` from other containers)
- **Host Ports**: 
- `6942` → `6942` (ttyd web terminal)
- **MCP Service**: Available via `mcp__skewed-emacs__*` functions
- **Mount**: `~/projects` → `/projects`

### Gendl/GDL Containers

**Included with skewed-emacs** (free, open-source Gendl kernel):

| Container | Image | HTTP Port | Swank Port |
|-----------|-------|-----------|------------|
| `gendl-ccl` | `genworks/gendl:devo-ccl` | 9080 (host: 19080) | 4200 |
| `gendl-sbcl` | `genworks/gendl:devo-sbcl` | 9090 (host: 29080) | 4210 |

**Available via supplemental overlay repos** (licensed, commercial GDL with NURBS):

| Container | HTTP Port | Swank Port |
|-----------|-----------|------------|
| `genworks-gdl-smp` | 9098 | 4218 |
| `genworks-gdl-non-smp` | 9089 | 4209 |
| `genworks-gdl-enterprise-smp` | 9098 | 4218 |

Licensed users clone their supplemental repo as a sibling to `basilisk/`,
run `./install` (which copies the overlay into the Basilisk checkout —
override with `BASILISK_DIR=` if it lives elsewhere), then `./basilisk up`
picks up the overlay automatically.

All containers mount `~/projects` → `/projects` and join `skewed-network`.
Check the Dashboard (`*dashboard*` buffer) for current service health.

### Docker Network
- **Network Name**: `skewed-network`
- **Purpose**: Enables container-to-container communication
- **Key Benefit**: Allows SLIME connection from Skewed Emacs to Gendl Swank server

## Development Workflow

### 1. Basic SLIME Development
```elisp
;; In Skewed Emacs container, after slime-connect to gendl-ccl:4200
;; Load Quicklisp
(load-quicklisp)

;; Add project directories
(pushnew "~/projects/gendl/demos/" ql:*local-project-directories* :test #'equalp)

;; Enable development mode
(setq gwl:*developing?* t)

;; Load systems
(ql:quickload :wire-world)
(ql:quickload :bus)
```

### 2. MCP API Development  
```python
# Test Gendl MCP service
result = mcp__gendl_ccl__gendl_ccl__lisp_eval(code="(+ 1 2 3)")

# Test Emacs MCP service
result = mcp__skewed_emacs__skewed_emacs__lisp_eval(code="(+ 1 2 3)")

# Test connectivity
gendl_status = mcp__gendl_ccl__gendl_ccl__ping_lisp()
emacs_status = mcp__skewed_emacs__skewed_emacs__ping_lisp()
```

### 3. Monitoring Claude Code Activity
With MCP services running, you can monitor what Claude Code or other agents are doing:

```bash
# Watch Emacs activities
docker logs -f skewed-emacs

# Watch Gendl activities  
docker logs -f gendl-ccl

# Or from within Emacs, watch the *Messages* buffer for API calls
```

## MCP API Usage

For detailed MCP API documentation, examples, and best practices, see:
**`dot-files/emacs.d/sideloaded/lisply-backend/CLAUDE.md`**

### Quick MCP API Reference
```python
# Basic evaluation
mcp__skewed_emacs__skewed_emacs__lisp_eval(code="(+ 1 2 3)")

# File editing (see lisply-backend docs for detailed patterns)
mcp__skewed_emacs__skewed_emacs__lisp_eval(code='(find-file "/path/to/file.lisp")')

# Test connectivity
mcp__skewed_emacs__skewed_emacs__ping_lisp()
```

**⚠️ CRITICAL WARNING**: When using MCP file editing, you share the **global current buffer** with the user. Always use `with-current-buffer` patterns to avoid conflicts. See lisply-backend documentation for safe practices.

## File Editing via MCP

**For comprehensive file editing documentation, see:**
**`dot-files/emacs.d/sideloaded/lisply-backend/CLAUDE.md`**

That documentation includes:
- Detailed MCP API patterns
- Paredit mode instructions for Lisp editing
- Safe buffer operations vs string manipulation
- Interactive prompt avoidance
- Error recovery patterns
- **Shared buffer footgun warnings**

## Network Architecture

```
Host Machine
├── MCP Services (via lisply-mcp wrapper)
│   ├── mcp__skewed-emacs__*    → skewed-emacs:7080
│   ├── mcp__gendl-ccl__*       → gendl-ccl:9080      (included)
│   ├── mcp__gendl-sbcl__*      → gendl-sbcl:9090     (included)
│   └── mcp__genworks-gdl-*__*  → genworks-gdl-*:9098  (overlay)
└── Host Ports: 6942 (ttyd), 19080 (gendl-ccl), 29080 (gendl-sbcl)

Docker Network: skewed-network
├── skewed-emacs   (Emacs + MCP + ttyd)           ── always present
├── gendl-ccl      (CCL + Swank 4200)             ── always present
├── gendl-sbcl     (SBCL + Swank 4210)            ── always present
└── genworks-gdl-* (Allegro CL + Swank 4218/4209) ── overlay repos
```

## Commands Reference

### Container Management
```bash
# Create network (one-time)
docker network create skewed-network

# List running containers
docker ps

# Stop containers
docker stop skewed-emacs gendl-ccl

# Remove containers
docker rm skewed-emacs gendl-ccl

# Remove network
docker network rm skewed-network
```

### Development Commands
```bash
# Connect to Emacs
docker exec -it skewed-emacs emacsclient -t

# Connect to Gendl REPL directly
docker exec -it gendl-ccl ccl

# Check logs
docker logs skewed-emacs
docker logs gendl-ccl
```

### Testing Connectivity
```python
# Test MCP services
emacs_status = mcp__skewed_emacs__skewed_emacs__ping_lisp()
gendl_status = mcp__gendl_ccl__gendl_ccl__ping_lisp()

# Test basic operations
emacs_result = mcp__skewed_emacs__skewed_emacs__lisp_eval(code="(+ 1 2 3)")
gendl_result = mcp__gendl_ccl__gendl_ccl__lisp_eval(code="(+ 1 2 3)")
```

## Troubleshooting

### Common Issues

1. **MCP services not responding**:
   - Check if containers are running: `docker ps`
   - Verify MCP wrapper is configured correctly
   - Check container logs: `docker logs <container-name>`

2. **Containers not communicating**:
   - Ensure both containers are on the same network: `docker network ls`
   - Check container names: `docker ps --format "table {{.Names}}\t{{.Networks}}"`

3. **SLIME connection fails**:
   - Verify Swank is running: `docker exec gendl-ccl netstat -an | grep 4200`
   - Check network connectivity: `docker exec skewed-emacs telnet gendl-ccl 4200`

4. **Mount issues**:
   - Ensure `~/projects` exists on host
   - Check permissions: `ls -la ~/projects`

### Reset Environment
```bash
# Stop and remove everything
cd ~/projects/skewed-emacs
./basilisk down

# Recreate from scratch
./basilisk up
```

## Integration with Claude Code

This environment is designed to work seamlessly with Claude Code:

1. **MCP Service Access**: Claude Code can use MCP services directly without HTTP calls
2. **File System Access**: Both containers mount `~/projects` for shared file access
3. **Real-time Monitoring**: Use `docker exec` to connect to Emacs and watch Claude's activities
4. **Development Feedback Loop**: Edit files, test with Claude, see results in real-time

### Example Claude Code Workflow
```python
# Claude makes changes via MCP services
result = mcp__gendl_ccl__gendl_ccl__lisp_eval(code='(ql:quickload :my-project)')

# You can see the results in your SLIME session
# And use Update! links in Gendl web interface for live reloading
```

## Important Notes

### Security Considerations
- MCP services allow arbitrary Lisp evaluation
- Only use in trusted, containerized environments
- Do not expose services to untrusted networks

### Data Types
- All results are returned as strings (using `format "%s"`)
- Complex Lisp data structures maintain their textual representation
- Boolean values: `t` for true, `nil` for false

### Error Handling
- Syntax errors and runtime errors are caught and returned in result
- MCP services provide consistent error reporting

## Related Documentation

- **Gendl MCP Docs**: Use `gendl-ccl:get_docs(id="claude-md")` or equivalent for each backend
- **Main Gendl Guide**: `/projects/CLAUDE.md` (top-level project documentation)

## Lessons Learned (March 2026 Session)

### Reading SLIME REPL Buffers via MCP
When reading `*slime-repl allegro<N>*` buffers from MCP:
- **Use `(buffer-string)`** — this works reliably
- **Do NOT use `(buffer-substring-no-properties ...)`** — returns empty strings for SLIME REPL buffers
- **Send commands**: `(with-current-buffer "*slime-repl allegro<2>*" (goto-char (point-max)) (insert "(your-form)") (slime-repl-return))`
- **Read SLDB debugger buffers**: `(with-current-buffer "*sldb allegro<2>/N*" (buffer-substring-no-properties (point-min) (min 2000 (point-max))))`
- **Abort debugger**: `(with-current-buffer "*sldb allegro<2>/N*" (sldb-abort))`
- **Avoid `sleep-for` between send and read** — timing is unreliable, just read the buffer and check for a prompt

### File Creation Through Emacs When /projects/ Is Not Directly Writable
Claude's scratch container cannot write to `/projects/`. Create files through Emacs:
```elisp
;; Write initial content
(with-temp-buffer
  (insert "file header...")
  (write-region (point-min) (point-max) "/projects/path/to/new-file.lisp"))

;; Append more content
(with-temp-buffer
  (insert "more content...")
  (append-to-file (point-min) (point-max) "/projects/path/to/new-file.lisp"))
```
This avoids triple-escaping issues when content contains strings with quotes (e.g., JSON in CL).

### Modern-Mode Allegro CL: Case Sensitivity
`genworks-gdl-enterprise-smp` runs modern-mode Allegro CL with `(readtable-case *readtable*)` → `:preserve`.
- Keywords are case-sensitive: `:email` ≠ `:EMAIL`
- When interning strings as keywords, do NOT upcase: `(intern key :keyword)` not `(intern (string-upcase key) :keyword)`
- This affects JSON parsing, property access, and any dynamic symbol creation

### `kill-sexp` for Balanced Replacements
The most reliable pattern for replacing a sexp in Emacs:
```elisp
(goto-char (point-min))
(search-forward "(defun target-function")
(beginning-of-line)
(kill-sexp)
(insert "(defun target-function () ...new balanced body...)")
```
This is safer than region-based deletion because `kill-sexp` guarantees structural correctness.

### AllegroServe: Symbol Names to Know
- `*response-method-not-allowed*` (NOT `*response-not-allowed*`)
- Use `(do-external-symbols ...)` to discover available symbols when unsure
- `gwl:with-all-servers` iterates over `gwl:*http-server*` and `gwl:*https-server*`
- Use `gwl:*http-server*` not `net.aserve:*wserver*` (Franz commandeered the default for their web IDE)

### `*print-readably*` in Error Handlers
Allegro CL's `dumplisp` and build processes can produce conditions containing unprintable objects (byte arrays).
Always bind `*print-readably*` to nil in error handlers:
```lisp
(handler-case (risky-operation)
  (error (c)
    (let ((*print-readably* nil))
      (format t "Error: ~a" c))))
```

## Version History

- **Initial Setup**: Basic container configuration
- **Network Integration**: Added Docker network for container communication
- **SLIME Integration**: Enabled seamless Emacs-to-Gendl SLIME connections
- **HTTP API Setup**: Both containers expose HTTP APIs for external tool integration
- **MCP Migration**: Transitioned from raw HTTP to MCP services for better integration


## Development Lessons Learned

**For detailed lessons learned including:**
- **Shared current buffer footgun and solutions**
- String escaping and code generation best practices
- Interactive prompt handling
- Successful MCP file editing workflows
- Paredit mode workflows
- Error recovery patterns

**See: `dot-files/emacs.d/sideloaded/lisply-backend/CLAUDE.md`**

### Key Takeaway: Shared Buffer State
When using MCP file editing, remember that you **share the global current buffer** with the user. This was discovered during viewport menu development when buffer switching conflicts occurred. Always use explicit buffer targeting with `with-current-buffer` patterns.

### Quick Reference: Safe Patterns
```elisp
;; BAD: Relies on global current buffer
(search-forward "target")

;; GOOD: Explicit buffer targeting
(with-current-buffer "specific-file.lisp"
  (search-forward "target"))
```


## Emacs-Native Tool Preference

**Prefer Emacs native tools over shell commands:**

| Task | Prefer | Avoid |
|------|--------|-------|
| File listing | `(dired-noselect "/path/")` | `(shell-command-to-string "ls")` |
| Git status | `(magit-status)` or `(vc-dir)` | `(shell-command-to-string "git status")` |
| File operations | `(rename-file)`, `(copy-file)` | `(shell-command "mv ...")` |
| Search in files | `(grep-find)`, `(project-find-regexp)` | `(shell-command "grep ...")` |

### Magit as git plumbing from batch elisp (learned 2026-08-13)

Git history perusal (log, show, diff, blame) goes through magit's
plumbing layer via `lisp_eval` — not host-side `git` commands:

```elisp
;; One-time per session: only interactive commands are autoloaded;
;; magit-git-output & friends need the full load.
(require 'magit)

;; Bind default-directory to the repo root (trailing slash), then:
(let ((default-directory "/projects/cyclops/"))
  (magit-git-output "show" "af5e39e" "--" "source/functions.lisp"))
```

Useful plumbing calls, all honoring `default-directory`:
- `(magit-git-output "log" "--oneline" "-10")` — full stdout as one string
- `(magit-git-lines "diff" "--stat" "HEAD~3..")` — stdout as list of lines
- `(magit-git-string "rev-parse" "HEAD")` — first line only
- `(magit-rev-verify "some-branch")`, `(magit-get-current-branch)`

Notes:
- Repos live under `/projects/` inside the container, so any repo the
  host sees at `~/projects/foo` is `/projects/foo/` here.
- `magit-git-output` returns the raw output — no pager, no ANSI, safe
  for batch use. Prefer it over `(magit-status)` in non-interactive
  evals (status pops a buffer the user shares).
- For big diffs, narrow with `-- <path>` per invocation rather than
  post-filtering one giant string.

### Container shell commands from batch elisp (learned 2026-08-13)

The container ships node (prefer it over host node for /projects JS —
e.g. `node --check`).  The lisply guard refuses bare `shell-command`
payloads (a synchronous child wedges the whole Emacs event loop), so
run child processes with an explicit bound:

```elisp
(lisply-shell-bounded "node --check /projects/apps/foo/static/foo.js" 30)
;; => (:exit-code 0 :output "..." :timed-out nil)
```

or `(lisply-shell-async CMD)` + `(lisply-shell-async-result TOKEN)`
for long-running work.

**Host-side line tools are out of bounds for /projects files**: even
when an agent runs on the host with ~/projects
mounted, sed/awk/grep-style edits and filters on project files go
through the skewed-emacs container -- either elisp temp-buffer edits
(insert-file-contents + write-region, never find-file-noselect from
batch evals) or a shell command run inside the container.  Host bash
is a last resort and needs permission.

**Always refresh stale buffers before consulting:**
```elisp
;; Dired: refresh before reading
(with-current-buffer (dired-noselect "/projects/skewed-emacs/")
  (revert-buffer)  ;; Same as pressing 'g' interactively
  ...)

;; File buffers: revert if file changed on disk
(with-current-buffer (find-file-noselect "/path/to/file")
  (when (not (verify-visited-file-modtime (current-buffer)))
    (revert-buffer t t t))
  ...)
```

**Why this matters:**
- Native Emacs tools integrate with the shared buffer state
- Shell commands bypass Emacs's knowledge of file system state
- Dired buffers can become stale; always `(revert-buffer)` before trusting contents


## Critical Best Practices for Claude (Learned 2026-01-04)

### File Path Confusion - Always Use MCP
**WRONG**: Assuming files are in `/mnt/project` (Claude.ai container filesystem)
**RIGHT**: Files in Dave's projects are at `/projects/apps/...` and accessed via skewed-emacs MCP

Example:
```elisp
;; WRONG - trying to use local filesystem
(with-temp-file "/mnt/project/assembly.lisp" ...)

;; RIGHT - use MCP to access Dave's environment
(with-current-buffer (find-file-noselect "/projects/apps/tw-site-2025/source/assembly.lisp")
  ...)
```

**Rule**: If you find yourself creating files in `/home/claude/`, you're doing it wrong. Use skewed-emacs MCP.

### Minibuffer Blocking Issue
**Symptom**: All MCP calls suddenly fail with connectivity errors
**Cause**: Emacs is waiting for minibuffer input (e.g., "File changed on disk. Discard edits? (yes or no)")
**Solution**: Alert Dave that Emacs needs input before continuing

### Event-Loop Blocking: Unbounded Child Processes (2026-07-26 Incident)
**Symptom**: skewed-emacs MCP goes totally dark mid-session — `lisp_eval` AND `ping_lisp` both time out; nothing recovers until the child process dies or the container restarts.
**Cause**: ANY synchronous child process (`shell-command-to-string`, `call-process`, `process-file`) blocks the single Emacs event loop until the child exits. Timers, `with-timeout`, network filters, and the lisply httpd all starve. An unbounded `curl` (no `--max-time`) against a stalled server is exactly as fatal as `sleep-for`. Demonstrated live 2026-07-26: one `(shell-command-to-string "sleep 60")` blacked out the entire transport for 60 s.
**Mandatory rules for every shell-out through lisp_eval**:
- `curl` always gets `--max-time N`
- generic commands get a `timeout(1)` wrapper: `(shell-command-to-string "timeout 30 ...")`
- `ssh` gets BOTH `-o ConnectTimeout=N` AND a `timeout N` wrapper — ConnectTimeout does not bound the remote command
- anything expected to run longer than ~25 s: never run synchronously — use the async helper (`lisply-shell-async` start-process + poll) or nohup + poll via separate calls
- **Backend enforcement (L3)**: a pre-eval lint (`lisply-shell-guard.el`) now refuses unbounded shell payloads, returning a `LISPLY-GUARD REFUSED:` result. Prefer `(lisply-shell-bounded CMD &optional SECS)` (default 25 s, returns `:exit-code/:output/:timed-out` plist). Deliberate override: include the comment `;; lisply:allow-unbounded` in the payload.
- **Guard durability**: as of the 2026-07-26 image rebuild, the guard (`lisply-shell-guard.el` + the `endpoints.el` lint) is baked into the image and survives all container restarts, including autoheal. Cheap sanity probe after any restart: `(fboundp 'lisply-shell-bounded)` should be `t` on a fresh boot with no re-sync.
- **After an autoheal restart**: fully self-healing as of 2026-07-26. The container recovers in ~2 min and the mcp-exec supervise loop respawns all wrapper processes into the recovered container (~2.5 min wedge-to-restored, proven end-to-end). If calls STILL time out after that window, the residual cause is client-side: the Claude Desktop MCP client stops routing to a server after in-flight failures -- a claude.ai session reconnect resumes it (no wrapper or desktop restart needed).
**Relay budget**: the claude.ai MCP relay times out responses at ~35–40 s (Claude Desktop wrapper: ~240 s). Longer evals EXECUTE but report a bare "Tool execution failed" — split work into short calls and poll.
**Recovery runbook (host side)**: `docker exec skewed-emacs ps -ef --forest` → find the stuck child under emacs → `docker exec skewed-emacs pkill -f '<child pattern>'` → service restores instantly (verified: transport recovers the moment the child exits). If no child visible: `docker exec skewed-emacs sh -c 'kill -USR2 $(pgrep -o emacs)'` and read the backtrace from `docker logs`; last resort is container restart.

### Incremental Editing > Wholesale Replacement
**WRONG**: Using `with-temp-file` to rewrite entire complex files
```elisp
(with-temp-file "/path/to/file.lisp"
  (insert "entire new file..."))  ;; Often creates unbalanced parens!
```

**RIGHT**: Make targeted edits with structural navigation
```elisp
(with-current-buffer "file.lisp"
  (when (fboundp 'paredit-mode) (paredit-mode 1))
  (save-excursion
    (goto-char (point-min))
    (search-forward "string-to-find")
    (search-backward "opening-quote")
    (kill-sexp)
    (insert "replacement"))
  (check-parens)
  (save-buffer))
```

### Wholesale Rewrite Done Safely — Build the S-Expression as Elisp Data

The warning above is about the *heredoc-string* approach to wholesale rewrites.
When the task genuinely is to author a new file or wholesale-replace one, there
is a reliable alternative: **build the s-expression as elisp data and let
Emacs serialize it.**

An elisp quoted-list literal is balanced by construction — the elisp reader
refuses to construct an unbalanced list, so syntactic correctness is guaranteed
by the time you call the writer.  CL and elisp share enough surface syntax that
the form round-trips cleanly (keywords, strings, Unicode all survive).

```elisp
(require 'lisply-sexp-write)

(lisply-write-sexp-file
 "/projects/apps/my-app/source/widget.lisp"
 "my-package"
 '((define-object widget (base-html-page)
     :computed-slots
     ((title "Hello")
      (body (with-lhtml-string ()
              ((:h1 :class "text-2xl") "Hello, world")))))))
```

For when to use this vs `kill-sexp`/paredit, how to avoid MCP timeouts on very
large forms by splitting into two calls (`setq` the body, then `lisply-write-
sexp-file` with backtick/comma), and the `lisp_eval`-reads-one-top-level-form
gotcha — see the backend doc:
[`dot-files/emacs.d/sideloaded/lisply-backend/CLAUDE.md`](dot-files/emacs.d/sideloaded/lisply-backend/CLAUDE.md),
section *Structural Authoring via Elisp Data — a Third Path*.


### When Structural Editing Fails
If you're stuck in unbalanced buffer hell:
1. Ask Dave to revert the file: `git checkout path/to/file`
2. Ask Dave to create a placeholder comment where you can insert balanced content
3. Insert the content into the placeholder position

Example workflow that works:
```elisp
;; Dave creates placeholder in buffer:
;;
;; Insert balanced lhtml body here
;;

;; Claude inserts at that position:
(goto-char (point-min))
(search-forward ";; Insert balanced lhtml body here")
(beginning-of-line)
(kill-line 3)  ;; Remove comment
(insert "balanced content...")
```

### LHTML Format (for GDL Web Projects)

GDL uses `with-lhtml-string` for HTML generation. Two syntaxes exist:

**OLD htmlgen compatibility format (extra parens):**
```lisp
((:a :href "url" :class "style") "Link Text")
```

**NEW lhtml native format (cleaner, preferred for new code):**
```lisp
(:a :href "url" :class "style" "Link Text")
```

Use the native format for new code in tw-site-2025 and similar projects.

## Lessons Learned (2026-08-11 Session)

### lisp_eval payloads: avoid literal multi-line strings
Elisp string literals containing REAL newlines inside a `lisp_eval`
payload hung the emacs backend twice (30s no-socket-activity timeout,
edit never applied; single-line equivalents using `\n` escapes applied
instantly).  Until root-caused: keep each `lisp_eval` payload on
single lines and spell newlines as `\n` inside strings.  Also verify
after any timeout whether the edit half-applied: check
`buffer-modified-p` and git status before retrying.

## Lessons Learned (2026-08-07 Session)

### NEVER find-file-noselect Project Source Files from Batch Evals
Opening a source file (e.g. `.gdl`) via `find-file-noselect` in an
emacsclient eval can fire mode hooks that prompt in the minibuffer
(slime-connect and friends) — the daemon blocks on the read and ALL
lisply/emacsclient traffic goes dark.  For read-only checks use
`(with-temp-buffer (insert-file-contents "/path") ...)` — no hooks run.
Balanced-parens check without visiting:
```elisp
(with-temp-buffer
  (insert-file-contents "/path/file.lisp")
  (with-syntax-table lisp-mode-syntax-table (check-parens)))
```
Recovery when the daemon does block and no stuck child shows in
`ps -ef --forest`: `docker restart skewed-emacs` self-heals in ~20 s
(then restart any emacs-managed watcher processes).  Do NOT send
SIGUSR2 + pkill of clients — that combination killed the daemon once.
Full-stack restarts go through `./basilisk down && ./basilisk up`
(use `up --daemon` from scripts to skip the interactive shell exec).

### webshot: Headless-Browser Page Captures (2026-08-07+, all images 2026-08-11+)
`webshot URL [out.png] [WxH] [--mobile] [--settle=MS] [--scale=N] [extra
browser flags]` is baked into all images (source: `docker/webshot`; node
+ CDP since 2026-08-15 -- see the addendum below).  It resolves a browser
at runtime: Debian chromium in the gui/full images, chrome-headless-shell
in the default images (in -lite, `skewed-install headless-shell` provides
it).  **WxH is a REAL viewport**: it is applied via
`Emulation.setDeviceMetricsOverride` before navigation, so page JS and
CSS both see exactly the width you asked for.  `--mobile` additionally
flags the viewport mobile and enables touch emulation.  Captures wait for
the load event and then settle (3.5s default, `--settle=MS`) so x3dom/ajax
finish; WebGL renders via SwiftShader (headless-shell needs
--enable-unsafe-swiftshader, which webshot adds itself), so 3D viewports
appear in captures.  Cache-busting is now built in -- every run gets a
throwaway profile and no disk cache.  For vhost-scoped pages, resolve the
virtual host inside chromium:
```bash
webshot "http://genworks.localhost/demo/staircase" /tmp/s.png 1440x2200 \
  --host-resolver-rules="MAP genworks.localhost cyclops"
```
Host-side agents export binaries without `docker cp` via:
`docker exec skewed-emacs base64 /tmp/s.png | base64 -d > local.png`.

`webshot-clip URL SELECTOR [out.png] [WxH] [pad] [--mobile]
[--settle=MS] [--scale=N] [extra chromium flags]` (source:
`docker/webshot-clip`; node + Chrome DevTools Protocol, no
puppeteer) captures just the first element matching a CSS selector --
hero images, a single card, a viewport region -- using
captureBeyondViewport so below-the-fold elements render fully.  PAD
(px) expands the clip on all sides.  WxH is a REAL viewport, same as
webshot (fixed 2026-08-15; see the addendum below).  Exit codes: 1
usage/bad args, 2 selector not found or zero-area, 3 capture failure,
4 no browser.  Same `--host-resolver-rules`
vhost flag as webshot.  Example (2026-08-09, used for the tw-site-2025
demo hero images):
```bash
webshot-clip "http://genworks.localhost/demo/staircase" ".p-6.relative" \
  /tmp/hero.png 1440x900 0 --host-resolver-rules="MAP genworks.localhost cyclops"
```

These chromium tools are framework-agnostic -- they snapshot ANY web
page under development, not only Gendl/GDL-powered ones.  For
Gendl/GDL GEOMETRY itself the lisply backends additionally carry
native emitters (inline `render_png` MCP tool; standalone drawing
system and `with-format` lenses emitting PDF/PNG/JPEG/SVG/DXF files at
runtime, no browser involved) -- see "Geometry & Image Output
Channels" in gendl/CLAUDE.md (gendl-ccl doc id `claude-gendl-md`).
Keep both channels in mind: chromium for web-app UI iteration, native
emitters for model iteration and runtime file deliverables.

#### Addendum (2026-08-14): output path + cache gotcha
Missed `webshot`/`webshot-clip` entirely this session and hand-rolled
raw `chromium --headless --screenshot=...` calls instead -- future
sessions should reach for the wrapper first, it already solves the
binary-resolution and vhost problems above.  Two things worth folding
back in from the raw-chromium detour:
- **Skip the base64 round-trip**: writing the screenshot straight to
  a path under the /projects bind mount (e.g. `/projects/tmp-shots/`,
  the existing convention) and then reading it via the equivalent
  HOST path (found by checking what the container's /projects bind-
  mounts FROM, e.g. `/home/<user>/projects/tmp-shots/...`) needs no
  `docker cp` and no base64 step at all -- one write, one direct read.
- **Cache gotcha, iterating on the SAME evolving page**: repeated
  headless chromium invocations against a URL you're actively editing
  CSS/JS for can silently serve a stale cached response even though
  the server-side file (and its cache-busting `?v=` mtime) genuinely
  changed -- confirmed by diffing the served CSS text directly against
  what a screenshot rendered.  Force a truly clean fetch every time:
  `--disk-cache-dir=/dev/null --user-data-dir=/tmp/chrome-fresh-$$`
  (a fresh, unique profile dir per invocation).

#### Addendum (2026-08-15): WxH is a real viewport now (webshot is node + CDP)
`webshot` was a bash wrapper around `chromium --headless
--screenshot=... --window-size=W,H`.  Headless chromium does not honor
`--window-size` below roughly 500px: **asking for 390x844 gave the page a
500x701 viewport.**  Measured with `docker/webshot-viewport-probe.html`
(kept in-repo precisely so this stays verifiable):

| | innerWidth | innerHeight | maxTouchPoints | matchMedia(max-width:480px) |
|---|---|---|---|---|
| old, requested 390x844 | 500 | 757 | 0 | **false** |
| new, `390x844 --mobile` | **390** | **844** | **1** | **true** |

Rewritten as node + CDP (the transport `webshot-clip` already used) so
`Emulation.setDeviceMetricsOverride` sets the viewport *before*
navigation.  The CLI contract is unchanged -- new options are FLAGS, not
positionals, specifically so the `--host-resolver-rules` recipe above
keeps working.  `--no-viewport` restores the old geometry for comparison.

**Correct the folklore while you are here.**  The original bug report said
"the CSS media queries never see 390px."  That is not quite what happened,
and the difference decides what to re-check:
- The old `--screenshot=` flag *did* resize the window for the capture, so
  the PNG came out 390x844 and **pure-CSS media queries mostly resolved at
  the right width in the final paint**.  That is exactly why the bug
  survived so long -- the shots were dimensionally plausible and the CSS
  looked right.
- What never ran at 390px is **the page itself**.  All load-time JS
  measured a 500px viewport, so anything JS-driven -- and any layout
  derived from a load-time measurement -- was computed for the wrong
  width, and touch was never emulated at all.  eyes-only, which does JS
  layout, is the prime victim; a pure-CSS page was mostly fine.

So: re-verify JS-driven responsive behavior at phone sizes, not every
stylesheet ever written.  Verification recipe:
```bash
webshot file:///projects/skewed-emacs/docker/webshot-viewport-probe.html \
  /projects/tmp-shots/vp.png 390x844 --mobile
```
The probe prints innerWidth/innerHeight/touch points/matchMedia and colors
a band for the phone (<=480), tablet (481-760) and desktop (>=761) ranges.

**`webshot-clip` caught up the same day.**  It now takes the same
`Emulation.setDeviceMetricsOverride` before navigation and the same
`--mobile` / `--settle=` / `--scale=` / `--no-viewport` flags, verified
with the probe below: `--no-viewport` reproduces 500x701 / touch 0 /
`matchMedia(<=480)` false, the default gives 390x844 / touch 1 / true,
and the clipped `#band` element flips from TABLET (481-760) to PHONE.
The element's own geometry changes with it, which is why this mattered
more for clips than for full pages -- a hero image cropped from a
mis-laid-out page looks perfectly plausible on its own.

Two other things came across from `webshot` in the same pass, both
previously bugs here and not there:
- **DevTools port 0 + `DevToolsActivePort`**, replacing a randomly
  guessed port that could collide with a concurrent run and silently
  attach to the WRONG browser -- screenshotting another job's page.
- **Throwaway profile + `--disk-cache-dir=/dev/null`**, so a CSS/JS file
  you are actively editing is never served stale.
Plus one bug of its own: `process.exit()` inside the CDP body skipped the
cleanup handler, so the selector-not-found path orphaned a whole headless
chromium process tree and its profile directory in the container.  Error
exits now throw with a code so the `finally` still runs.

Still open: `/projects/tmp/split-drag-test.js` is the
companion trick worth folding in -- CDP `Input` events to drive a real
pointer/touch drag and assert the resulting geometry, i.e. proving a page
RESPONDS rather than only renders.

### Long-Running Dev Processes as Emacs-Managed Processes
Watchers (e.g. the tailwind CSS watcher) run as async emacs processes —
visible to the user, no event-loop blocking:
```elisp
(start-process "tailwind-demos-watch" "*tailwind-demos-watch*"
               "sh" "-c" "cd /projects/apps/tailwind && exec npm run dev:demos")
```
They die with the daemon/container — restart them after any restart.
Node/npm live ONLY in the skewed-emacs container, never in gendl/gdl
containers (those consume compiled artifacts from /projects).

### Git Commits from Inside the Container
No git identity or ssh keys exist in the container.  Commit with
explicit identity flags; pushes must happen on the host:
```bash
git -c user.name="..." -c user.email="..." commit -m "..."
```

## Verifying mechanical/bulk edits (2026-08-13 production incident)

After any find/replace or bulk edit, verify by PRESENCE of the correct
result, and compile with warnings VISIBLE.  A `remhash -> remhash-scrubbed`
replace_all glued 12 of 17 arglists (`(remhash-scrubbed fd*request-registry*)`)
and shipped to the production cyclops fleet, because two verifications
lied:

- an **absence-grep** whose exclusion pattern (`remhash-scrubbed `, with
  trailing space) also matched the broken lines, so "no matches" read as
  "clean" when it meant "all broken";
- `ql:quickload ... :silent t`, which suppressed the very
  undefined-variable / wrong-arity warnings that named every broken site.

Rules: (a) grep the edited call sites and READ the resulting lines —
verify presence of the right form, never absence of the mistake; (b)
compile with warnings visible and read them (never `:silent` for a
verification build — on ACL capture compiler output and scan for
undefined-variable/arity warnings); (c) prefer whole-expression old/new
strings over token-splice replacements so whitespace is never
load-bearing.  Corollary: a build that emits warnings you routinely
scroll past will hide the next real one — keep verification builds at
zero warnings.

### Inspecting MCP tool-result dumps (2026-08-13)

When a large `lisp_eval`/`get_docs` result is persisted to
`~/.claude/.../tool-results/*.json`, do NOT reach for host-side
python/grep to search it.  Pull it back through the container instead —
re-request `get_docs` with a narrower id, or fetch/search the text in an
elisp temp-buffer.  General rule: once content originated in the
container's world, keep working it there rather than shelling out on the
host (same principle as the file-ops and syntax-check guidance above).

## Raising a buffer in the user's live eskew session (2026-08-17)

When a piece deserves reading in Emacs rather than chat scroll — a
draft document, a review skeleton, a diff — put it in a buffer and
raise it in the user's attached client frame.  An eskew session is an
emacsclient frame on the shared captain daemon, so anything done to a
buffer via `lisp_eval` is already in the user's Emacs; the only trick
is selecting THEIR frame, not the daemon's initial one:

```elisp
(let ((buf (get-buffer-create "*name the user will recognize*")))
  (with-current-buffer buf
    (erase-buffer)
    (org-mode)                          ; org outlines fold nicely
    (insert "..."))
  (with-selected-frame
      (seq-find (lambda (f) (frame-parameter f 'client)) (frame-list))
    (switch-to-buffer buf)
    (goto-char (point-min))))
```

- The daemon's own frame has `client` nil (`F1`, no tty); an attached
  emacsclient frame has `client` set and a `tty` parameter.  Check
  with `(frame-list)` + `frame-parameter` first; if no client frame
  exists, just create the buffer and say so — the user can `C-x b` to
  it after attaching.
- With several client frames, `seq-find` takes the first; prefer the
  one whose `tty` matches where the user says they are, or fall back
  to telling them the buffer name.
- Give buffers stable, greppable names (`*canon rebuild: ...*`) so a
  later `C-x b` completes them easily.
- First live use: a document-skeleton review during a 2026-08-17
  session — worked on the first try.
