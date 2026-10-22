import { Controller } from "@hotwired/stimulus"

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
      // Replacing the element disconnects this controller. A fresh instance
      // connects only if the new markup is still non-terminal.
      this.element.outerHTML = html
    } catch (_error) {
      this.schedule()
    }
  }
}
