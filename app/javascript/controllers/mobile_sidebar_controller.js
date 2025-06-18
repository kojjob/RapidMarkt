import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="mobile-sidebar"
export default class extends Controller {
  static targets = ["overlay", "panel", "backdrop"]

  connect() {
    // Ensure sidebar starts hidden on mobile
    this.close()
    
    // Store initial focus element
    this.lastFocusedElement = null
    
    // Add keyboard event listener for accessibility
    document.addEventListener("keydown", this.handleKeydown.bind(this))
  }

  disconnect() {
    // Cleanup: restore body scroll when controller is disconnected
    document.body.style.overflow = ""
    
    // Remove keyboard event listeners
    document.removeEventListener("keydown", this.handleKeydown.bind(this))
  }

  toggle() {
    if (this.overlayTarget.style.display === "none" || !this.overlayTarget.style.display) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    // Store current focus
    this.lastFocusedElement = document.activeElement
    
    // Show overlay
    this.overlayTarget.style.display = "flex"
    
    // Animate panel in
    setTimeout(() => {
      this.panelTarget.style.transform = "translateX(0)"
    }, 10)
    
    // Prevent body scroll
    document.body.style.overflow = "hidden"
    
    // Focus first focusable element in sidebar
    setTimeout(() => {
      const firstFocusable = this.panelTarget.querySelector('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])')
      if (firstFocusable) {
        firstFocusable.focus()
      }
    }, 100)
  }

  close() {
    // Animate panel out
    this.panelTarget.style.transform = "translateX(-100%)"
    
    // Hide overlay after animation
    setTimeout(() => {
      this.overlayTarget.style.display = "none"
      this.panelTarget.style.transform = ""
    }, 300)
    
    // Restore body scroll
    document.body.style.overflow = ""
    
    // Restore focus
    if (this.lastFocusedElement) {
      this.lastFocusedElement.focus()
      this.lastFocusedElement = null
    }
  }

  handleKeydown(event) {
    // Close on Escape key
    if (event.key === "Escape" && this.overlayTarget.style.display === "flex") {
      event.preventDefault()
      this.close()
    }
  }
}