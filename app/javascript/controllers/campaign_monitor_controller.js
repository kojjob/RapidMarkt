import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="campaign-monitor"
export default class extends Controller {
  static targets = [
    "statusText", "lastUpdated", "sentCount", "openRate", "clickRate", "revenue",
    "deliveredCount", "bouncedCount", "pendingCount", "deliveryRate",
    "uniqueOpens", "totalOpens", "uniqueClicks", "totalClicks", "ctor",
    "totalRevenue", "conversions", "conversionRate", "revenuePerEmail",
    "opensChart", "clicksChart", "timeRange", "activityFeed", "loadMoreButton",
    "autoRefresh", "updateIndicator"
  ]
  
  static values = { 
    campaignId: String,
    refreshInterval: Number,
    autoRefreshEnabled: Boolean
  }

  connect() {
    this.refreshIntervalValue = this.refreshIntervalValue || 30000 // 30 seconds
    this.autoRefreshEnabledValue = this.autoRefreshEnabledValue !== false
    this.activityOffset = 0
    
    this.initializeCharts()
    this.loadInitialData()
    this.startAutoRefresh()
  }

  disconnect() {
    this.stopAutoRefresh()
  }

  // Initialize chart containers
  initializeCharts() {
    // This would typically initialize Chart.js or similar
    // For now, we'll create placeholder charts
    this.createPlaceholderChart(this.opensChartTarget, 'Opens Over Time')
    this.createPlaceholderChart(this.clicksChartTarget, 'Clicks Over Time')
  }

  // Create placeholder chart
  createPlaceholderChart(container, title) {
    container.innerHTML = `
      <div class="flex items-center justify-center h-full">
        <div class="text-center">
          <div class="w-16 h-16 mx-auto mb-4 bg-gray-100 rounded-lg flex items-center justify-center">
            <svg class="w-8 h-8 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
            </svg>
          </div>
          <p class="text-sm text-gray-600">${title}</p>
          <p class="text-xs text-gray-400 mt-1">Chart data will appear here</p>
        </div>
      </div>
    `
  }

  // Load initial campaign data
  async loadInitialData() {
    try {
      await this.refreshMetrics()
      await this.loadActivityFeed()
    } catch (error) {
      console.error('Failed to load initial data:', error)
      this.showError('Failed to load campaign data')
    }
  }

  // Refresh all metrics
  async refreshMetrics() {
    try {
      const response = await fetch(`/campaigns/${this.campaignIdValue}/metrics`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      if (response.ok) {
        const data = await response.json()
        this.updateMetrics(data)
        this.updateLastUpdated()
      }
    } catch (error) {
      console.error('Failed to refresh metrics:', error)
    }
  }

  // Update metrics display
  updateMetrics(data) {
    // Update header stats
    if (this.hasSentCountTarget) this.sentCountTarget.textContent = this.formatNumber(data.sent_count)
    if (this.hasOpenRateTarget) this.openRateTarget.textContent = this.formatPercentage(data.open_rate)
    if (this.hasClickRateTarget) this.clickRateTarget.textContent = this.formatPercentage(data.click_rate)
    if (this.hasRevenueTarget) this.revenueTarget.textContent = '$' + this.formatNumber(data.revenue)

    // Update delivery metrics
    if (this.hasDeliveredCountTarget) this.deliveredCountTarget.textContent = this.formatNumber(data.delivered_count)
    if (this.hasBouncedCountTarget) this.bouncedCountTarget.textContent = this.formatNumber(data.bounced_count)
    if (this.hasPendingCountTarget) this.pendingCountTarget.textContent = this.formatNumber(data.pending_count)
    if (this.hasDeliveryRateTarget) this.deliveryRateTarget.textContent = this.formatPercentage(data.delivery_rate)

    // Update engagement metrics
    if (this.hasUniqueOpensTarget) this.uniqueOpensTarget.textContent = this.formatNumber(data.unique_opens)
    if (this.hasTotalOpensTarget) this.totalOpensTarget.textContent = this.formatNumber(data.total_opens)
    if (this.hasUniqueClicksTarget) this.uniqueClicksTarget.textContent = this.formatNumber(data.unique_clicks)
    if (this.hasTotalClicksTarget) this.totalClicksTarget.textContent = this.formatNumber(data.total_clicks)
    if (this.hasCtorTarget) this.ctorTarget.textContent = this.formatPercentage(data.click_to_open_rate)

    // Update revenue metrics
    if (this.hasTotalRevenueTarget) this.totalRevenueTarget.textContent = '$' + this.formatNumber(data.total_revenue)
    if (this.hasConversionsTarget) this.conversionsTarget.textContent = this.formatNumber(data.conversions)
    if (this.hasConversionRateTarget) this.conversionRateTarget.textContent = this.formatPercentage(data.conversion_rate)
    if (this.hasRevenuePerEmailTarget) this.revenuePerEmailTarget.textContent = '$' + this.formatDecimal(data.revenue_per_email)

    // Update status
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = data.status.charAt(0).toUpperCase() + data.status.slice(1)
    }
  }

