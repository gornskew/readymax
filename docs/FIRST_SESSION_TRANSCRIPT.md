# A First Session: Building a Staircase Through MCP

This is a lightly edited transcript of a real first session: Claude
(via Claude Desktop) connected to a freshly started skewed-emacs
container stack, talking to the `skewed-emacs` (Emacs) and `gendl-ccl`
(Gendl/Common Lisp) MCP servers. Every tool call and result below is
genuine — captured live, trimmed only for brevity.

The stack was started with nothing but:

```bash
./basilisk up
```

---

**User:** Say hello to my Emacs, then build me a staircase in Gendl.
I have 3.1 meters of rise and 3.9 meters of run to work with, and I
want treads of 2x6 deck lumber.

**Claude:** I'll start by saying hello to Emacs, then set up a
parametric staircase model in Gendl.

*Tool call — `skewed-emacs__lisp_eval`:*

```elisp
(with-current-buffer "*scratch*"
  (goto-char (point-max))
  (insert "\n;; Hello from your AI agent — this text was typed via MCP.\n")
  (format "Emacs %s says hello. *scratch* is now %d chars long."
          emacs-version (buffer-size)))
```

```
Result: "Emacs 30.1 says hello. *scratch* is now 207 chars long."
```

Emacs is live — check your `*scratch*` buffer. Now the staircase.
I'll define it as a Gendl object: you give it a total rise and run,
and it *computes* how many steps you need, keeping every riser under a
building-code-style limit, and lays out the treads in space.

*Tool call — `gendl-ccl__lisp_eval`:*

```lisp
(define-object staircase (base-object)

  :documentation (:description "Parametric straight-run staircase sized to
code-style constraints. Give it a total rise and run; it computes how many
steps you need and lays out treads of 2x6 deck lumber.")

  :input-slots
  ((total-rise 2600 :settable)      ;; floor-to-floor height, mm
   (total-run 3300 :settable)       ;; horizontal span, mm
   (tread-width 900 :settable)      ;; stair width, mm
   (max-riser-height 190 :settable) ;; building-code style limit, mm
   (tread-thickness 38)             ;; 2x6 deckwood, mm
   (board-width 140))               ;; 2x6 actual width, mm

  :computed-slots
  ((number-of-risers (ceiling (the total-rise) (the max-riser-height)))
   (riser-height (/ (the total-rise) (the number-of-risers)))
   (number-of-treads (1- (the number-of-risers)))
   (tread-depth (/ (the total-run) (the number-of-treads)))
   (boards-per-tread (ceiling (the tread-depth) (the board-width))))

  :objects
  ((treads :type 'box
           :sequence (:size (the number-of-treads))
           :width (the tread-width)
           :length (the tread-depth)
           :height (the tread-thickness)
           :center (translate (the center)
                              :up (* (the riser-height) (1+ (the-child index)))
                              :rear (* (the tread-depth) (+ 1/2 (the-child index)))))))
```

```
Result: #<GDL-CLASS STAIRCASE>
```

The object is defined. Notice there's no staircase *yet* — just
knowledge about staircases. Let me instantiate one and interrogate it:

*Tool call — `gendl-ccl__lisp_eval`:*

```lisp
(progn
  (setq self (make-object 'staircase))
  (list :risers (the number-of-risers)
        :riser-height (coerce (the riser-height) 'double-float)
        :treads (the number-of-treads)
        :tread-depth (coerce (the tread-depth) 'double-float)
        :boards-per-tread (the boards-per-tread)
        :first-tread-center (the (treads 0) center)
        :last-tread-center (the (treads 12) center)))
```

```
Result: (:RISERS 14 :RISER-HEIGHT 185.71428571428572
         :TREADS 13 :TREAD-DEPTH 253.84615384615384
         :BOARDS-PER-TREAD 2
         :FIRST-TREAD-CENTER #(0.0 126.923... 185.714...)
         :LAST-TREAD-CENTER  #(0.0 3173.076... 2414.285...))
```

With the default 2.6m rise: 14 risers of ~185.7mm (under the 190mm
limit), 13 treads of ~254mm depth, each needing 2 boards of 2x6.
Every tread already has real 3D coordinates.

Now your actual dimensions — 3.1m rise, 3.9m run. I don't rebuild
anything; I just change the inputs, and Gendl's dependency tracking
recomputes whatever is affected:

*Tool call — `gendl-ccl__lisp_eval`:*

```lisp
(progn
  (the (set-slot! :total-rise 3100))
  (the (set-slot! :total-run 3900))
  (list :risers (the number-of-risers)
        :riser-height (coerce (the riser-height) 'double-float)
        :treads (the number-of-treads)
        :tread-depth (coerce (the tread-depth) 'double-float)
        :boards-per-tread (the boards-per-tread)
        :top-tread-elevation
        (coerce (get-z (the (treads 15) center)) 'double-float)))
```

```
Result: (:RISERS 17 :RISER-HEIGHT 182.35294117647058
         :TREADS 16 :TREAD-DEPTH 243.75
         :BOARDS-PER-TREAD 2
         :TOP-TREAD-ELEVATION 2917.6470588235293)
```

Your staircase: **17 risers at 182.4mm, 16 treads at 243.8mm** — the
riser height stayed legal automatically. One more question the model
can answer: what do you buy at the lumber yard?

*Tool call — `gendl-ccl__lisp_eval`:*

```lisp
(let* ((boards-per-tread (the boards-per-tread))
       (n (the number-of-treads))
       (board-length-m (/ (the tread-width) 1000.0))
       (total-boards (* n boards-per-tread))
       (total-linear-m (* total-boards board-length-m)))
  (format nil "~a boards of 2x6 at ~,1fm each = ~,1f linear meters of deck lumber"
          total-boards board-length-m total-linear-m))
```

```
Result: "32 boards of 2x6 at 0.9m each = 28.8 linear meters of deck lumber"
```

**Claude:** Done. You need **32 boards of 0.9m 2x6 — about 29 linear
meters** — for a 17-riser staircase whose geometry is fully computed
and queryable. To see it in 3D, open Gendl's web-based development
browser, **geysr**, at
[http://localhost:9080/geysr](http://localhost:9080/geysr) and
instantiate `staircase`. Change `total-rise` there — or ask me to —
and everything downstream updates: step count, tread layout, shopping
list.

---

## What just happened

- The agent never edited a file, ran a build, or restarted anything —
  it *conversed with a live Lisp machine*, defining and refining a
  running model incrementally. That is the REPL workflow Lisp people
  have always had, now driveable by any MCP-capable agent.
- Two different Lisp environments (Emacs elisp and Gendl Common Lisp)
  were driven through the same uniform tool protocol
  (`lisp_eval` / `http_request` / `ping_lisp`), served by
  [lisply-mcp](https://github.com/gornskew/lisply-mcp).
- Everything ran inside the container sandbox that `./basilisk up`
  started; the host machine was never touched.

Try it yourself: any MCP client works. See the README Quick Start for
the two-minute setup.
