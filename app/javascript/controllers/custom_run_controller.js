import { Controller } from "@hotwired/stimulus"

// Mini IDE: stdin + Run via Judge0 custom_runs; sample Play compare states.
export default class extends Controller {
  static targets = [
    "stdin",
    "stdout",
    "stderr",
    "compile",
    "runButton",
    "status",
    "sample"
  ]

  static values = {
    url: String,
    csrf: String
  }

  connect() {
    this.sampleVerdict = null
    this.onEditorChange = this.onEditorChange.bind(this)
    this.element.addEventListener("editor:change", this.onEditorChange)
  }

  disconnect() {
    this.element.removeEventListener("editor:change", this.onEditorChange)
  }

  async run(event) {
    if (event) event.preventDefault()
    await this.execute({ compareSample: null })
  }

  async playSample(event) {
    if (event) event.preventDefault()
    const button = event.currentTarget
    const sampleEl = button.closest("[data-custom-run-target='sample']") || button.closest(".sample-card")
    const stdin = button.dataset.stdin ?? sampleEl?.dataset?.stdin ?? ""
    const expected = button.dataset.expected ?? sampleEl?.dataset?.expected ?? ""

    if (this.hasStdinTarget) this.stdinTarget.value = stdin
    await this.execute({ compareSample: sampleEl, expected })
  }

  async execute({ compareSample, expected }) {
    if (!this.urlValue) return

    const editor = this.editorController()
    const source = editor ? editor.getValue() : ""
    const languageEl = this.element.querySelector("select[name='language']")
    const language = languageEl ? languageEl.value : "python"
    const stdin = this.hasStdinTarget ? this.stdinTarget.value : ""

    this.setBusy(true)
    this.clearOutputs()

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": this.csrfValue || this.csrfToken()
        },
        body: JSON.stringify({ language, source_code: source, stdin }),
        credentials: "same-origin"
      })

      const body = await response.json().catch(() => ({}))
      if (!response.ok) {
        this.showError(body.error || "Custom run failed.")
        if (compareSample) this.markSample(compareSample, false, false)
        return
      }

      this.fillOutputs(body)

      if (compareSample) {
        const passed = this.outputsMatch(body.stdout, expected)
        this.markSample(compareSample, passed, false)
        this.sampleVerdict = { el: compareSample, passed }
      }
    } catch (error) {
      this.showError(error.message || "Custom run failed.")
      if (compareSample) this.markSample(compareSample, false, false)
    } finally {
      this.setBusy(false)
    }
  }

  onEditorChange() {
    if (!this.sampleVerdict?.el) return
    this.markSample(this.sampleVerdict.el, this.sampleVerdict.passed, true)
  }

  markSample(el, passed, pale) {
    if (!el) return
    el.classList.remove(
      "sample-card--pass",
      "sample-card--fail",
      "sample-card--pass-pale",
      "sample-card--fail-pale"
    )
    if (passed) {
      el.classList.add(pale ? "sample-card--pass-pale" : "sample-card--pass")
    } else {
      el.classList.add(pale ? "sample-card--fail-pale" : "sample-card--fail")
    }
  }

  outputsMatch(actual, expected) {
    const norm = (value) => String(value ?? "").replace(/\r\n/g, "\n").replace(/\s+$/g, "")
    return norm(actual) === norm(expected)
  }

  fillOutputs(body) {
    if (this.hasStdoutTarget) this.stdoutTarget.textContent = body.stdout || ""
    if (this.hasStderrTarget) this.stderrTarget.textContent = body.stderr || ""
    if (this.hasCompileTarget) this.compileTarget.textContent = body.compile_output || ""
    if (this.hasStatusTarget) this.statusTarget.textContent = (body.status || "").toUpperCase()
  }

  clearOutputs() {
    if (this.hasStdoutTarget) this.stdoutTarget.textContent = ""
    if (this.hasStderrTarget) this.stderrTarget.textContent = ""
    if (this.hasCompileTarget) this.compileTarget.textContent = ""
    if (this.hasStatusTarget) this.statusTarget.textContent = ""
  }

  showError(message) {
    if (this.hasStderrTarget) this.stderrTarget.textContent = message
    if (this.hasStatusTarget) this.statusTarget.textContent = "ERR"
  }

  setBusy(busy) {
    if (this.hasRunButtonTarget) this.runButtonTarget.disabled = busy
    if (busy && this.hasStatusTarget) this.statusTarget.textContent = "…"
  }

  editorController() {
    const el = this.element.closest("[data-controller~='editor']") || this.element
    return this.application.getControllerForElementAndIdentifier(el, "editor")
  }

  csrfToken() {
    const meta = document.querySelector("meta[name='csrf-token']")
    return meta ? meta.content : ""
  }
}
