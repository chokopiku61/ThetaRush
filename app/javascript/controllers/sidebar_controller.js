import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "thetarush-sidebar-collapsed"
const DESKTOP_MQ = "(min-width: 52.01rem)"

// Mobile: off-canvas hamburger. Desktop: collapse rail into a top peek circle.
export default class extends Controller {
  static targets = ["panel", "toggle", "backdrop", "shell", "collapse"]

  connect() {
    this.onKeydown = this.onKeydown.bind(this)
    this.onResize = this.onResize.bind(this)
    document.addEventListener("keydown", this.onKeydown)
    window.addEventListener("resize", this.onResize)

    if (this.isDesktop && this.readStoredCollapsed()) {
      this.setCollapsed(true, { persist: false })
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    window.removeEventListener("resize", this.onResize)
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
    if (!this.isDesktop) return
    this.setCollapsed(!this.isCollapsed)
  }

  get isOpen() {
    return this.element.classList.contains("app-shell--sidebar-open")
  }

  get isCollapsed() {
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

  setCollapsed(collapsed, { persist = true } = {}) {
    if (this.hasPanelTarget) {
      this.panelTarget.classList.toggle("sidebar--collapsed", collapsed)
    }
    if (this.hasShellTarget) {
      this.shellTarget.classList.toggle("app-shell--sidebar-collapsed", collapsed)
    }
    if (this.hasCollapseTarget) {
      this.collapseTarget.setAttribute("aria-expanded", String(!collapsed))
      this.collapseTarget.setAttribute(
        "aria-label",
        collapsed ? this.collapseTarget.dataset.expandLabel : this.collapseTarget.dataset.collapseLabel
      )
      this.collapseTarget.title = collapsed
        ? this.collapseTarget.dataset.expandLabel
        : this.collapseTarget.dataset.collapseLabel
    }
    if (persist) this.writeStoredCollapsed(collapsed)
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
    if (!this.isDesktop && this.isCollapsed) {
      this.setCollapsed(false, { persist: false })
    }
  }

  onKeydown(event) {
    if (event.key === "Escape" && this.isOpen) this.close()
  }
}
