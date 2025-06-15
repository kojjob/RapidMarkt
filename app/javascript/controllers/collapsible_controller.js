import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="collapsible"
export default class extends Controller {
  static targets = ["content", "toggle", "icon"]
  static values = { 
    expanded: Boolean,
    duration: Number,
    saveState: Boolean,
    storageKey: String
  }

  connect() {
    this.durationValue = this.durationValue || 300
    this.saveStateValue = this.saveStateValue !== false
    this.storageKeyValue = this.storageKeyValue || `collapsible_${this.element.id || Math.random()}`
    
    // Restore saved state if enabled
    if (this.saveStateValue) {
      const savedState = localStorage.getItem(this.storageKeyValue)
      if (savedState !== null) {
        this.expandedValue = savedState === 'true'
      }
    }
    
    this.updateUI(false) // Don't animate on initial load
  }

  // Toggle expanded state
  toggle() {
    this.expandedValue = !this.expandedValue
    this.updateUI(true)
    
    // Save state if enabled
    if (this.saveStateValue) {
      localStorage.setItem(this.storageKeyValue, this.expandedValue.toString())
    }
    
    // Dispatch custom event
    this.dispatch('toggled', { 
      detail: { 
        expanded: this.expandedValue,
        element: this.element 
      }
    })
  }

  // Expand the section
  expand() {
    if (!this.expandedValue) {
      this.toggle()
    }
  }

  // Collapse the section
  collapse() {
    if (this.expandedValue) {
      this.toggle()
    }
  }

  // Update UI based on expanded state
  updateUI(animate = true) {
    if (!this.hasContentTarget) return

    const content = this.contentTarget
    const duration = animate ? this.durationValue : 0

    if (this.expandedValue) {
      this.showContent(content, duration)
    } else {
      this.hideContent(content, duration)
    }

    this.updateToggleButton()
    this.updateIcon()
  }

  // Show content with animation
  showContent(content, duration) {
    // Set initial state for animation
    content.style.display = 'block'
    content.style.overflow = 'hidden'
    
    if (duration > 0) {
      // Get the natural height
      const naturalHeight = content.scrollHeight
      content.style.height = '0px'
      content.style.opacity = '0'
      
      // Force reflow
      content.offsetHeight
      
      // Animate to natural height
      content.style.transition = `height ${duration}ms ease-out, opacity ${duration}ms ease-out`
      content.style.height = naturalHeight + 'px'
      content.style.opacity = '1'
      
      // Clean up after animation
      setTimeout(() => {
        content.style.height = 'auto'
        content.style.overflow = 'visible'
        content.style.transition = ''
      }, duration)
    } else {
      content.style.height = 'auto'
      content.style.opacity = '1'
      content.style.overflow = 'visible'
    }
  }

  // Hide content with animation
  hideContent(content, duration) {
    if (duration > 0) {
      // Set current height explicitly
      const currentHeight = content.scrollHeight
      content.style.height = currentHeight + 'px'
      content.style.overflow = 'hidden'
      
      // Force reflow
      content.offsetHeight
      
      // Animate to zero height
      content.style.transition = `height ${duration}ms ease-out, opacity ${duration}ms ease-out`
      content.style.height = '0px'
      content.style.opacity = '0'
      
      // Hide after animation
      setTimeout(() => {
        content.style.display = 'none'
        content.style.transition = ''
      }, duration)
    } else {
      content.style.display = 'none'
      content.style.opacity = '0'
      content.style.height = '0px'
    }
  }

  // Update toggle button appearance
  updateToggleButton() {
    if (!this.hasToggleTarget) return

    const toggle = this.toggleTarget
    
    if (this.expandedValue) {
      toggle.classList.add('expanded')
      toggle.classList.remove('collapsed')
      toggle.setAttribute('aria-expanded', 'true')
    } else {
      toggle.classList.add('collapsed')
      toggle.classList.remove('expanded')
      toggle.setAttribute('aria-expanded', 'false')
    }
  }

  // Update icon rotation
  updateIcon() {
    if (!this.hasIconTarget) return

    const icon = this.iconTarget
    
    if (this.expandedValue) {
      icon.style.transform = 'rotate(180deg)'
      icon.classList.add('rotate-180')
    } else {
      icon.style.transform = 'rotate(0deg)'
      icon.classList.remove('rotate-180')
    }
  }

  // Handle expanded value changes
  expandedValueChanged() {
    this.updateUI(true)
  }

  // Keyboard navigation
  keydown(event) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault()
      this.toggle()
    }
  }

  // Handle clicks on the toggle button
  toggleClicked(event) {
    event.preventDefault()
    this.toggle()
  }

  // Utility methods for external control
  isExpanded() {
    return this.expandedValue
  }

  isCollapsed() {
    return !this.expandedValue
  }

  // Batch operations for multiple collapsibles
  static expandAll(selector = '[data-controller*="collapsible"]') {
    document.querySelectorAll(selector).forEach(element => {
      const controller = this.application.getControllerForElementAndIdentifier(element, 'collapsible')
      if (controller) {
        controller.expand()
      }
    })
  }

  static collapseAll(selector = '[data-controller*="collapsible"]') {
    document.querySelectorAll(selector).forEach(element => {
      const controller = this.application.getControllerForElementAndIdentifier(element, 'collapsible')
      if (controller) {
        controller.collapse()
      }
    })
  }

  // Smooth scroll to element when expanded
  scrollIntoView() {
    if (this.expandedValue) {
      this.element.scrollIntoView({ 
        behavior: 'smooth', 
        block: 'nearest' 
      })
    }
  }

  // Auto-expand based on validation errors
  expandIfHasErrors() {
    const hasErrors = this.contentTarget?.querySelector('.field-error, .error, [aria-invalid="true"]')
    if (hasErrors && !this.expandedValue) {
      this.expand()
      setTimeout(() => this.scrollIntoView(), this.durationValue)
    }
  }

  // Initialize with error checking
  checkForErrors() {
    this.expandIfHasErrors()
  }
}
