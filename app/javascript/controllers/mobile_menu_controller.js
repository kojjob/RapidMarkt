import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="mobile-menu"
export default class extends Controller {
  static targets = ["menu", "overlay", "panel"]

  connect() {
    this.close = this.close.bind(this)
    this.handleKeydown = this.handleKeydown.bind(this)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (!this.hasMenuTarget) {
      console.warn("Mobile menu target not found")
      return
    }

    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    if (!this.hasMenuTarget) return

    this.menuTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    document.addEventListener("keydown", this.handleKeydown)

    // Animate in if panel target exists
    if (this.hasPanelTarget) {
      setTimeout(() => {
        this.panelTarget.classList.remove("-translate-x-full")
      }, 10)
    }
  }

  close(event) {
    if (!this.hasMenuTarget) return

    if (event && this.element.contains(event.target)) {
      return
    }

    // Animate out if panel target exists
    if (this.hasPanelTarget) {
      this.panelTarget.classList.add("-translate-x-full")
      setTimeout(() => {
        this.menuTarget.classList.add("hidden")
        document.body.classList.remove("overflow-hidden")
      }, 300)
    } else {
      this.menuTarget.classList.add("hidden")
      document.body.classList.remove("overflow-hidden")
    }

    document.removeEventListener("keydown", this.handleKeydown)
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  overlayClick(event) {
    if (this.hasOverlayTarget && event.target === this.overlayTarget) {
      this.close()
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
    document.body.classList.remove("overflow-hidden")
  }
}