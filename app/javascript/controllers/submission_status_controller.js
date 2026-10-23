import { Controller } from "@hotwired/stimulus"
import confetti from "canvas-confetti"

// Polls the submission status partial while a submission is queued or judging.
// The server returns the same partial; when it is terminal it no longer has
// data-controller, so polling stops once the element is replaced.
export default class extends Controller {
  static values = {
    url: String,
    interval: { type: Number, default: 1500 },
    maxAttempts: { type: Number, default: 120 }
  }

  connect() {
    this.attempts = 0
    this.schedule()
  }

  disconnect() {
    clearTimeout(this.timer)
    this.stopped = true
  }

  schedule() {
    if (this.stopped || this.element.dataset.terminal === "true") return
    if (this.attempts >= this.maxAttemptsValue) return

    this.timer = setTimeout(() => this.poll(), this.intervalValue)
  }

  async poll() {
    this.attempts += 1

    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "text/html", "X-Requested-With": "XMLHttpRequest" },
        credentials: "same-origin"
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const html = await response.text()
      if (this.stopped) return

      const previousVerdict = this.element.dataset.verdict
      const template = document.createElement("template")
      template.innerHTML = html.trim()
      const next = template.content.firstElementChild
      const nextVerdict = next?.dataset?.verdict
      const celebrate = previousVerdict !== "ac" && nextVerdict === "ac"

      // Replacing the element disconnects this controller. A fresh instance
      // connects only if the new markup is still non-terminal.
      this.element.outerHTML = html

      if (celebrate) {
        requestAnimationFrame(() => this.burstFromLatestAc())
      }
    } catch (_error) {
      this.schedule()
    }
  }

  burstFromLatestAc() {
    const badge = document.querySelector("#submission-status [data-latest-verdict-badge], #submission-status .badge--ac")
    if (!badge) return

    const rect = badge.getBoundingClientRect()
    const x = (rect.left + rect.width / 2) / window.innerWidth
    const y = (rect.top + rect.height / 2) / window.innerHeight

    confetti({
      particleCount: 48,
      spread: 55,
      startVelocity: 28,
      ticks: 90,
      gravity: 1.05,
      scalar: 0.85,
      origin: { x, y },
      disableForReducedMotion: true
    })
  }
}
