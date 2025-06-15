import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="mobile-menu"
export default class extends Controller {
  static targets = ["menu", "button", "hamburger", "close"]

  connect() {
    this.close = this.close.bind(this)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    // Show menu
    this.menuTarget.classList.remove("hidden")

    // Update button icons
    if (this.hasHamburgerTarget) this.hamburgerTarget.classList.add("hidden")
    if (this.hasCloseTarget) this.closeTarget.classList.remove("hidden")

    // Update aria attributes
    this.buttonTarget.setAttribute("aria-expanded", "true")

    // Prevent body scroll
    document.body.classList.add("overflow-hidden")

    // Add click outside listener
    document.addEventListener("click", this.close)

    // Add escape key listener
    document.addEventListener("keydown", this.handleEscape.bind(this))
  }

  close(event) {
    // Don't close if clicking inside the menu
    if (event && this.menuTarget.contains(event.target)) {
      return
    }

    // Hide menu
    this.menuTarget.classList.add("hidden")

    // Update button icons
    if (this.hasHamburgerTarget) this.hamburgerTarget.classList.remove("hidden")
    if (this.hasCloseTarget) this.closeTarget.classList.add("hidden")

    // Update aria attributes
    this.buttonTarget.setAttribute("aria-expanded", "false")

    // Restore body scroll
    document.body.classList.remove("overflow-hidden")

    // Remove listeners
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this.handleEscape.bind(this))
  }

  handleEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  disconnect() {
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this.handleEscape.bind(this))
    document.body.classList.remove("overflow-hidden")
  }
}