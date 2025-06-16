import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="mobile-sidebar"
export default class extends Controller {
  static targets = ["sidebar", "overlay", "menuButton"]

  connect() {
    // Ensure sidebar starts hidden on mobile
    this.close()
    
    // Initialize touch handling for swipe gestures
    this.initializeTouchHandling()
    
    // Store initial focus element
    this.lastFocusedElement = null
  }

  toggle() {
    if (this.sidebarTarget.classList.contains("-translate-x-full")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    // Store current focus
    this.lastFocusedElement = document.activeElement
    
    // Show overlay with smooth transition
    this.overlayTarget.classList.remove("hidden")
    // Force reflow to ensure the element is visible before transitioning
    this.overlayTarget.offsetHeight
    this.overlayTarget.style.opacity = "1"
    
    // Show sidebar
    this.sidebarTarget.classList.remove("-translate-x-full")
    this.sidebarTarget.classList.add("translate-x-0")
    
    // Update aria attributes
    if (this.hasMenuButtonTarget) {
      this.menuButtonTarget.setAttribute("aria-expanded", "true")
      this.menuButtonTarget.setAttribute("aria-label", "Close navigation menu")
    }
    
    // Prevent body scroll
    document.body.style.overflow = "hidden"
    
    // Focus first focusable element in sidebar after a short delay to allow animation
    setTimeout(() => {
      this.focusFirstElement()
    }, 300)
    
    // Add event listeners for accessibility
    document.addEventListener("keydown", this.handleKeydown.bind(this))
  }

  close() {
    // Fade out overlay first
    this.overlayTarget.style.opacity = "0"
    
    // Hide sidebar
    this.sidebarTarget.classList.add("-translate-x-full")
    this.sidebarTarget.classList.remove("translate-x-0")
    
    // Hide overlay after transition completes
    setTimeout(() => {
      this.overlayTarget.classList.add("hidden")
      this.overlayTarget.style.opacity = ""
    }, 300)
    
    // Update aria attributes
    if (this.hasMenuButtonTarget) {
      this.menuButtonTarget.setAttribute("aria-expanded", "false")
      this.menuButtonTarget.setAttribute("aria-label", "Open navigation menu")
    }
    
    // Restore body scroll
    document.body.style.overflow = ""
    
    // Remove event listeners
    document.removeEventListener("keydown", this.handleKeydown.bind(this))
    
    // Restore focus to previous element
    if (this.lastFocusedElement) {
      this.lastFocusedElement.focus()
      this.lastFocusedElement = null
    }
  }

  // Close sidebar when clicking outside (on overlay)
  overlayClicked() {
    this.close()
  }

  // Close sidebar when pressing escape key
  keydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  disconnect() {
    // Cleanup: restore body scroll when controller is disconnected
    document.body.style.overflow = ""
    
    // Remove touch event listeners
    this.removeTouchHandling()
    
    // Remove keyboard event listeners
    document.removeEventListener("keydown", this.handleKeydown.bind(this))
  }

  // Initialize touch handling for swipe gestures
  initializeTouchHandling() {
    this.touchStartX = 0
    this.touchStartY = 0
    this.touchCurrentX = 0
    this.touchCurrentY = 0
    this.isSwipingLeft = false
    
    // Add touch event listeners to sidebar and overlay
    this.sidebarTarget.addEventListener("touchstart", this.handleTouchStart.bind(this), { passive: true })
    this.sidebarTarget.addEventListener("touchmove", this.handleTouchMove.bind(this), { passive: false })
    this.sidebarTarget.addEventListener("touchend", this.handleTouchEnd.bind(this), { passive: true })
    
    this.overlayTarget.addEventListener("touchstart", this.handleTouchStart.bind(this), { passive: true })
    this.overlayTarget.addEventListener("touchmove", this.handleTouchMove.bind(this), { passive: false })
    this.overlayTarget.addEventListener("touchend", this.handleTouchEnd.bind(this), { passive: true })
  }

  // Remove touch event listeners
  removeTouchHandling() {
    if (this.sidebarTarget) {
      this.sidebarTarget.removeEventListener("touchstart", this.handleTouchStart.bind(this))
      this.sidebarTarget.removeEventListener("touchmove", this.handleTouchMove.bind(this))
      this.sidebarTarget.removeEventListener("touchend", this.handleTouchEnd.bind(this))
    }
    
    if (this.overlayTarget) {
      this.overlayTarget.removeEventListener("touchstart", this.handleTouchStart.bind(this))
      this.overlayTarget.removeEventListener("touchmove", this.handleTouchMove.bind(this))
      this.overlayTarget.removeEventListener("touchend", this.handleTouchEnd.bind(this))
    }
  }

  // Handle touch start
  handleTouchStart(event) {
    this.touchStartX = event.touches[0].clientX
    this.touchStartY = event.touches[0].clientY
    this.isSwipingLeft = false
  }

  // Handle touch move
  handleTouchMove(event) {
    if (!event.touches[0]) return
    
    this.touchCurrentX = event.touches[0].clientX
    this.touchCurrentY = event.touches[0].clientY
    
    const deltaX = this.touchStartX - this.touchCurrentX
    const deltaY = Math.abs(this.touchStartY - this.touchCurrentY)
    
    // Check if this is a horizontal swipe (more horizontal than vertical movement)
    if (Math.abs(deltaX) > deltaY && Math.abs(deltaX) > 30) {
      this.isSwipingLeft = deltaX > 0
      
      // Prevent default scrolling when swiping
      event.preventDefault()
      
      // Add visual feedback during swipe
      if (this.isSwipingLeft && deltaX > 50) {
        const opacity = Math.max(0.3, 1 - (deltaX - 50) / 200)
        this.sidebarTarget.style.opacity = opacity
        this.overlayTarget.style.opacity = opacity
      }
    }
  }

  // Handle touch end
  handleTouchEnd(event) {
    const deltaX = this.touchStartX - this.touchCurrentX
    const deltaY = Math.abs(this.touchStartY - this.touchCurrentY)
    
    // Reset visual feedback
    this.sidebarTarget.style.opacity = ""
    this.overlayTarget.style.opacity = ""
    
    // If it was a left swipe with sufficient distance, close the sidebar
    if (this.isSwipingLeft && deltaX > 100 && Math.abs(deltaX) > deltaY) {
      this.close()
    }
    
    // Reset touch tracking
    this.touchStartX = 0
    this.touchStartY = 0
    this.touchCurrentX = 0
    this.touchCurrentY = 0
    this.isSwipingLeft = false
  }

  // Handle keyboard navigation
  handleKeydown(event) {
    // Close on Escape key
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
      return
    }
    
    // Trap focus within sidebar
    if (event.key === "Tab") {
      this.trapFocus(event)
    }
  }

