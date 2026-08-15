;;; fittings.sexp - the Basilisk fitting catalogue
;;; -*- mode: lisp-data; -*-
;;;
;;; Every ship in this fleet is a BASILISK-CLASS ship.  They differ not by
;;; class but by COMPLEMENT -- who is aboard.  This file is the one place
;;; that says what each post actually means in container terms, so a host's
;;; services.sexp can name posts symbolically instead of restating service
;;; definitions.  See skewed-emacs/BASILISK.md and apps/eyes-only/THEMES.md.
;;;
;;; A post may also carry a :probe, which says what that post looks like to
;;; the Eyes Only board.  Because the probe list is then derived from each
;;; ship's ROSTER, a crew member who is not aboard cannot be probed for, and
;;; so cannot present as a permanently red tile (shelly, 2026-08-14).
;;;
;;; A host declares EITHER a :crew-level (coarse) or a :roster (specific)
;;; in its services.sexp :meta.  Level expands to roster; roster infers
;;; level.  Its own :services then carries only genuine deviation, merged
;;; sparsely over what expansion produced.
;;;
;;; {{STACK}} is substituted at GENERATION time with the stack's short name,
;;; derived from the output directory (narad-stack -> narad).  Deliberately
;;; not a runtime env var: one catalogue serves every ship without anything
;;; needing to be defined in .env.
;;;
;;; :in-base t marks a post already defined by the vanilla skewed-emacs
;;; docker-compose.yml.  The roster still names it -- it describes the whole
;;; ship -- but an OVERLAY emits only the delta, so those are skipped when
;;; generating with a prefix.

(
 :posts
 (
  ;; ---- Always aboard.  A Basilisk without a Cap'n is not a Basilisk
  ;; (Dave, 2026-08-15); the generator refuses a roster lacking :captain.
  (:post :captain
   :in-base t
   :description "The ship's console, and the longest-lived process aboard."
   :services ((:name "skewed-emacs"))
   ;; :in-stack is the ONLY sanctioned routing for the :emacs kind --
   ;; emacs lisply has no token gate, so it never rides a public path.
   ;; Off-ship, the Cap'n is sampled through that stack's own gendl-ccl
   ;; proxy (publish-emacs-metrics!), which is gated.
   :probe (:tile "heap skewed-emacs"
           :in-stack (:kind :emacs
                      :url "http://skewed-emacs:7080/lisply/lisp-eval"
                      :alert-mb 2000)
           :remote (:kind :metrics
                    :path "/eyes-only-metrics/skewed-emacs"
                    :alert-mb 2000)))

  (:post :ship-engineers
   :in-base t
   :description "Two small, competent, collegial engineering departments."
   :services ((:name "gendl-ccl") (:name "gendl-sbcl"))
   ;; One probe, not two: gendl-ccl carries the metrics publisher;
   ;; gendl-sbcl publishes nothing, so there is no tile to ask for.
   ;; No :in-stack form either -- a board self-samples its own image
   ;; (the heap gendl-ccl tile) without a probe entry.
   :probe (:tile "heap gendl-ccl"
           :remote (:kind :metrics
                    :path "/eyes-only-metrics/gendl-ccl"
                    :alert-mb 1200)))

  (:post :medic
   :in-base t
   :description "Watches for the wedged and revives them."
   :services ((:name "autoheal")))

  ;; ---- Optional.  A Pilot can be taken out while the ship sails on.
  (:post :pilot
   :description "At the conn: every packet enters through the Cyclops."
   :services
   ((:name "cyclops"
     :type "reverse-proxy"
     :lisp-impl "AllegroCL-Runtime"
     :image "gornskew/cyclops:master"
     :ports ((:name "http" :container 80 :host ${CYCLOPS_HOST_PORT:-19069})
             (:name "utility" :container 9191 :host 19191))
     :volumes ((:source "${CYCLOPS_CONFIG:-${PROJECTS_DIR}/{{STACK}}-stack/cyclops-{{STACK}}.sexp}"
                :target "/etc/cyclops/cyclops.sexp"
                :mode "ro"))
     :mcp t
     :extra-hosts (("host.docker.internal" . "host-gateway"))
     :healthcheck (:endpoint "/_cyclops/status" :interval "30s"))))

  ;; ---- Optional.  Commissioned units, competent if sometimes arrogant,
  ;; to standards imposed by central Guild authorities.
  (:post :guild
   :description "A Guild engineering detachment: two commissioned GDL units."
   :probe (:tile "heap gdl-enterprise"
           :remote (:kind :metrics
                    :path "/eyes-only-metrics/gdl-enterprise"
                    :alert-mb 512))
   :services
   ((:name "genworks-gdl-enterprise-smp"
     :type "common-lisp"
     :lisp-impl "AllegroCL-SMP-Enterprise"
     :image "genworks/gdl:devo-enterprise-smp-licensed"
     :ports ((:name "http" :container 9098 :host 9098)
             (:name "swank" :container 4218))
     :mcp t
     :volumes ((:source "${PROJECTS_DIR}/{{STACK}}-stack/gdl-services-init.cl"
                :target "/home/gdl-user/gdl-services-init.cl"
                :mode "ro"))
     :healthcheck (:endpoint "/lisply/ping-lisp" :interval "30s"))

    (:name "genworks-gdl-enterprise-non-smp"
     :type "common-lisp"
     :lisp-impl "AllegroCL-Enterprise"
     :image "genworks/gdl:devo-enterprise-non-smp-licensed"
     :ports ((:name "http" :container 9088)
             (:name "swank" :container 4208))
     :mcp t
     :healthcheck (:endpoint "/lisply/ping-lisp" :interval "48s")))))

 ;; Named points in roster-space.  Inference takes the HIGHEST level whose
 ;; roster is a subset of the actual one; the remainder reports as deltas,
 ;; and a roster matching nothing is :custom -- a first-class outcome, not
 ;; an error, or this stops describing ships we actually build.
 :crew-levels
 ((:level :standard :roster (:captain :ship-engineers :medic))
  (:level :piloted  :roster (:captain :ship-engineers :medic :pilot))
  (:level :guild    :roster (:captain :ship-engineers :medic :pilot :guild)))

 ;; Omissions that are legal but worth saying out loud once.  :captain is
 ;; absent from this table deliberately: it is an error, not a warning.
 :warnings
 ((:post :pilot  :when-absent "no Pilot: nothing fronts HTTP; publish ports directly")
  (:post :medic  :when-absent "no Medic: no steady-state autoheal")
  (:post :guild  :when-absent "no Guild detachment: community engines only")))
