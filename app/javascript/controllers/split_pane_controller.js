import { Controller } from "@hotwired/stimulus"

// Draggable vertical divider between a left and right pane.
// The left width is stored as a percentage in the --split-left CSS variable
// on the controller element and remembered in localStorage.
export default class extends Controller {
  static targets = ["left", "divider"]
  static values = {
    min: { type: Number, default: 25 },
    max: { type: Number, default: 75 },
    storageKey: { type: String, default: "thetarush:split-left" }
  }

  connect() {
    this.onMove = this.onMove.bind(this)
    this.stop = this.stop.bind(this)

    const saved = parseFloat(window.localStorage.getItem(this.storageKeyValue))
    if (!Number.isNaN(saved)) this.apply(saved)

    if (this.hasDividerTarget) {
      this.dividerTarget.addEventListener("keydown", this.onKey)
    }
  }

  disconnect() {
    this.stop()
    if (this.hasDividerTarget) {
      this.dividerTarget.removeEventListener("keydown", this.onKey)
    }
  }

  start(event) {
    event.preventDefault()
    this.dragging = true
    this.element.classList.add("is-resizing")
    document.addEventListener("pointermove", this.onMove)
    document.addEventListener("pointerup", this.stop)
    document.addEventListener("pointercancel", this.stop)
  }

  onMove(event) {
    if (!this.dragging) return
    const rect = this.element.getBoundingClientRect()
    if (rect.width === 0) return
    this.apply(((event.clientX - rect.left) / rect.width) * 100)
  }

  stop() {
    if (!this.dragging) return
    this.dragging = false
    this.element.classList.remove("is-resizing")
    document.removeEventListener("pointermove", this.onMove)
    document.removeEventListener("pointerup", this.stop)
    document.removeEventListener("pointercancel", this.stop)
    if (this.current != null) {
      window.localStorage.setItem(this.storageKeyValue, String(this.current))
    }
  }

  // Keyboard support for the separator: arrow keys nudge by 2%.
  onKey = (event) => {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return
    event.preventDefault()
    const base = this.current ?? 50
    this.apply(base + (event.key === "ArrowLeft" ? -2 : 2))
    window.localStorage.setItem(this.storageKeyValue, String(this.current))
  }

  apply(percent) {
    const clamped = Math.min(this.maxValue, Math.max(this.minValue, percent))
    this.current = clamped
    this.element.style.setProperty("--split-left", `${clamped}%`)
    if (this.hasLeftTarget) this.leftTarget.style.flexBasis = `${clamped}%`
    if (this.hasDividerTarget) {
      this.dividerTarget.setAttribute("aria-valuenow", String(Math.round(clamped)))
    }
  }
}