  // Focus first focusable element in sidebar
  focusFirstElement() {
    const focusableElements = this.getFocusableElements()
    if (focusableElements.length > 0) {
      focusableElements[0].focus()
    }
  }

  // Get all focusable elements within sidebar
  getFocusableElements() {
    const focusableSelectors = [
      'a[href]',
      'button:not([disabled])',
      'input:not([disabled])',
      'select:not([disabled])',
      'textarea:not([disabled])',
      '[tabindex]:not([tabindex="-1"])'
    ]
    
    return Array.from(this.sidebarTarget.querySelectorAll(focusableSelectors.join(', ')))
      .filter(element => {
        return element.offsetWidth > 0 && element.offsetHeight > 0 && !element.hidden
      })
  }

  // Trap focus within sidebar
  trapFocus(event) {
    const focusableElements = this.getFocusableElements()
    const firstElement = focusableElements[0]
    const lastElement = focusableElements[focusableElements.length - 1]
    
    if (event.shiftKey) {
      // Shift + Tab: moving backwards
      if (document.activeElement === firstElement) {
        event.preventDefault()
        lastElement.focus()
      }
    } else {
      // Tab: moving forwards
      if (document.activeElement === lastElement) {
        event.preventDefault()
        firstElement.focus()
      }
    }
  }
}