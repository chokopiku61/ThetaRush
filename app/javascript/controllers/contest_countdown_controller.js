import { Controller } from "@hotwired/stimulus"

// Keeps the contest strip countdown label fresh without a full page reload.
export default class extends Controller {
  static targets = ["label"]
  static values = {
    target: String,
    mode: String,
    untilStartTemplate: String,
    untilEndTemplate: String,
    finished: String
  }

  connect() {
    this.tick = this.tick.bind(this)
    this.tick()
    this.timer = window.setInterval(this.tick, 1_000)
  }

  disconnect() {
    if (this.timer) window.clearInterval(this.timer)
  }

  tick() {
    if (!this.hasLabelTarget || !this.targetValue) return

    const deadline = Date.parse(this.targetValue)
    if (Number.isNaN(deadline)) return

    const seconds = Math.floor((deadline - Date.now()) / 1000)
    if (seconds <= 0) {
      this.labelTarget.textContent = this.finishedValue
      return
    }

    const hms = this.formatHms(seconds)
    const template =
      this.modeValue === "upcoming" ? this.untilStartTemplateValue : this.untilEndTemplateValue
    this.labelTarget.textContent = template.replace("%{time}", hms)
  }

  formatHms(totalSeconds) {
    const hours = Math.floor(totalSeconds / 3600)
    const minutes = Math.floor((totalSeconds % 3600) / 60)
    const secs = totalSeconds % 60
    const pad = (n) => String(n).padStart(2, "0")
    return `${pad(hours)}:${pad(minutes)}:${pad(secs)}`
  }
}
