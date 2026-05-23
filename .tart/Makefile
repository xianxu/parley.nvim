# Tart-VM management — included from Makefile.workflow:
#   -include .tart/Makefile
#
# Provides:
#   make tart        cold-boot $(TART_VM) headless (stops first if
#                    running), prepare an APFS clone of $(CURDIR) at
#                    /tmp/$(TART_VM)-clone (cp -cR; O(1) on APFS),
#                    mount it writable at /Volumes/My Shared
#                    Files/$(REPO_NAME), ssh in. ~/repo in the VM is
#                    a symlink to the writable share. Cold-boot is
#                    the default for mount-cache freshness — see
#                    ariadne#28 for why. Clone-based share is the
#                    successor to rsync — see ariadne#29.
#   make tart-gui    same but display via macOS Screen Sharing.app
#                    (--vnc; built-in UI is broken on macOS Tahoe)
#   make tart-stop   stop $(TART_VM); remove its clone
#   make tart-clean  stop + delete $(TART_VM) + remove its clone
#                    (base image stays cached)
#
# Mount is on by default in every boot target. The mount serves only as
# the rsync source — `tart-vm-setup.sh` mirrors it into ~/repo on every
# boot via rsync --delete, so the VM's ~/repo is a byte-for-byte copy
# of the host worktree (including .git and uncommitted/untracked files).
# Any VM-local edits to ~/repo are wiped on next boot — keep persistent
# work outside ~/repo (e.g. ~/workspace/, ~/brain-*).
#
# This replaces two earlier layouts: ~/repo-as-symlink (broke `make
# build` with EPERM from host xattrs on bin/) and ~/repo-as-git-clone
# (only picked up committed host state, missed uncommitted edits).
# Override RUN_FLAGS empty for a true no-mount, no-mirror boot:
#   make tart RUN_FLAGS=
#
# Auto-derived per repo via $(REPO_NAME):
#   - TART_VM defaults to <repo>-test (one VM per consuming repo).
#     Override the suffix with TART_SUFFIX for parallel VMs in the
#     same repo: `make tart TART_SUFFIX=emma` in pair → pair-emma.
#     Full TART_VM=… override is still supported for cases the
#     suffix shorthand doesn't model.
#   - Mount tag and mount path inside the VM both default to <repo>
#
# Cache (~/.tart/cache, ~/.tart/vms) is system-wide and shared across
# every repo on this Mac — pulling the OCI image once is enough; only
# per-VM clones (4-8 GB diff after some use) accumulate per repo.
#
# Apple Silicon only (Tart uses Apple Virtualization framework).
# Operator must `brew install cirruslabs/cli/tart`; sshpass + fzf are
# recommended but not required — see scripts/tart-*.sh for fallbacks.

TART_BASE      ?= ghcr.io/cirruslabs/macos-tahoe-base:latest
# Default: <repo>-test. Override the suffix with TART_SUFFIX for
# parallel VMs in the same repo (TART_SUFFIX=emma → <repo>-emma).
# Full TART_VM=… override still bypasses suffix logic entirely.
TART_VM        ?= $(REPO_NAME)-$(or $(TART_SUFFIX),test)
# --no-graphics by default; tart-gui overrides to --vnc to delegate
# display to macOS Screen Sharing.app. Tart's built-in UI is broken
# on macOS Tahoe (tart registers as a GUI app via Cmd-Tab but never
# creates a visible window — silent failure, no crash, no log). --vnc
# routes through Screen Sharing.app and works reliably. Display mode
# is a cold-boot setting, so tart-gui force-restarts a running
# headless VM.
#
# When tart upstream fixes the Tahoe built-in-UI bug, the workaround
# can be removed by setting GRAPHICS_FLAG := (empty) for tart-gui.
GRAPHICS_FLAG  ?= --no-graphics

# Host-side APFS clone of the repo, used as the VM's writable share
# (ariadne#29). cp -cR is metadata-only on APFS — initial cost is O(1)
# regardless of repo size, and VM writes diverge into the clone via
# COW without touching the source. Replaces the previous rsync-into-
# VM-local-fs workflow.
#
# Path choice: ~/.tart/clones/ rather than /tmp. macOS's Virtualization
# framework + tart's app sandbox refuse to expose paths under
# /private/tmp (the canonical /tmp target) as VirtIO-FS shares — boot
# fails with "A directory sharing device configuration is invalid /
# No such file or directory" even when the path concretely exists.
# ~/.tart is already a tart-managed directory (used for cached OCI
# images + VM disks) and is on the framework's whitelist by virtue of
# tart's TCC permissions for its own state dir.
TART_CLONE_DIR ?= $(HOME)/.tart/clones/$(TART_VM)-clone