  // Load activity feed
  async loadActivityFeed(offset = 0) {
    try {
      const response = await fetch(`/campaigns/${this.campaignIdValue}/activity?offset=${offset}`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      if (response.ok) {
        const data = await response.json()
        this.updateActivityFeed(data.activities, offset === 0)
        
        // Hide load more button if no more activities
        if (this.hasLoadMoreButtonTarget) {
          this.loadMoreButtonTarget.style.display = data.has_more ? 'block' : 'none'
        }
      }
    } catch (error) {
      console.error('Failed to load activity feed:', error)
    }
  }

  // Update activity feed display
  updateActivityFeed(activities, replace = false) {
    if (replace) {
      this.activityFeedTarget.innerHTML = ''
    }

    if (activities.length === 0 && replace) {
      this.activityFeedTarget.innerHTML = `
        <div class="text-center py-8 text-gray-500">
          <svg class="mx-auto h-12 w-12 text-gray-400 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <p class="text-sm">No recent activity</p>
        </div>
      `
      return
    }

    activities.forEach(activity => {
      const activityElement = this.createActivityElement(activity)
      this.activityFeedTarget.appendChild(activityElement)
    })
  }

  // Create activity element
  createActivityElement(activity) {
    const div = document.createElement('div')
    div.className = 'flex items-start space-x-3 p-4 bg-gray-50 rounded-lg border border-gray-200'
    
    const iconColor = this.getActivityIconColor(activity.type)
    const icon = this.getActivityIcon(activity.type)
    
    div.innerHTML = `
      <div class="flex-shrink-0">
        <div class="w-8 h-8 ${iconColor} rounded-lg flex items-center justify-center">
          ${icon}
        </div>
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-sm font-medium text-gray-900">${activity.title}</p>
        <p class="text-sm text-gray-600">${activity.description}</p>
        <p class="text-xs text-gray-400 mt-1">${this.formatTimestamp(activity.timestamp)}</p>
      </div>
    `
    
    return div
  }

  // Get activity icon color
  getActivityIconColor(type) {
    const colors = {
      'email_sent': 'bg-blue-100',
      'email_opened': 'bg-green-100',
      'link_clicked': 'bg-purple-100',
      'email_bounced': 'bg-red-100',
      'unsubscribed': 'bg-yellow-100'
    }
    return colors[type] || 'bg-gray-100'
  }

  // Get activity icon
  getActivityIcon(type) {
    const icons = {
      'email_sent': '<svg class="w-4 h-4 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" /></svg>',
      'email_opened': '<svg class="w-4 h-4 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>',
      'link_clicked': '<svg class="w-4 h-4 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 15l-2 5L9 9l11 4-5 2zm0 0l5 5M7.188 2.239l.777 2.897M5.136 7.965l-2.898-.777M13.95 4.05l-2.122 2.122m-5.657 5.656l-2.12 2.122" /></svg>',
      'email_bounced': '<svg class="w-4 h-4 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>',
      'unsubscribed': '<svg class="w-4 h-4 text-yellow-600" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7a4 4 0 11-8 0 4 4 0 018 0zM9 14a3 3 0 01-3-3" /></svg>'
    }
    return icons[type] || '<svg class="w-4 h-4 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>'
  }

  // Start auto-refresh
  startAutoRefresh() {
    if (this.autoRefreshEnabledValue) {
      this.refreshTimer = setInterval(() => {
        this.refreshMetrics()
      }, this.refreshIntervalValue)
      
      if (this.hasUpdateIndicatorTarget) {
        this.updateIndicatorTarget.style.display = 'block'
      }
    }
  }

  // Stop auto-refresh
  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
    }
    
