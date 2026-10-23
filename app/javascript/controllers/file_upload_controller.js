import { Controller } from "@hotwired/stimulus"

// Loads a local source file into the Monaco editor (or textarea fallback).
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
    if (!this.hasInputTarget) return

    const file = this.inputTarget.files[0]
    if (!file) return

    if (file.size > this.maxBytesValue) {
      window.alert(`File is too large (max ${Math.round(this.maxBytesValue / 1024)} KB).`)
      this.inputTarget.value = ""
      return
    }

    const reader = new FileReader()
    reader.onload = () => {
      const text = String(reader.result)
      const editor = this.editorController()
      if (editor) {
        editor.setValue(text)
      } else if (this.hasTextareaTarget) {
        this.textareaTarget.value = text
        this.textareaTarget.dispatchEvent(new Event("input", { bubbles: true }))
      }
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
      select.dispatchEvent(new Event("change", { bubbles: true }))
      const editor = this.editorController()
      if (editor) editor.setLanguage(language)
    }
  }

  editorController() {
    const el = this.element.closest("[data-controller~='editor']") || this.element
    return this.application.getControllerForElementAndIdentifier(el, "editor")
  }
}
