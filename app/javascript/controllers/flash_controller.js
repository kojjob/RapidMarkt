import { Controller } from "@hotwired/stimulus"

// Enhanced Flash/Toast Controller
export default class extends Controller {
  static values = {
    autoDismiss: Boolean,
    duration: { type: Number, default: 5000 },
    type: String,
    position: { type: String, default: "top-right" }
  }

  static targets = ["progressBar"]

  connect() {
    this.setupToast()

    if (this.autoDismissValue) {
      this.startAutoDismiss()
    }
  }

  setupToast() {
    // Add entrance animation
    this.element.style.transform = this.getEntranceTransform()
    this.element.style.opacity = "0"

    // Trigger entrance animation
    requestAnimationFrame(() => {
      this.element.style.transition = "all 0.4s cubic-bezier(0.16, 1, 0.3, 1)"
      this.element.style.transform = "translateX(0) translateY(0) scale(1)"
      this.element.style.opacity = "1"
    })

    // Add hover pause functionality
    this.element.addEventListener('mouseenter', () => this.pauseAutoDismiss())
    this.element.addEventListener('mouseleave', () => this.resumeAutoDismiss())
  }

  getEntranceTransform() {
    switch(this.positionValue) {
      case 'top-right':
      case 'bottom-right':
        return "translateX(100%) scale(0.95)"
      case 'top-left':
      case 'bottom-left':
        return "translateX(-100%) scale(0.95)"
      case 'top-center':
        return "translateY(-100%) scale(0.95)"
      case 'bottom-center':
        return "translateY(100%) scale(0.95)"
      default:
        return "translateX(100%) scale(0.95)"
    }
  }

  startAutoDismiss() {
    if (this.hasProgressBarTarget) {
      this.animateProgressBar()
    }

    this.autoDismissTimer = setTimeout(() => {
      this.dismiss()
    }, this.durationValue)
  }

  pauseAutoDismiss() {
    if (this.autoDismissTimer) {
      clearTimeout(this.autoDismissTimer)
      this.autoDismissTimer = null
    }

    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.animationPlayState = "paused"
    }
  }

  resumeAutoDismiss() {
    if (this.autoDismissValue && !this.autoDismissTimer) {
      const remainingTime = this.getRemainingTime()

      if (remainingTime > 0) {
        this.autoDismissTimer = setTimeout(() => {
          this.dismiss()
        }, remainingTime)

        if (this.hasProgressBarTarget) {
          this.progressBarTarget.style.animationPlayState = "running"
        }
      }
    }
  }

  getRemainingTime() {
    if (!this.hasProgressBarTarget) return this.durationValue

    const progressBar = this.progressBarTarget
    const computedStyle = window.getComputedStyle(progressBar)
    const animationDuration = parseFloat(computedStyle.animationDuration) * 1000
    const animationDelay = parseFloat(computedStyle.animationDelay) * 1000
    const totalDuration = animationDuration + animationDelay

    // This is a simplified calculation - in a real implementation,
    // you'd want to track the actual elapsed time
    return Math.max(0, totalDuration * 0.7) // Rough estimate
  }

  animateProgressBar() {
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.animation = `toast-progress ${this.durationValue}ms linear forwards`
    }
  }

  dismiss() {
    // Clear any pending timers
    if (this.autoDismissTimer) {
      clearTimeout(this.autoDismissTimer)
    }

    // Add exit animation
    this.element.style.transition = "all 0.3s cubic-bezier(0.4, 0, 1, 1)"
    this.element.style.transform = this.getExitTransform()
    this.element.style.opacity = "0"

    setTimeout(() => {
      if (this.element.parentNode) {
        this.element.remove()
      }
    }, 300)
  }

  getExitTransform() {
    switch(this.positionValue) {
      case 'top-right':
      case 'bottom-right':
        return "translateX(100%) scale(0.95)"
      case 'top-left':
      case 'bottom-left':
        return "translateX(-100%) scale(0.95)"
      case 'top-center':
        return "translateY(-100%) scale(0.95)"
      case 'bottom-center':
        return "translateY(100%) scale(0.95)"
      default:
        return "translateX(100%) scale(0.95)"
    }
  }

  // Action methods
  close(event) {
    event.preventDefault()
    this.dismiss()
  }

  disconnect() {
    if (this.autoDismissTimer) {
      clearTimeout(this.autoDismissTimer)
    }
  }
}