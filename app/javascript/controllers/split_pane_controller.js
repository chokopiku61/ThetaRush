import { Controller } from "@hotwired/stimulus"

// Draggable divider between a primary and secondary pane.
// Horizontal: left width as --split-left (%). Vertical: top height as --split-top (%).
export default class extends Controller {
  static targets = ["left", "divider"]
  static values = {
    min: { type: Number, default: 25 },
    max: { type: Number, default: 75 },
    storageKey: { type: String, default: "thetarush:split-left" },
    orientation: { type: String, default: "horizontal" }
  }

  connect() {
    this.onMove = this.onMove.bind(this)
    this.stop = this.stop.bind(this)

    const saved = parseFloat(window.localStorage.getItem(this.storageKeyValue))
    if (!Number.isNaN(saved)) this.apply(saved, { notify: false })

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

  get isVertical() {
    return this.orientationValue === "vertical"
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
    if (this.isVertical) {
      if (rect.height === 0) return
      this.apply(((event.clientY - rect.top) / rect.height) * 100)
    } else {
      if (rect.width === 0) return
      this.apply(((event.clientX - rect.left) / rect.width) * 100)
    }
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
    this.notifyResize()
  }

  // Keyboard support for the separator.
  onKey = (event) => {
    const vertical = this.isVertical
    const shrink = vertical ? "ArrowUp" : "ArrowLeft"
    const grow = vertical ? "ArrowDown" : "ArrowRight"
    if (event.key !== shrink && event.key !== grow) return
    event.preventDefault()
    const base = this.current ?? 50
    this.apply(base + (event.key === shrink ? -2 : 2))
    window.localStorage.setItem(this.storageKeyValue, String(this.current))
    this.notifyResize()
  }

  apply(percent, { notify = true } = {}) {
    const clamped = Math.min(this.maxValue, Math.max(this.minValue, percent))
    this.current = clamped
    if (this.isVertical) {
      this.element.style.setProperty("--split-top", `${clamped}%`)
      if (this.hasLeftTarget) this.leftTarget.style.flexBasis = `${clamped}%`
    } else {
      this.element.style.setProperty("--split-left", `${clamped}%`)
      if (this.hasLeftTarget) this.leftTarget.style.flexBasis = `${clamped}%`
    }
    if (this.hasDividerTarget) {
      this.dividerTarget.setAttribute("aria-valuenow", String(Math.round(clamped)))
    }
    if (notify) this.notifyResize()
  }

  notifyResize() {
    this.element.dispatchEvent(
      new CustomEvent("split-pane:resized", { bubbles: true })
    )
  }
}
