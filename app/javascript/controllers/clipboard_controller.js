import { Controller } from "@hotwired/stimulus"

// Copies the text of the source target to the clipboard.
export default class extends Controller {
  static targets = ["source", "button"]
  static values = {
    copied: { type: String, default: "Copied" },
    resetAfter: { type: Number, default: 1500 }
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  async copy(event) {
    if (event) event.preventDefault()
    if (!this.hasSourceTarget) return

    const text = this.sourceTarget.value ?? this.sourceTarget.textContent
    try {
      await navigator.clipboard.writeText(text)
    } catch (_error) {
      this.fallbackCopy(text)
    }
    this.flash()
  }

  fallbackCopy(text) {
    const area = document.createElement("textarea")
    area.value = text
    area.setAttribute("readonly", "")
    area.style.position = "fixed"
    area.style.opacity = "0"
    document.body.appendChild(area)
    area.select()
    document.execCommand("copy")
    area.remove()
  }

  flash() {
    if (!this.hasButtonTarget) return

    const button = this.buttonTarget
    if (this.original === undefined) this.original = button.textContent.trim()
    button.textContent = this.copiedValue
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      button.textContent = this.original
    }, this.resetAfterValue)
  }
}
