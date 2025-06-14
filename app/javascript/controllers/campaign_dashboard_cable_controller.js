import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["connectionStatus"]

  connect() {
    console.log("Campaign Dashboard Cable controller connected")
    this.setupCableConnection()
  }

  disconnect() {
    console.log("Campaign Dashboard Cable controller disconnected")
    this.teardownCableConnection()
  }

  setupCableConnection() {
    // Create ActionCable consumer
    this.consumer = createConsumer()
    
    // Subscribe to the campaign dashboard channel
    this.subscription = this.consumer.subscriptions.create(
      { channel: "CampaignDashboardChannel" },
      {
        connected: () => {
          console.log("Connected to CampaignDashboardChannel")
          this.updateConnectionStatus("connected")
        },

        disconnected: () => {
          console.log("Disconnected from CampaignDashboardChannel")
          this.updateConnectionStatus("disconnected")
        },

        received: (data) => {
          console.log("Received data from CampaignDashboardChannel:", data)
          this.handleReceivedData(data)
        },

        rejected: () => {
          console.log("Subscription to CampaignDashboardChannel was rejected")
          this.updateConnectionStatus("rejected")
        }
      }
    )
  }

  teardownCableConnection() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
    
    if (this.consumer) {
      this.consumer.disconnect()
      this.consumer = null
    }
  }

  handleReceivedData(data) {
    switch (data.type) {
      case 'dashboard_update':
        this.updateDashboard(data.data)
        break
      case 'campaign_status_change':
        this.updateCampaignStatus(data.data)
        break
      case 'new_activity':
        this.addNewActivity(data.data)
        break
      default:
        console.log("Unknown data type received:", data.type)
    }
  }

  updateDashboard(dashboardData) {
    // Dispatch a custom event that the dashboard controller can listen to
    const event = new CustomEvent('dashboard:update', {
      detail: dashboardData,
      bubbles: true
    })
    
    this.element.dispatchEvent(event)
  }

  updateCampaignStatus(campaignData) {
    // Find the campaign row and update its status
    const campaignRow = document.querySelector(`[data-campaign-id="${campaignData.id}"]`)
    if (campaignRow) {
      const statusBadge = campaignRow.querySelector('.status-badge')
      const statusDot = campaignRow.querySelector('.status-dot')
      
      if (statusBadge) {
        statusBadge.textContent = campaignData.status.charAt(0).toUpperCase() + campaignData.status.slice(1)
        statusBadge.className = `inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${this.getStatusClasses(campaignData.status)}`
      }
      
      if (statusDot) {
        statusDot.className = `w-3 h-3 rounded-full ${this.getStatusDotClasses(campaignData.status)}`
      }
    }
    
    // Show a toast notification
    this.showNotification(`Campaign "${campaignData.name}" status changed to ${campaignData.status}`, 'info')
  }

  addNewActivity(activityData) {
    // Add new activity to the activity feed
    const activityFeed = document.querySelector('[data-campaign-dashboard-target="activityFeed"]')
    if (activityFeed) {
      const activityHtml = this.createActivityHtml(activityData)
      const activityList = activityFeed.querySelector('.divide-y')
      
      if (activityList) {
        activityList.insertAdjacentHTML('afterbegin', activityHtml)
        
        // Remove the last activity if we have more than 20
        const activities = activityList.children
        if (activities.length > 20) {
          activities[activities.length - 1].remove()
        }
      }
    }
    
    // Show a toast notification
    this.showNotification(`${activityData.contact_email} ${activityData.action} campaign "${activityData.campaign_name}"`, 'success')
  }

  createActivityHtml(activity) {
    return `
      <div class="px-6 py-4 hover:bg-gray-50/50 transition-colors duration-200">
        <div class="flex items-start space-x-3">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-gradient-to-br from-green-100 to-emerald-200 rounded-lg flex items-center justify-center">
              <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
              </svg>
            </div>
          </div>
          <div class="min-w-0 flex-1">
            <p class="text-sm text-gray-900">
              <span class="font-medium">${activity.contact_email}</span>
              ${activity.action} campaign
              <span class="font-medium">${activity.campaign_name}</span>
            </p>
            <p class="text-xs text-gray-500 mt-1">
              Just now
            </p>
          </div>
        </div>
      </div>
    `
  }

  updateConnectionStatus(status) {
    if (this.hasConnectionStatusTarget) {
      const statusElement = this.connectionStatusTarget
      
      switch (status) {
        case 'connected':
          statusElement.innerHTML = `
            <div class="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
            <span class="text-xs text-gray-600">Live</span>
          `
          statusElement.className = "flex items-center space-x-2"
          break
        case 'disconnected':
          statusElement.innerHTML = `
            <div class="w-2 h-2 bg-red-500 rounded-full"></div>
            <span class="text-xs text-gray-600">Disconnected</span>
          `
          statusElement.className = "flex items-center space-x-2"
          break
        case 'rejected':
          statusElement.innerHTML = `
            <div class="w-2 h-2 bg-yellow-500 rounded-full"></div>
            <span class="text-xs text-gray-600">Connection Error</span>
          `
          statusElement.className = "flex items-center space-x-2"
          break
      }
    }
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

  showNotification(message, type = 'info') {
    // Create a simple toast notification
    const toast = document.createElement('div')
    toast.className = `fixed top-4 right-4 z-50 px-4 py-3 rounded-lg shadow-lg text-white text-sm max-w-sm transform transition-all duration-300 translate-x-full ${
      type === 'success' ? 'bg-green-500' : 
      type === 'error' ? 'bg-red-500' : 
      type === 'warning' ? 'bg-yellow-500' : 
      'bg-blue-500'
    }`
    toast.textContent = message
    
    document.body.appendChild(toast)
    
    // Animate in
    setTimeout(() => {
      toast.classList.remove('translate-x-full')
    }, 100)
    
    // Remove after 5 seconds
    setTimeout(() => {
      toast.classList.add('translate-x-full')
      setTimeout(() => {
        if (toast.parentNode) {
          toast.parentNode.removeChild(toast)
        }
      }, 300)
    }, 5000)
  }

  // Method to manually refresh data
  refreshData() {
    if (this.subscription) {
      this.subscription.perform('refresh_data')
    }
  }
}