# Bind-mount the clone into the VM at the canonical tag. Writable by
# default — tart's `--dir` syntax is `<name>:<path>` (writable) or
# `<name>:<path>:ro` (read-only). There's no `:rw` suffix; passing one
# makes tart treat ":rw" as part of the path, which then fails to
# resolve (VZErrorDomain Code=2 "No such file or directory").
# Overridable to empty on the command line for a no-mount boot.
RUN_FLAGS      ?= --dir=$(REPO_NAME):$(TART_CLONE_DIR)

.PHONY: tart tart-gui tart-stop tart-clean help-tart

help-tart:
	@printf '%s\n' \
	"Tart (macOS VMs):" \
	"  make tart           Cold-boot $(TART_VM) headless (stops first if running)," \
	"                      prepare APFS clone of \$$(CURDIR) at /tmp/$(TART_VM)-clone," \
	"                      mount it writable at /Volumes/My Shared Files/$(REPO_NAME)," \
	"                      ssh in. ~/repo in the VM symlinks to the writable share." \
	"                      Cold-boot is the default for mount-cache freshness (ariadne#28)." \
	"                      Clone-based share is the successor to rsync (ariadne#29)." \
	"                      To attach without restart, ssh directly." \
	"  make tart-gui       Same but display via macOS Screen Sharing.app" \
	"  make tart-stop      Stop $(TART_VM) + remove its clone" \
	"  make tart-clean     Stop + delete $(TART_VM) + remove its clone (base stays cached)" \
	"" \
	"  Writes in the VM diverge into the APFS clone via COW; host source" \
	"  ($(CURDIR)) stays untouched. Clone wipes on tart-stop / next boot." \
	"  Skip the mount entirely with 'make tart RUN_FLAGS=' for a vanilla boot." \
	"" \
	"  Parallel VMs per repo: 'make tart TART_SUFFIX=emma' → $(REPO_NAME)-emma" \
	"  (each VM gets its own clone at /tmp/$(REPO_NAME)-emma-clone)." \
	""

# Interactive multi-select to stop OTHER running tart VMs (4-8 GB
# resident each; easy to leave one from a prior repo running).
# Implementation in .tart/scripts/tart-stop-others.sh — fzf when
# available, y/N fallback otherwise, no-op in non-tty contexts.
# Default is always "stop nothing" — Enter with no selection, or
# Esc, both keep all VMs running.
define _tart_check_others
	@bash $(CURDIR)/.tart/scripts/tart-stop-others.sh $(TART_VM) $(TART_BASE)
endef

