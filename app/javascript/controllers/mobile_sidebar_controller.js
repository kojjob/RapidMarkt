import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="mobile-sidebar"
export default class extends Controller {
  static targets = ["sidebar", "overlay", "menuButton", "searchInput", "clearSearch", "navigationList"]

  connect() {
    // Ensure sidebar starts hidden on mobile
    this.close()
    
    // Initialize touch handling for swipe gestures
    this.initializeTouchHandling()
    
    // Store initial focus element
    this.lastFocusedElement = null
    
    // Initialize search functionality
    this.originalNavigationHTML = this.navigationListTarget.innerHTML
    this.searchResults = []
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
    
    // Track usage
    this.trackUsage('sidebar_opened')
    
    // Initialize gesture shortcuts
    this.addGestureShortcuts()
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
    
    // Track usage
    this.trackUsage('sidebar_closed')
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

  // Search functionality
  search(event) {
    const query = event.target.value.toLowerCase().trim()
    
    if (query === '') {
      this.clearSearch()
      return
    }
    
    // Show clear button
    if (this.hasClearSearchTarget) {
      this.clearSearchTarget.classList.remove('hidden')
    }
    
    // Search through navigation items
    const navigationLinks = this.navigationListTarget.querySelectorAll('a[data-search-terms]')
    const searchResults = []
    
    navigationLinks.forEach(link => {
      const searchTerms = link.dataset.searchTerms.toLowerCase()
      const linkText = link.textContent.toLowerCase()
      
      if (searchTerms.includes(query) || linkText.includes(query)) {
        searchResults.push(link.cloneNode(true))
      }
    })
    
    // Display search results
    this.displaySearchResults(searchResults, query)
  }

  displaySearchResults(results, query) {
    if (results.length === 0) {
      this.navigationListTarget.innerHTML = `
        <div class="px-4 py-8 text-center">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">No results found</h3>
          <p class="mt-1 text-sm text-gray-500">Try searching for a different term</p>
        </div>
      `
      return
    }
    
    // Create search results HTML
    const resultsHTML = `
      <div class="px-2 mb-4">
        <h4 class="px-2 mb-2 text-xs font-semibold text-gray-500 uppercase tracking-wider">
          Search Results (${results.length})
        </h4>
        <div class="space-y-1">
          ${results.map(link => {
            // Highlight search terms
            const linkHTML = link.outerHTML.replace(
              new RegExp(`(${query})`, 'gi'),
              '<mark class="bg-yellow-200 text-gray-900 px-1 rounded">$1</mark>'
            )
            return linkHTML
          }).join('')}
        </div>
      </div>
    `
    
    this.navigationListTarget.innerHTML = resultsHTML
  }

  clearSearch() {
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ''
    }
    
    if (this.hasClearSearchTarget) {
      this.clearSearchTarget.classList.add('hidden')
    }
    
    // Restore original navigation
    this.navigationListTarget.innerHTML = this.originalNavigationHTML
  }

  handleSearchKeydown(event) {
    if (event.key === 'Escape') {
      this.clearSearch()
      this.searchInputTarget.blur()
    } else if (event.key === 'Enter') {
      // If there's only one result, navigate to it
      const firstResult = this.navigationListTarget.querySelector('a')
      if (firstResult && this.navigationListTarget.querySelectorAll('a').length === 1) {
        firstResult.click()
      }
    }
  }

  // Enhanced gesture shortcuts
  addGestureShortcuts() {
    // Double tap to search
    let tapCount = 0
    let tapTimer = null
    
    this.sidebarTarget.addEventListener('touchend', (e) => {
      tapCount++
      
      if (tapCount === 1) {
        tapTimer = setTimeout(() => {
          tapCount = 0
        }, 300)
      } else if (tapCount === 2) {
        clearTimeout(tapTimer)
        tapCount = 0
        
        // Focus search input on double tap
        if (this.hasSearchInputTarget) {
          this.searchInputTarget.focus()
        }
      }
    })
  }

  // Track usage analytics
  trackUsage(action, data = {}) {
    // Simple usage tracking - can be extended with analytics service
    const event = {
      timestamp: new Date().toISOString(),
      action: action,
      data: data,
      userAgent: navigator.userAgent
    }
    
    // Store in localStorage for now (can be sent to analytics service)
    const usage = JSON.parse(localStorage.getItem('mobileSidebarUsage') || '[]')
    usage.push(event)
    
    // Keep only last 100 events
    if (usage.length > 100) {
      usage.splice(0, usage.length - 100)
    }
    
    localStorage.setItem('mobileSidebarUsage', JSON.stringify(usage))
  }
}