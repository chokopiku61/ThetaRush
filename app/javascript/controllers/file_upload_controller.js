import { Controller } from "@hotwired/stimulus"

// Loads a local source file into the code textarea.
export default class extends Controller {
  static targets = ["input", "textarea", "language"]
  static values = { maxBytes: { type: Number, default: 262144 } }

  static EXTENSIONS = {
    py: "python",
    cpp: "cpp",
    cc: "cpp",
    cxx: "cpp",
    c: "cpp"
  }

  pick(event) {
    if (event) event.preventDefault()
    if (this.hasInputTarget) this.inputTarget.click()
  }

  load() {
    if (!this.hasInputTarget || !this.hasTextareaTarget) return

    const file = this.inputTarget.files[0]
    if (!file) return

    if (file.size > this.maxBytesValue) {
      window.alert(`File is too large (max ${Math.round(this.maxBytesValue / 1024)} KB).`)
      this.inputTarget.value = ""
      return
    }

    const reader = new FileReader()
    reader.onload = () => {
      this.textareaTarget.value = String(reader.result)
      this.textareaTarget.dispatchEvent(new Event("input", { bubbles: true }))
      this.selectLanguage(file.name)
      this.inputTarget.value = ""
    }
    reader.readAsText(file)
  }

  selectLanguage(filename) {
    const select = this.hasLanguageTarget
      ? this.languageTarget
      : this.element.querySelector("select[name='language']")
    if (!select) return

    const ext = filename.split(".").pop().toLowerCase()
    const language = this.constructor.EXTENSIONS[ext]
    if (language && Array.from(select.options).some((o) => o.value === language)) {
      select.value = language
    }
  }
}
