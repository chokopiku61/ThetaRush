import { Controller } from "@hotwired/stimulus"

const VIM_KEY = "thetarush:editor-vim"
const CAPS_KEY = "thetarush:editor-caps-esc"
const MONACO_BASE = "/monaco/vs"

// Monaco code editor with Classic/Vim toggle and one-way Caps→Esc (Vim only).
export default class extends Controller {
  static targets = [
    "host",
    "input",
    "language",
    "vimToggle",
    "capsToggle",
    "capsRow",
    "vimStatus"
  ]

  static values = {
    language: { type: String, default: "python" }
  }

  connect() {
    this.alive = true
    this.editor = null
    this.vimMode = null
    this.monacoVim = null
    this.monaco = null
    this.resizeObserver = null
    this.resizeRaf = null
    this.lastLayout = { width: 0, height: 0 }
    this.onCapsKeydown = this.onCapsKeydown.bind(this)
    this.onSplitResize = this.onSplitResize.bind(this)
    this.loadMonaco().then(() => {
      if (!this.alive) return
      this.mount()
    }).catch((error) => {
      if (!this.alive) return
      console.error("Monaco failed to load", error)
      this.fallbackTextarea()
    })
    this.element.addEventListener("split-pane:resized", this.onSplitResize)
    // Sidebar shell width transition ends with a window resize nudge.
    window.addEventListener("resize", this.onSplitResize)
  }

  disconnect() {
    this.alive = false
    this.teardownVim()
    this.teardownResizeObserver()
    document.removeEventListener("keydown", this.onCapsKeydown, true)
    this.element.removeEventListener("split-pane:resized", this.onSplitResize)
    window.removeEventListener("resize", this.onSplitResize)
    if (this.editor) {
      this.editor.dispose()
      this.editor = null
    }
  }

  onSplitResize() {
    if (!this.editor || !this.hasHostTarget) return
    const width = Math.max(0, Math.floor(this.hostTarget.clientWidth))
    const height = Math.max(0, Math.floor(this.hostTarget.clientHeight))
    if (width === 0 || height === 0) return
    this.lastLayout = { width, height }
    this.editor.layout({ width, height })
  }

  loadMonaco() {
    if (window.monaco && window.require) {
      return Promise.resolve(window.monaco)
    }

    return new Promise((resolve, reject) => {
      const existing = document.querySelector("script[data-monaco-loader]")
      const start = () => {
        window.require.config({
          paths: {
            vs: MONACO_BASE,
            "monaco-vim": "/monaco/monaco-vim"
          }
        })
        window.require(["vs/editor/editor.main"], () => resolve(window.monaco), reject)
      }

      if (existing) {
        if (window.require) start()
        else existing.addEventListener("load", start)
        return
      }

      const script = document.createElement("script")
      script.src = `${MONACO_BASE}/loader.js`
      script.dataset.monacoLoader = "1"
      script.async = true
      script.onload = start
      script.onerror = reject
      document.head.appendChild(script)

      if (!document.querySelector("link[data-monaco-css]")) {
        const link = document.createElement("link")
        link.rel = "stylesheet"
        link.href = `${MONACO_BASE}/editor/editor.main.css`
        link.dataset.monacoCss = "1"
        document.head.appendChild(link)
      }
    })
  }

