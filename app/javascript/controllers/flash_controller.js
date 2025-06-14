import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="flash"
export default class extends Controller {
  static values = { autoDismiss: Boolean }

  connect() {
    if (this.autoDismissValue) {
      setTimeout(() => {
        this.dismiss()
      }, 5000) // Auto dismiss after 5 seconds
    }
  }

  dismiss() {
    this.element.style.transition = "opacity 0.3s ease-out"
    this.element.style.opacity = "0"
    
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}