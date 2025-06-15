import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="preview-carousel"
export default class extends Controller {
  static targets = ["deviceToggle", "frame", "container"]
  static values = { currentDevice: String }

  connect() {
    this.currentDeviceValue = "desktop"
    this.updateDeviceView()
  }

  // Switch between device previews
  switchDevice(event) {
    const device = event.currentTarget.dataset.device
    this.currentDeviceValue = device
    this.updateDeviceView()
  }

  // Update the device view and toggle buttons
  updateDeviceView() {
    // Update toggle button states
    this.deviceToggleTargets.forEach(toggle => {
      const device = toggle.dataset.device
      if (device === this.currentDeviceValue) {
        toggle.classList.remove('bg-gray-200', 'text-gray-700')
        toggle.classList.add('bg-gray-600', 'text-white')
      } else {
        toggle.classList.remove('bg-gray-600', 'text-white')
        toggle.classList.add('bg-gray-200', 'text-gray-700')
      }
    })

    // Update frame visibility with smooth transition
    this.frameTargets.forEach(frame => {
      const device = frame.dataset.device
      if (device === this.currentDeviceValue) {
        frame.classList.remove('hidden')
        // Trigger animation
        setTimeout(() => {
          frame.style.opacity = '1'
          frame.style.transform = 'scale(1)'
        }, 10)
      } else {
        frame.style.opacity = '0'
        frame.style.transform = 'scale(0.95)'
        setTimeout(() => {
          frame.classList.add('hidden')
        }, 200)
      }
    })

    // Update container width based on device
    this.updateContainerWidth()
  }

  // Update container width for responsive preview
  updateContainerWidth() {
    const container = this.containerTarget
    
    switch (this.currentDeviceValue) {
      case 'desktop':
        container.style.maxWidth = '800px'
        container.style.width = '100%'
        break
      case 'tablet':
        container.style.maxWidth = '768px'
        container.style.width = '768px'
        break
      case 'mobile':
        container.style.maxWidth = '375px'
        container.style.width = '375px'
        break
    }
  }

  // Load preview content for current device
  loadPreview(content) {
    const currentFrame = this.frameTargets.find(frame => 
      frame.dataset.device === this.currentDeviceValue && !frame.classList.contains('hidden')
    )
    
    if (currentFrame) {
      const contentArea = currentFrame.querySelector('.bg-white')
      if (contentArea) {
        contentArea.innerHTML = content || this.getDefaultPreviewContent()
      }
    }
  }

  // Get default preview content
  getDefaultPreviewContent() {
    const device = this.currentDeviceValue
    const deviceName = device.charAt(0).toUpperCase() + device.slice(1)
    
    return `
      <div class="text-center text-gray-500 py-8">
        <svg class="mx-auto h-12 w-12 text-gray-400 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
        </svg>
        <p class="text-sm">${deviceName} email preview will appear here</p>
        <p class="text-xs text-gray-400 mt-2">Complete the email content step to see your preview</p>
      </div>
    `
  }

  // Refresh preview with current campaign data
  refreshPreview() {
    // This would typically fetch the latest preview from the server
    // For now, we'll just update with placeholder content
    this.loadPreview()
  }

  // Handle window resize for responsive behavior
  handleResize() {
    this.updateContainerWidth()
  }

  // Keyboard navigation
  keydown(event) {
    switch (event.key) {
      case 'ArrowLeft':
        this.previousDevice()
        break
      case 'ArrowRight':
        this.nextDevice()
        break
      case '1':
        this.currentDeviceValue = 'desktop'
        this.updateDeviceView()
        break
      case '2':
        this.currentDeviceValue = 'tablet'
        this.updateDeviceView()
        break
      case '3':
        this.currentDeviceValue = 'mobile'
        this.updateDeviceView()
        break
    }
  }

  // Navigate to previous device
  previousDevice() {
    const devices = ['desktop', 'tablet', 'mobile']
    const currentIndex = devices.indexOf(this.currentDeviceValue)
    const previousIndex = currentIndex > 0 ? currentIndex - 1 : devices.length - 1
    this.currentDeviceValue = devices[previousIndex]
    this.updateDeviceView()
  }

  // Navigate to next device
  nextDevice() {
    const devices = ['desktop', 'tablet', 'mobile']
    const currentIndex = devices.indexOf(this.currentDeviceValue)
    const nextIndex = currentIndex < devices.length - 1 ? currentIndex + 1 : 0
    this.currentDeviceValue = devices[nextIndex]
    this.updateDeviceView()
  }

  // Get current device
  getCurrentDevice() {
    return this.currentDeviceValue
  }

  // Set device programmatically
  setDevice(device) {
    if (['desktop', 'tablet', 'mobile'].includes(device)) {
      this.currentDeviceValue = device
      this.updateDeviceView()
    }
  }

  // Handle value changes
  currentDeviceValueChanged() {
    this.updateDeviceView()
  }

  // Cleanup
  disconnect() {
    // Remove any event listeners if needed
  }
}
