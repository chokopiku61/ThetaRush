import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "thetarush-sidebar-collapsed"
const DESKTOP_MQ = "(min-width: 52.01rem)"
// Phase A (fold up) + Phase B (extend right); chevron rotates across the full span.
const PHASE_MS = 400

// Mobile: off-canvas hamburger. Desktop: fold nav under logo, then pin + chevron strip right.
export default class extends Controller {
  static targets = ["panel", "toggle", "backdrop", "shell", "collapse"]

  connect() {
    this.onKeydown = this.onKeydown.bind(this)
    this.onResize = this.onResize.bind(this)
    this.onShellTransitionEnd = this.onShellTransitionEnd.bind(this)
    this.phaseTimer = null
    this.animating = false
    document.addEventListener("keydown", this.onKeydown)
    window.addEventListener("resize", this.onResize)
    if (this.hasShellTarget) {
      this.shellTarget.addEventListener("transitionend", this.onShellTransitionEnd)
    }

    if (this.isDesktop && this.readStoredCollapsed()) {
      this.setCollapsedImmediate(true)
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    window.removeEventListener("resize", this.onResize)
    if (this.hasShellTarget) {
      this.shellTarget.removeEventListener("transitionend", this.onShellTransitionEnd)
    }
    this.clearPhaseTimer()
    this.setOpen(false)
  }

  toggle() {
    this.setOpen(!this.isOpen)
  }

  open() {
    this.setOpen(true)
  }

  close() {
    this.setOpen(false)
  }

  toggleCollapse() {
    if (!this.isDesktop || this.animating) return
    this.setCollapsed(!this.isFullyCollapsed)
  }

  get isOpen() {
    return this.element.classList.contains("app-shell--sidebar-open")
  }

  get isFullyCollapsed() {
    return this.hasPanelTarget && this.panelTarget.classList.contains("sidebar--collapsed")
  }

  get isDesktop() {
    return window.matchMedia(DESKTOP_MQ).matches
  }

  setOpen(open) {
    this.element.classList.toggle("app-shell--sidebar-open", open)

    if (this.hasToggleTarget) {
      this.toggleTarget.setAttribute("aria-expanded", String(open))
    }
    if (this.hasBackdropTarget) {
      this.backdropTarget.hidden = !open
    }
  }

  clearPhaseTimer() {
    if (this.phaseTimer != null) {
      window.clearTimeout(this.phaseTimer)
      this.phaseTimer = null
    }
  }

  // Skip animation (initial restore from localStorage).
  setCollapsedImmediate(collapsed) {
    this.clearPhaseTimer()
    this.animating = false
    if (!this.hasPanelTarget) return

    this.panelTarget.classList.remove("sidebar--folding", "sidebar--unfolding")
    this.panelTarget.classList.toggle("sidebar--collapsed", collapsed)
    this.panelTarget.classList.toggle("sidebar--chevron-collapsed", collapsed)
    if (this.hasShellTarget) {
      this.shellTarget.classList.toggle("app-shell--sidebar-collapsed", collapsed)
    }
    this.syncCollapseControl(collapsed)
    this.nudgeLayout()
  }

  setCollapsed(collapsed, { persist = true } = {}) {
    if (!this.hasPanelTarget) return

    this.clearPhaseTimer()
    this.animating = true

    if (collapsed) {
      this.collapsePhased(persist)
    } else {
      this.expandPhased(persist)
    }
  }

  // Phase A: fold rail up under fixed logo. Phase B: extend strip to the right.
  collapsePhased(persist) {
    const panel = this.panelTarget
    panel.classList.remove("sidebar--unfolding", "sidebar--collapsed")
    panel.classList.add("sidebar--folding")
    // Chevron rotates across the full A+B window.
    panel.classList.add("sidebar--chevron-collapsed")
    // Start shell spacer transition with Phase A so main width eases across A+B.
    if (this.hasShellTarget) {
      this.shellTarget.classList.add("app-shell--sidebar-collapsed")
    }
    this.syncCollapseControl(true)

    this.phaseTimer = window.setTimeout(() => {
      panel.classList.remove("sidebar--folding")
      panel.classList.add("sidebar--collapsed")
      this.phaseTimer = window.setTimeout(() => {
        this.phaseTimer = null
        this.animating = false
        if (persist) this.writeStoredCollapsed(true)
      }, PHASE_MS)
    }, PHASE_MS)
  }

  // Reverse: shrink strip first, then unfold height.
  expandPhased(persist) {
    const panel = this.panelTarget
    panel.classList.remove("sidebar--folding")
    panel.classList.add("sidebar--unfolding")
    panel.classList.remove("sidebar--collapsed")
    panel.classList.remove("sidebar--chevron-collapsed")
    if (this.hasShellTarget) {
      this.shellTarget.classList.remove("app-shell--sidebar-collapsed")
    }
    this.syncCollapseControl(false)

    this.phaseTimer = window.setTimeout(() => {
      panel.classList.remove("sidebar--unfolding")
      this.phaseTimer = window.setTimeout(() => {
        this.phaseTimer = null
        this.animating = false
        if (persist) this.writeStoredCollapsed(false)
      }, PHASE_MS)
    }, PHASE_MS)
  }

  syncCollapseControl(collapsed) {
    if (!this.hasCollapseTarget) return
    this.collapseTarget.setAttribute("aria-expanded", String(!collapsed))
    this.collapseTarget.setAttribute(
      "aria-label",
      collapsed ? this.collapseTarget.dataset.expandLabel : this.collapseTarget.dataset.collapseLabel
    )
    this.collapseTarget.title = collapsed
      ? this.collapseTarget.dataset.expandLabel
      : this.collapseTarget.dataset.collapseLabel
  }

  onShellTransitionEnd(event) {
    if (event.target !== this.shellTarget) return
    if (event.propertyName !== "grid-template-columns") return
    this.nudgeLayout()
  }

  // Help Monaco / flex panes pick up the finished main-column width.
  nudgeLayout() {
    window.dispatchEvent(new Event("resize"))
  }

  readStoredCollapsed() {
    try {
      return window.localStorage.getItem(STORAGE_KEY) === "1"
    } catch {
      return false
    }
  }

  writeStoredCollapsed(collapsed) {
    try {
      window.localStorage.setItem(STORAGE_KEY, collapsed ? "1" : "0")
    } catch {
      // Ignore private-mode / quota errors.
    }
  }

  onResize() {
    if (!this.isDesktop && (this.isFullyCollapsed || this.animating)) {
      this.setCollapsedImmediate(false)
      this.writeStoredCollapsed(false)
    }
  }

  onKeydown(event) {
    if (event.key === "Escape" && this.isOpen) this.close()
  }
}