  mount() {
    if (!this.hasHostTarget) return

    const initial = this.hasInputTarget ? this.inputTarget.value : ""
    this.monaco = window.monaco
    // Avoid Monaco automaticLayout: with flex + overflow:auto parents it can
    // enter a ResizeObserver feedback loop and peg the CPU until the tab freezes.
    this.editor = this.monaco.editor.create(this.hostTarget, {
      value: initial,
      language: this.monacoLanguage(this.currentLanguage()),
      theme: "vs-dark",
      automaticLayout: false,
      minimap: { enabled: false },
      fontFamily: "IBM Plex Mono, ui-monospace, monospace",
      fontSize: 14,
      lineNumbers: "on",
      scrollBeyondLastLine: false,
      wordBasedSuggestions: "off",
      quickSuggestions: false,
      suggestOnTriggerCharacters: false,
      parameterHints: { enabled: false },
      hover: { enabled: true },
      tabSize: 4,
      renderValidationDecorations: "off",
      "semanticHighlighting.enabled": false
    })

    this.observeHostSize()

    this.editor.onDidChangeModelContent(() => {
      this.syncInput()
      this.element.dispatchEvent(new CustomEvent("editor:change", { bubbles: true }))
    })

    this.element.querySelectorAll("form").forEach((form) => {
      form.addEventListener("submit", () => this.syncInput())
    })

    if (this.hasLanguageTarget) {
      this.languageTarget.addEventListener("change", () => this.setLanguage(this.languageTarget.value))
    }

    const vimOn = this.readFlag(VIM_KEY, false)
    const capsOn = this.readFlag(CAPS_KEY, false)
    if (this.hasVimToggleTarget) this.vimToggleTarget.checked = vimOn
    if (this.hasCapsToggleTarget) this.capsToggleTarget.checked = capsOn
    this.syncVimSwitch(vimOn)
    this.applyVim(vimOn)
    this.applyCaps(capsOn)
    this.syncInput()
  }

  observeHostSize() {
    if (!this.editor || !this.hasHostTarget) return

    const layoutIfChanged = () => {
      if (!this.alive || !this.editor) return
      const width = Math.max(0, Math.floor(this.hostTarget.clientWidth))
      const height = Math.max(0, Math.floor(this.hostTarget.clientHeight))
      if (width === 0 || height === 0) return
      if (width === this.lastLayout.width && height === this.lastLayout.height) return
      this.lastLayout = { width, height }
      this.editor.layout({ width, height })
    }

    layoutIfChanged()

    this.resizeObserver = new ResizeObserver(() => {
      if (this.resizeRaf) cancelAnimationFrame(this.resizeRaf)
      this.resizeRaf = requestAnimationFrame(() => {
        this.resizeRaf = null
        layoutIfChanged()
      })
    })
    this.resizeObserver.observe(this.hostTarget)
  }

