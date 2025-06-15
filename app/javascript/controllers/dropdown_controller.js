import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown"
export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.close = this.close.bind(this)
    this.handleKeydown = this.handleKeydown.bind(this)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (!this.hasMenuTarget) {
      console.warn("Dropdown menu target not found")
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

    // Close any other open dropdowns
    this.closeOtherDropdowns()

    this.menuTarget.classList.remove("hidden")
    document.addEventListener("click", this.close)
    document.addEventListener("keydown", this.handleKeydown)

    // Focus first menu item for accessibility
    const firstMenuItem = this.menuTarget.querySelector('a, button')
    if (firstMenuItem) {
      setTimeout(() => firstMenuItem.focus(), 10)
    }
  }

  close(event) {
    if (!this.hasMenuTarget) return

    if (event && this.element.contains(event.target)) {
      return
    }

    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this.handleKeydown)
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  closeOtherDropdowns() {
    // Close any other open dropdowns on the page
    document.querySelectorAll('[data-controller*="dropdown"] [data-dropdown-target="menu"]:not(.hidden)').forEach(menu => {
      if (menu !== this.menuTarget) {
        menu.classList.add("hidden")
      }
    })
  }

  disconnect() {
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this.handleKeydown)
  }
}