    if (this.hasUpdateIndicatorTarget) {
      this.updateIndicatorTarget.style.display = 'none'
    }
  }

  // Toggle auto-refresh
  toggleAutoRefresh() {
    this.autoRefreshEnabledValue = this.autoRefreshTarget.checked
    
    if (this.autoRefreshEnabledValue) {
      this.startAutoRefresh()
    } else {
      this.stopAutoRefresh()
    }
  }

  // Update time range
  updateTimeRange() {
    const timeRange = this.timeRangeTarget.value
    // This would typically update the charts with new data
    console.log('Time range updated to:', timeRange)
  }

  // Load more activity
  loadMoreActivity() {
    this.activityOffset += 20 // Assuming 20 items per page
    this.loadActivityFeed(this.activityOffset)
  }

  // Export data
  async exportData() {
    try {
      const response = await fetch(`/campaigns/${this.campaignIdValue}/export`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      if (response.ok) {
        const blob = await response.blob()
        const url = window.URL.createObjectURL(blob)
        const a = document.createElement('a')
        a.href = url
        a.download = `campaign-${this.campaignIdValue}-data.csv`
        document.body.appendChild(a)
        a.click()
        window.URL.revokeObjectURL(url)
        document.body.removeChild(a)
      }
    } catch (error) {
      console.error('Failed to export data:', error)
      this.showError('Failed to export data')
    }
  }

  // Campaign actions
  async pauseCampaign() {
    await this.updateCampaignStatus('pause')
  }

  async resumeCampaign() {
    await this.updateCampaignStatus('resume')
  }

  async archiveCampaign() {
    if (confirm('Are you sure you want to archive this campaign?')) {
      await this.updateCampaignStatus('archive')
    }
  }

  // Update campaign status
  async updateCampaignStatus(action) {
    try {
      const response = await fetch(`/campaigns/${this.campaignIdValue}/${action}`, {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      if (response.ok) {
        await this.refreshMetrics()
        this.showSuccess(`Campaign ${action}d successfully`)
      } else {
        this.showError(`Failed to ${action} campaign`)
      }
    } catch (error) {
      console.error(`Failed to ${action} campaign:`, error)
      this.showError(`Failed to ${action} campaign`)
    }
  }

  // Update last updated timestamp
  updateLastUpdated() {
    if (this.hasLastUpdatedTarget) {
      this.lastUpdatedTarget.textContent = 'Just now'
    }
  }

  // Utility methods
  formatNumber(num) {
    return new Intl.NumberFormat().format(num || 0)
  }

  formatPercentage(num) {
    return (num || 0).toFixed(1) + '%'
  }

  formatDecimal(num) {
    return (num || 0).toFixed(2)
  }

  formatTimestamp(timestamp) {
    return new Date(timestamp).toLocaleString()
  }

  showSuccess(message) {
    // This would typically show a toast notification
    console.log('Success:', message)
  }

  showError(message) {
    // This would typically show a toast notification
    console.error('Error:', message)
  }
}
