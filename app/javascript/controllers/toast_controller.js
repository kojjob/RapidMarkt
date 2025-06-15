import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]
  static values = {
    duration: { type: Number, default: 5000 },
    position: { type: String, default: "top-right" }
  }

  connect() {
    this.toasts = []
    this.setupEventListeners()
    this.ensureContainer()
  }

  setupEventListeners() {
    // Listen for toast events from other controllers
    document.addEventListener('template-canvas:showToast', (event) => {
      this.show(event.detail.message, event.detail.type)
    })
    
    document.addEventListener('properties-panel:showToast', (event) => {
      this.show(event.detail.message, event.detail.type)
    })
  }

  ensureContainer() {
    if (!this.hasContainerTarget) {
      this.createContainer()
    }
  }

  createContainer() {
    const container = document.createElement('div')
    container.className = this.getContainerClasses()
    container.setAttribute('data-toast-target', 'container')
    document.body.appendChild(container)
    this.containerTarget = container
  }

  getContainerClasses() {
    const baseClasses = 'fixed z-50 flex flex-col space-y-2 pointer-events-none'
    
    switch (this.positionValue) {
      case 'top-left':
        return `${baseClasses} top-4 left-4`
      case 'top-center':
        return `${baseClasses} top-4 left-1/2 transform -translate-x-1/2`
      case 'top-right':
        return `${baseClasses} top-4 right-4`
      case 'bottom-left':
        return `${baseClasses} bottom-4 left-4`
      case 'bottom-center':
        return `${baseClasses} bottom-4 left-1/2 transform -translate-x-1/2`
      case 'bottom-right':
        return `${baseClasses} bottom-4 right-4`
      default:
        return `${baseClasses} top-4 right-4`
    }
  }

  show(message, type = 'info', duration = null) {
    const toast = this.createToast(message, type)
    const toastDuration = duration || this.durationValue
    
    this.containerTarget.appendChild(toast)
    this.toasts.push(toast)
    
    // Trigger animation
    requestAnimationFrame(() => {
      toast.classList.remove('translate-x-full', 'opacity-0')
      toast.classList.add('translate-x-0', 'opacity-100')
    })
    
    // Auto-dismiss
    if (toastDuration > 0) {
      setTimeout(() => {
        this.dismiss(toast)
      }, toastDuration)
    }
    
    return toast
  }

  createToast(message, type) {
    const toast = document.createElement('div')
    toast.className = `transform transition-all duration-300 ease-in-out translate-x-full opacity-0 pointer-events-auto max-w-sm w-full ${this.getToastClasses(type)}`
    
    const icon = this.getIcon(type)
    const colors = this.getColors(type)
    
    toast.innerHTML = `
      <div class="${colors.bg} ${colors.border} border rounded-lg shadow-lg p-4">
        <div class="flex items-start">
          <div class="flex-shrink-0">
            <div class="${colors.icon} w-5 h-5">
              ${icon}
            </div>
          </div>
          <div class="ml-3 flex-1">
            <p class="${colors.text} text-sm font-medium">
              ${this.escapeHtml(message)}
            </p>
          </div>
          <div class="ml-4 flex-shrink-0 flex">
            <button class="${colors.closeButton} rounded-md inline-flex text-sm focus:outline-none focus:ring-2 focus:ring-offset-2 ${colors.focusRing}" data-action="click->toast#dismissToast">
              <span class="sr-only">Close</span>
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
              </svg>
            </button>
          </div>
        </div>
      </div>
    `
    
    return toast
  }

  getIcon(type) {
    const icons = {
      success: `
        <svg fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
        </svg>
      `,
      error: `
        <svg fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path>
        </svg>
      `,
      warning: `
        <svg fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path>
        </svg>
      `,
      info: `
        <svg fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path>
        </svg>
      `
    }
    
    return icons[type] || icons.info
  }

  getColors(type) {
    const colorSchemes = {
      success: {
        bg: 'bg-green-50',
        border: 'border-green-200',
        icon: 'text-green-400',
        text: 'text-green-800',
        closeButton: 'text-green-500 hover:text-green-600',
        focusRing: 'focus:ring-green-500'
      },
      error: {
        bg: 'bg-red-50',
        border: 'border-red-200',
        icon: 'text-red-400',
        text: 'text-red-800',
        closeButton: 'text-red-500 hover:text-red-600',
        focusRing: 'focus:ring-red-500'
      },
      warning: {
        bg: 'bg-yellow-50',
        border: 'border-yellow-200',
        icon: 'text-yellow-400',
        text: 'text-yellow-800',
        closeButton: 'text-yellow-500 hover:text-yellow-600',
        focusRing: 'focus:ring-yellow-500'
      },
      info: {
        bg: 'bg-blue-50',
        border: 'border-blue-200',
        icon: 'text-blue-400',
        text: 'text-blue-800',
        closeButton: 'text-blue-500 hover:text-blue-600',
        focusRing: 'focus:ring-blue-500'
      }
    }
    
    return colorSchemes[type] || colorSchemes.info
  }

  getToastClasses(type) {
    // Additional classes based on type if needed
    return ''
  }

  dismiss(toast) {
    if (!toast || !toast.parentNode) return
    
    // Animate out
    toast.classList.remove('translate-x-0', 'opacity-100')
    toast.classList.add('translate-x-full', 'opacity-0')
    
    // Remove from DOM after animation
    setTimeout(() => {
      if (toast.parentNode) {
        toast.parentNode.removeChild(toast)
      }
      
      // Remove from toasts array
      const index = this.toasts.indexOf(toast)
      if (index > -1) {
        this.toasts.splice(index, 1)
      }
    }, 300)
  }

  dismissToast(event) {
    const toast = event.target.closest('[data-toast-target="container"] > div')
    if (toast) {
      this.dismiss(toast)
    }
  }

  dismissAll() {
    this.toasts.forEach(toast => this.dismiss(toast))
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  // Public API methods
  success(message, duration = null) {
    return this.show(message, 'success', duration)
  }

  error(message, duration = null) {
    return this.show(message, 'error', duration)
  }

  warning(message, duration = null) {
    return this.show(message, 'warning', duration)
  }

  info(message, duration = null) {
    return this.show(message, 'info', duration)
  }

  // Persistent toast (doesn't auto-dismiss)
  persistent(message, type = 'info') {
    return this.show(message, type, 0)
  }
}