  teardownResizeObserver() {
    if (this.resizeRaf) {
      cancelAnimationFrame(this.resizeRaf)
      this.resizeRaf = null
    }
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
      this.resizeObserver = null
    }
  }

  fallbackTextarea() {
    if (!this.hasHostTarget || !this.hasInputTarget) return
    this.inputTarget.hidden = false
    this.inputTarget.classList.add("textarea", "textarea--code")
    this.hostTarget.hidden = true
  }

  setValue(value) {
    const text = String(value ?? "")
    if (this.editor) {
      this.editor.setValue(text)
    } else if (this.hasInputTarget) {
      this.inputTarget.value = text
    }
    this.syncInput()
    this.element.dispatchEvent(new CustomEvent("editor:change", { bubbles: true }))
  }

  getValue() {
    if (this.editor) return this.editor.getValue()
    if (this.hasInputTarget) return this.inputTarget.value
    return ""
  }

  syncInput() {
    if (this.hasInputTarget) this.inputTarget.value = this.getValue()
  }

  setLanguage(language) {
    if (!this.editor || !this.monaco) return
    const model = this.editor.getModel()
    if (model) this.monaco.editor.setModelLanguage(model, this.monacoLanguage(language))
  }

  monacoLanguage(language) {
    return language === "cpp" ? "cpp" : "python"
  }

  currentLanguage() {
    if (this.hasLanguageTarget) return this.languageTarget.value || this.languageValue
    return this.languageValue
  }

  toggleVim() {
    const on = this.hasVimToggleTarget ? this.vimToggleTarget.checked : false
    this.syncVimSwitch(on)
    this.writeFlag(VIM_KEY, on)
    this.applyVim(on)
  }

  toggleCaps() {
    const on = this.hasCapsToggleTarget ? this.capsToggleTarget.checked : false
    this.writeFlag(CAPS_KEY, on)
    this.applyCaps(on)
  }

  syncVimSwitch(on) {
    if (!this.hasVimToggleTarget) return
    this.vimToggleTarget.setAttribute("aria-checked", String(on))
  }

  applyVim(on) {
    if (this.hasCapsRowTarget) this.capsRowTarget.hidden = !on
    this.syncVimSwitch(on)
    if (!on) {
      this.teardownVim()
      this.applyCaps(false)
      return
    }
    this.enableVim()
    const capsOn = this.hasCapsToggleTarget ? this.capsToggleTarget.checked : false
    this.applyCaps(capsOn)
  }

  enableVim() {
    if (!this.editor || this.vimMode) return

    const finish = (MonacoVim) => {
      this.monacoVim = MonacoVim
      const statusNode = this.hasVimStatusTarget ? this.vimStatusTarget : null
      this.vimMode = MonacoVim.initVimMode(this.editor, statusNode)
    }

    window.require(["monaco-vim"], (MonacoVim) => finish(MonacoVim), (err) => {
      console.error("monaco-vim failed", err)
    })
  }

  teardownVim() {
    if (this.vimMode) {
      this.vimMode.dispose()
      this.vimMode = null
    }
    if (this.hasVimStatusTarget) this.vimStatusTarget.textContent = ""
  }

  applyCaps(on) {
    document.removeEventListener("keydown", this.onCapsKeydown, true)
    if (on && this.hasVimToggleTarget && this.vimToggleTarget.checked) {
      document.addEventListener("keydown", this.onCapsKeydown, true)
    }
  }

  // Caps Lock -> Escape. While enabled, letter case follows Shift only (ignore OS Caps).
  onCapsKeydown(event) {
    if (!this.editor || !this.vimMode) return
    if (!this.editorHasFocus()) return

    if (event.key === "CapsLock" || event.code === "CapsLock") {
      if (event.repeat) return
      event.preventDefault()
      event.stopPropagation()
      event.stopImmediatePropagation()
      this.sendVimKey("<Esc>")
      return
    }

    if (event.ctrlKey || event.altKey || event.metaKey) return
    if (!event.getModifierState?.("CapsLock")) return

    const match = event.code && event.code.match(/^Key([A-Z])$/)
    if (!match) return

    const letter = match[1]
    const key = event.shiftKey ? letter : letter.toLowerCase()

    event.preventDefault()
    event.stopPropagation()
    event.stopImmediatePropagation()

    if (this.vimInsertMode()) {
      this.editor.trigger("keyboard", "type", { text: key })
    } else {
      this.sendVimKey(key)
    }
  }

  sendVimKey(key) {
    const Vim = this.monacoVim?.VimMode?.Vim
    if (Vim && typeof Vim.handleKey === "function") {
      Vim.handleKey(this.vimMode, key)
      return
    }

    window.require(["monaco-vim"], (MonacoVim) => {
      this.monacoVim = MonacoVim
      if (!this.vimMode) return
      MonacoVim.VimMode.Vim.handleKey(this.vimMode, key)
    })
  }

  vimInsertMode() {
    return Boolean(this.vimMode?.state?.vim?.insertMode)
  }

  editorHasFocus() {
    const node = this.editor?.getDomNode()
    if (!node) return false
    if (node.contains(document.activeElement) || this.hostTarget.contains(document.activeElement)) {
      return true
    }
    if (this.hasVimStatusTarget && this.vimStatusTarget.contains(document.activeElement)) {
      return true
    }
    return false
  }

  readFlag(key, fallback) {
    try {
      const raw = window.localStorage.getItem(key)
      if (raw === null) return fallback
      return raw === "1"
    } catch {
      return fallback
    }
  }

  writeFlag(key, value) {
    try {
      window.localStorage.setItem(key, value ? "1" : "0")
    } catch {
      // Ignore private-mode / quota errors.
    }
  }
}
