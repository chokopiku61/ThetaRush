import { Controller } from "@hotwired/stimulus"

// Decorative falling-characters background drawn on a canvas.
export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    color: { type: String, default: "#8B5CF6" },
    fontSize: { type: Number, default: 16 },
    fps: { type: Number, default: 24 }
  }

  static GLYPHS = "01θπΣ∑∫λ{}[]<>/+=#$"

  connect() {
    if (!this.hasCanvasTarget) return
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.ctx = this.canvasTarget.getContext("2d")
    this.resize = this.resize.bind(this)
    this.frame = this.frame.bind(this)
    this.lastTick = 0

    window.addEventListener("resize", this.resize)
    this.resize()
    this.raf = requestAnimationFrame(this.frame)
  }

  disconnect() {
    window.removeEventListener("resize", this.resize)
    if (this.raf) cancelAnimationFrame(this.raf)
    this.raf = null
  }

  resize() {
    const canvas = this.canvasTarget
    const rect = (canvas.parentElement || canvas).getBoundingClientRect()
    const dpr = window.devicePixelRatio || 1

    canvas.width = Math.max(1, Math.floor(rect.width * dpr))
    canvas.height = Math.max(1, Math.floor(rect.height * dpr))
    canvas.style.width = `${rect.width}px`
    canvas.style.height = `${rect.height}px`
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0)

    this.width = rect.width
    this.height = rect.height
    const columns = Math.ceil(this.width / this.fontSizeValue)
    this.drops = Array.from({ length: columns }, () => Math.random() * -50)
    this.ctx.clearRect(0, 0, this.width, this.height)
  }

  frame(now) {
    this.raf = requestAnimationFrame(this.frame)
    if (now - this.lastTick < 1000 / this.fpsValue) return
    this.lastTick = now

    const ctx = this.ctx
    const size = this.fontSizeValue
    const glyphs = this.constructor.GLYPHS

    // Fade previous frame to leave trails.
    ctx.globalCompositeOperation = "destination-out"
    ctx.fillStyle = "rgba(0, 0, 0, 0.12)"
    ctx.fillRect(0, 0, this.width, this.height)
    ctx.globalCompositeOperation = "source-over"

    ctx.fillStyle = this.colorValue
    ctx.font = `${size}px "IBM Plex Mono", monospace`

    this.drops.forEach((y, i) => {
      const glyph = glyphs[Math.floor(Math.random() * glyphs.length)]
      ctx.fillText(glyph, i * size, y * size)

      if (y * size > this.height && Math.random() > 0.975) {
        this.drops[i] = 0
      } else {
        this.drops[i] = y + 1
      }
    })
  }
}
