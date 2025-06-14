import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pauseButton", "resumeButton"]

  connect() {
    console.log("Campaign row controller connected")
  }

  pauseCampaign(event) {
    event.preventDefault()
    
    const campaignId = event.currentTarget.dataset.campaignId
    const button = event.currentTarget
    
    if (!campaignId) {
      console.error("No campaign ID found")
      return
    }

    // Disable button and show loading state
    button.disabled = true
    const originalText = button.innerHTML
    button.innerHTML = `
      <svg class="w-3 h-3 mr-1 animate-spin" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      Pausing...
    `

    // Make API call to pause campaign
    fetch(`/campaigns/${campaignId}/pause`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken(),
        'Accept': 'application/json'
      }
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      if (data.success) {
        this.showSuccessMessage('Campaign paused successfully')
        this.updateCampaignStatus('paused', button)
      } else {
        throw new Error(data.error || 'Failed to pause campaign')
      }
    })
    .catch(error => {
      console.error('Error pausing campaign:', error)
      this.showErrorMessage('Failed to pause campaign: ' + error.message)
      
      // Restore button state
      button.disabled = false
      button.innerHTML = originalText
    })
  }

  resumeCampaign(event) {
    event.preventDefault()
    
    const campaignId = event.currentTarget.dataset.campaignId
    const button = event.currentTarget
    
    if (!campaignId) {
      console.error("No campaign ID found")
      return
    }

    // Disable button and show loading state
    button.disabled = true
    const originalText = button.innerHTML
    button.innerHTML = `
      <svg class="w-3 h-3 mr-1 animate-spin" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      Resuming...
    `

    // Make API call to resume campaign
    fetch(`/campaigns/${campaignId}/resume`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken(),
        'Accept': 'application/json'
      }
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      if (data.success) {
        this.showSuccessMessage('Campaign resumed successfully')
        this.updateCampaignStatus('sending', button)
      } else {
        throw new Error(data.error || 'Failed to resume campaign')
      }
    })
    .catch(error => {
      console.error('Error resuming campaign:', error)
      this.showErrorMessage('Failed to resume campaign: ' + error.message)
      
      // Restore button state
      button.disabled = false
      button.innerHTML = originalText
    })
  }

  stopCampaign(event) {
    event.preventDefault()

    const campaignId = event.currentTarget.dataset.campaignId
    const button = event.currentTarget

    if (!campaignId) {
      console.error("No campaign ID found")
      return
    }

    if (!confirm('Are you sure you want to stop this campaign? This action cannot be undone.')) {
      return
    }

    // Disable button and show loading state
    button.disabled = true
    const originalText = button.innerHTML
    button.innerHTML = `
      <svg class="w-3 h-3 mr-1 animate-spin" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      Stopping...
    `

    // Make API call to stop campaign
    fetch(`/campaigns/${campaignId}/stop`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken(),
        'Accept': 'application/json'
      }
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      if (data.success) {
        this.showSuccessMessage('Campaign stopped successfully')
        this.updateCampaignStatus('cancelled', button)
      } else {
        throw new Error(data.error || 'Failed to stop campaign')
      }
    })
    .catch(error => {
      console.error('Error stopping campaign:', error)
      this.showErrorMessage('Failed to stop campaign: ' + error.message)

      // Restore button state
      button.disabled = false
      button.innerHTML = originalText
    })
  }

  duplicateCampaign(event) {
    event.preventDefault()

    const campaignId = event.currentTarget.dataset.campaignId

    if (!campaignId) {
      console.error("No campaign ID found")
      return
    }

    if (!confirm('Are you sure you want to duplicate this campaign?')) {
      return
    }

    // Make API call to duplicate campaign
    fetch(`/campaigns/${campaignId}/duplicate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken(),
        'Accept': 'application/json'
      }
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      if (data.success) {
        this.showSuccessMessage('Campaign duplicated successfully')
        // Optionally redirect to the new campaign
        if (data.redirect_url) {
          window.location.href = data.redirect_url
        } else {
          // Refresh the page to show the new campaign
          window.location.reload()
        }
      } else {
        throw new Error(data.error || 'Failed to duplicate campaign')
      }
    })
    .catch(error => {
      console.error('Error duplicating campaign:', error)
      this.showErrorMessage('Failed to duplicate campaign: ' + error.message)
    })
  }

  updateCampaignStatus(newStatus, button) {
    // Update the status badge
    const statusBadge = this.element.querySelector('.status-badge')
    if (statusBadge) {
      statusBadge.textContent = newStatus.charAt(0).toUpperCase() + newStatus.slice(1)
      
      // Update badge classes based on status
      statusBadge.className = `inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${this.getStatusClasses(newStatus)}`
    }

    // Update the status indicator dot
    const statusDot = this.element.querySelector('.status-dot')
    if (statusDot) {
      statusDot.className = `w-3 h-3 rounded-full ${this.getStatusDotClasses(newStatus)}`
    }

    // Update button based on new status
    if (newStatus === 'paused') {
      button.innerHTML = `
        <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h1m4 0h1m-6 4h8m-9-4h10a2 2 0 012 2v8a2 2 0 01-2 2H6a2 2 0 01-2-2v-8a2 2 0 012-2z" />
        </svg>
        Resume
      `
      button.className = "inline-flex items-center px-3 py-1 border border-green-200 rounded-lg text-xs font-medium text-green-700 bg-green-50 hover:bg-green-100 transition-colors duration-200"
      button.dataset.action = "click->campaign-row#resumeCampaign"
    } else if (newStatus === 'sending') {
      button.innerHTML = `
        <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        Pause
      `
      button.className = "inline-flex items-center px-3 py-1 border border-orange-200 rounded-lg text-xs font-medium text-orange-700 bg-orange-50 hover:bg-orange-100 transition-colors duration-200"
      button.dataset.action = "click->campaign-row#pauseCampaign"
    }

    button.disabled = false
  }

  getStatusClasses(status) {
    const statusClasses = {
      'draft': 'bg-gray-100 text-gray-800',
      'scheduled': 'bg-blue-100 text-blue-800',
      'sending': 'bg-yellow-100 text-yellow-800',
      'sent': 'bg-green-100 text-green-800',
      'paused': 'bg-orange-100 text-orange-800',
      'cancelled': 'bg-red-100 text-red-800'
    }
    return statusClasses[status] || 'bg-gray-100 text-gray-800'
  }

  getStatusDotClasses(status) {
    const dotClasses = {
      'draft': 'bg-gray-500',
      'scheduled': 'bg-blue-500',
      'sending': 'bg-yellow-500 animate-pulse',
      'sent': 'bg-green-500',
      'paused': 'bg-orange-500',
      'cancelled': 'bg-red-500'
    }
    return dotClasses[status] || 'bg-gray-500'
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }

  showSuccessMessage(message) {
    // You can implement a toast notification system here
    console.log('Success:', message)
    // For now, just show an alert
    // In a real app, you'd want to use a proper notification system
  }

  showErrorMessage(message) {
    // You can implement a toast notification system here
    console.error('Error:', message)
    // For now, just show an alert
    alert(message)
  }
}