# _tart_prepare_clone: APFS-clone $(CURDIR) → $(TART_CLONE_DIR) and
# strip the dirs that would carry codesign / provenance xattrs (the
# previous rsync did this via --exclude). Also strips ariadne-local
# state files (.nous-mode, .nous-plugins) that are operator-host-
# specific and shouldn't propagate to the VM.
#
# cp -cR uses clonefile(2) under the hood on APFS — metadata-only,
# O(1) regardless of repo size. Falls back to plain cp -R if
# clonefile fails for any reason (rare; non-APFS volume, etc.).
define _tart_prepare_clone
	@echo "==> Preparing APFS clone at $(TART_CLONE_DIR) (write-isolated; replaces rsync)..."
	@mkdir -p "$(dir $(TART_CLONE_DIR))"
	@rm -rf "$(TART_CLONE_DIR)"
	@if ! cp -cR "$(CURDIR)" "$(TART_CLONE_DIR)" 2>/dev/null; then \
	    echo "  [warn] cp -cR (clonefile) failed; falling back to plain cp -R"; \
	    cp -R "$(CURDIR)" "$(TART_CLONE_DIR)"; \
	fi
	@rm -rf "$(TART_CLONE_DIR)/bin" "$(TART_CLONE_DIR)"/cmd/*/bin
	@rm -f  "$(TART_CLONE_DIR)/.nous-mode" "$(TART_CLONE_DIR)/.nous-plugins"
	@echo "  cloned + stripped build artifacts"
endef

# _tart_gc_orphan_clones: remove any ~/.tart/clones/*-clone older than
# 7 days. Safety net for the force-kill case (operator ^C's tart
# mid-boot, tart-stop doesn't fire, the clone leaks). 7d threshold is
# conservative — a legitimately-active VM's clone gets refreshed on
# every cold-boot so its mtime stays current. mtime works on
# directories created by cp -cR; APFS preserves it as the clone
# instant.
define _tart_gc_orphan_clones
	@if [ -d "$(HOME)/.tart/clones" ]; then \
	    find "$(HOME)/.tart/clones" -maxdepth 1 -name '*-clone' -type d -mtime +7 -prune 2>/dev/null \
	        -exec rm -rf {} \; 2>/dev/null || true; \
	fi
endef

# _tart_cleanup_clone: remove the specific clone for $(TART_VM).
# Called from tart-stop / tart-clean. Idempotent (silent no-op
# when the clone doesn't exist).
define _tart_cleanup_clone
	@rm -rf "$(TART_CLONE_DIR)"
endef

# `tart stop` returns after sending shutdown, but tart list's State
# column doesn't always reflect "stopped" instantly — there's a brief
# window where it still reads "running". If _tart_boot_and_ssh runs
# during that window, its state guard skips the boot (which means no
# new tart run process, no log output, no GUI window — and ssh polling
# either times out or attaches to the dying-but-not-dead VM, leaving
# no obvious failure signal).
#
# Poll for the transition. 15s ceiling matches the longest delay seen
# in practice; if state is still "running" after that, the cold-boot
# branch wouldn't help anyway and we fall through.
define _tart_wait_for_stop
	@for i in $$(seq 1 15); do \
	    state=$$(tart list 2>/dev/null | awk -v vm=$(TART_VM) '$$2==vm {print $$NF}'); \
	    if [ "$$state" != "running" ]; then break; fi; \
	    sleep 1; \
	done
endef

# Common preamble: tart present, base pulled, VM cloned (idempotent).
define _tart_ensure_vm
	@command -v tart >/dev/null || \
	    { echo "Install tart: brew install cirruslabs/cli/tart"; exit 1; }
	@if ! tart list --source local -q 2>/dev/null | grep -qx $(TART_VM); then \
	    echo "==> Pulling $(TART_BASE) (cached at ~/.tart/cache/, shared with other repos)..."; \
	    tart pull $(TART_BASE); \
	    echo "==> Cloning to $(TART_VM)..."; \
	    tart clone $(TART_BASE) $(TART_VM); \
	fi
endef

# Boot in background (no-op if already running), poll for SSH, then
# install pubkey (if needed), push tart-vm-rc + setup.sh (if present),
# and exec ssh -t for an interactive shell. RUN_FLAGS lets tart-mount
# inject --dir without duplicating the rest of the recipe.
#
# Gate the boot decision on `tart list`'s State column, not on
# `tart ip`. Tart caches the last-known IP for a stopped VM, so
# `tart ip` succeeds even when the VM isn't running.
define _tart_boot_and_ssh
	@state=$$(tart list 2>/dev/null | awk -v vm=$(TART_VM) '$$2==vm {print $$NF}'); \
	if [ "$$state" != "running" ]; then \
	    echo "==> Booting VM..."; \
	    nohup tart run $(GRAPHICS_FLAG) $(RUN_FLAGS) $(TART_VM) >/tmp/tart-$(TART_VM).log 2>&1 & \
	fi
	@echo "==> Waiting for SSH..."
	@for i in $$(seq 1 60); do \
	    ip=$$(tart ip $(TART_VM) 2>/dev/null); \
	    if [ -n "$$ip" ] && nc -z -G 2 "$$ip" 22 2>/dev/null; then break; fi; \
	    sleep 2; \
	done
	@ip=$$(tart ip $(TART_VM)); \
	    if ! nc -z -G 2 "$$ip" 22 2>/dev/null; then \
	        if grep -q "exceeds the system limit" /tmp/tart-$(TART_VM).log 2>/dev/null; then \
	            echo "==> Boot failed: Apple's 2-macOS-VM cap reached."; \
	            echo "    Stop another macOS VM first ('tart list' to see them,"; \
	            echo "    'tart stop <name>' to stop one), then retry."; \
	            exit 1; \
	        fi; \
	        echo "==> SSH never came up at $$ip (boot log: /tmp/tart-$(TART_VM).log)"; \
	        exit 1; \
	    fi; \
	    pubkey=$$(ls ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa.pub 2>/dev/null | head -1); \
	    if [ -n "$$pubkey" ] && ! ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	            -o BatchMode=yes -o ConnectTimeout=3 admin@$$ip true 2>/dev/null; then \
	        echo "==> Installing $$pubkey for passwordless ssh (one-time per VM)..."; \
	        if command -v sshpass >/dev/null; then \
	            sshpass -p admin ssh-copy-id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	                -i "$$pubkey" admin@$$ip >/dev/null 2>&1; \
	        else \
	            echo "    (sshpass not installed → interactive prompt; install with"; \
	            echo "     'brew install hudochenkov/sshpass/sshpass' to make this silent)"; \
	            ssh-copy-id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	                -i "$$pubkey" admin@$$ip; \
	        fi; \
	    fi; \
	    if [ -f "$(CURDIR)/.tart/scripts/tart-vm-rc.zsh" ] && [ -f "$(CURDIR)/.tart/scripts/tart-vm-setup.sh" ]; then \
	        scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	            "$(CURDIR)/.tart/scripts/tart-vm-rc.zsh"    admin@$$ip:.tart-vm-rc.zsh; \
	        scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	            "$(CURDIR)/.tart/scripts/tart-vm-setup.sh" admin@$$ip:.tart-vm-setup.sh; \
	        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null admin@$$ip \
	            'bash ~/.tart-vm-setup.sh'; \
	    fi; \
	    echo "==> ssh admin@$$ip"; \
	    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	        -t admin@$$ip \
	        'export TERM=xterm-256color; stty erase "^?"; exec $$SHELL -l' \
	        || true
endef
# `|| true` on the ssh: ssh propagates the remote shell's exit status.
# When the VM user types `exit`, zsh returns $? from its last automatic
# command (commonly non-zero from compinit / /etc/zshrc on fresh macOS).
# That's a normal session-ended event, not a make failure — swallow it.

tart:
	$(call _tart_check_others)
	$(call _tart_ensure_vm)
	@# Cold-boot for fresh VirtIO-FS mount. macOS's host-guest directory
	@# share caches dentries/inodes guest-side and diverges from the
	@# host over time — git's atomic-rename writes are especially
	@# affected (rename(2) changes the inode; the guest's cached
	@# dentry still points at the old/deleted inode → stale reads,
	@# sometimes empty content). Cost: ~30s extra per invocation.
	@# Benefit: ~/repo on the VM always reflects the host worktree's
	@# current state. See ariadne#28 for the bug that motivated the
	@# default. Operators who want to ssh into a running VM without
	@# restart should `ssh admin@$$(tart ip <name>)` directly rather
	@# than re-running `make tart`.
	@if tart list 2>/dev/null | awk -v vm=$(TART_VM) '$$2==vm {print $$NF}' | grep -qx running; then \
	    echo "==> Cold-restarting VM to refresh host mount (VirtIO-FS cache invalidation)..."; \
	    tart stop $(TART_VM); \
	fi
	$(call _tart_wait_for_stop)
	$(call _tart_gc_orphan_clones)
	$(call _tart_prepare_clone)
	@if [ -n "$(RUN_FLAGS)" ]; then \
	    echo "==> Share: /Volumes/My Shared Files/$(REPO_NAME) (writable; APFS clone)"; \
	    echo "    VM-side ~/repo symlinks to it. Writes diverge into the clone via APFS"; \
	    echo "    COW; host source ($(CURDIR)) untouched. Clone wipes on tart-stop / next boot."; \
	fi
	$(call _tart_boot_and_ssh)

tart-gui: GRAPHICS_FLAG := --vnc
tart-gui:
	$(call _tart_check_others)
	$(call _tart_ensure_vm)
	@# Display mode is a cold-boot setting; can't be hot-attached to a
	@# running VM. If the VM is up headless (e.g., from a prior
	@# `make tart`), stop it so the next boot picks up --vnc.
	@if tart list 2>/dev/null | awk -v vm=$(TART_VM) '$$2==vm {print $$NF}' | grep -qx running; then \
	    echo "==> Stopping VM to switch to VNC mode (cold-boot only setting)..."; \
	    tart stop $(TART_VM); \
	fi
	$(call _tart_wait_for_stop)
	$(call _tart_gc_orphan_clones)
	$(call _tart_prepare_clone)
	@echo "==> Booting with VNC display + APFS-cloned share"
	@echo "    Share: /Volumes/My Shared Files/$(REPO_NAME) (writable; APFS clone at $(TART_CLONE_DIR))"
	@echo "    First-time Screen Sharing: choose 'Standard' in the"
	@echo "    network-type dialog — 'High Performance' is incompatible"
	@echo "    with tart's VNC stream on Tahoe (Screen Sharing remembers"
	@echo "    the choice after the first connection)."
	$(call _tart_boot_and_ssh)

tart-stop:
	@if tart ip $(TART_VM) >/dev/null 2>&1; then tart stop $(TART_VM); fi
	$(call _tart_cleanup_clone)

tart-clean: tart-stop
	@if tart list --source local -q 2>/dev/null | grep -qx $(TART_VM); then \
	    tart delete $(TART_VM); \
	fi
	$(call _tart_cleanup_clone)
