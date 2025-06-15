import { Controller } from "@hotwired/stimulus"

// Enhanced Dropdown Controller with better animations and debugging
export default class extends Controller {
  static targets = ["menu", "button"]
  static values = {
    closeOnClick: { type: Boolean, default: true },
    animation: { type: Boolean, default: true }
  }

  connect() {
    console.log("Dropdown controller connected", this.element)
    this.close = this.close.bind(this)
    this.handleEscape = this.handleEscape.bind(this)

    // Ensure menu starts hidden
    if (this.hasMenuTarget) {
      this.menuTarget.classList.add("hidden")
      this.menuTarget.classList.remove("show")
    }
  }

  toggle(event) {
    console.log("Dropdown toggle clicked", event)
    event.preventDefault()
    event.stopPropagation()

    if (!this.hasMenuTarget) {
      console.error("No menu target found for dropdown")
      return
    }

    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    console.log("Opening dropdown")

    if (!this.hasMenuTarget) return

    // Close any other open dropdowns
    this.closeOtherDropdowns()

    // Show the menu
    this.menuTarget.classList.remove("hidden")

    // Add animation class if enabled
    if (this.animationValue) {
      this.menuTarget.classList.add("dropdown-enter")

      // Trigger animation
      requestAnimationFrame(() => {
        this.menuTarget.classList.remove("dropdown-enter")
        this.menuTarget.classList.add("dropdown-enter-active", "show")
      })
    } else {
      this.menuTarget.classList.add("show")
    }

    // Update button aria-expanded
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", "true")
    }

    // Add event listeners
    document.addEventListener("click", this.close)
    document.addEventListener("keydown", this.handleEscape)
  }

  close(event) {
    // Don't close if clicking inside the dropdown
    if (event && this.element.contains(event.target)) {
      return
    }

    console.log("Closing dropdown")

    if (!this.hasMenuTarget || !this.isOpen()) return

    // Add exit animation if enabled
    if (this.animationValue) {
      this.menuTarget.classList.remove("dropdown-enter-active", "show")
      this.menuTarget.classList.add("dropdown-exit")

      // Wait for animation to complete
      setTimeout(() => {
        this.menuTarget.classList.remove("dropdown-exit")
        this.menuTarget.classList.add("hidden")
      }, 150)
    } else {
      this.menuTarget.classList.remove("show")
      this.menuTarget.classList.add("hidden")
    }

    // Update button aria-expanded
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", "false")
    }

    // Remove event listeners
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this.handleEscape)
  }

  handleEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  isOpen() {
    return this.hasMenuTarget && !this.menuTarget.classList.contains("hidden")
  }

  closeOtherDropdowns() {
    // Close any other open dropdowns
    document.querySelectorAll('[data-controller*="dropdown"]').forEach(dropdown => {
      if (dropdown !== this.element) {
        const controller = this.application.getControllerForElementAndIdentifier(dropdown, "dropdown")
        if (controller && controller.isOpen && controller.isOpen()) {
          controller.close()
        }
      }
    })
  }

  // Action to close dropdown when clicking menu items
  closeOnItemClick(event) {
    if (this.closeOnClickValue) {
      // Small delay to allow navigation to complete
      setTimeout(() => this.close(), 100)
    }
  }

  disconnect() {
    console.log("Dropdown controller disconnected")
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this.handleEscape)
  }
}