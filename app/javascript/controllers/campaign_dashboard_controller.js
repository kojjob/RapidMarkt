import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from 'chart.js'

// Register Chart.js components
Chart.register(...registerables)

export default class extends Controller {
  static targets = [
    "totalCampaigns", 
    "activeCampaigns", 
    "totalRecipients", 
    "averageOpenRate",
    "performanceChart",
    "statusChart",
    "activityFeed"
  ]
  
  static values = { 
    refreshInterval: Number 
  }

  connect() {
    console.log("Campaign Dashboard controller connected")
    this.initializeCharts()
    this.startAutoRefresh()
  }

  disconnect() {
    this.stopAutoRefresh()
    this.destroyCharts()
  }

  initializeCharts() {
    this.initializePerformanceChart()
    this.initializeStatusChart()
  }

  initializePerformanceChart() {
    if (!this.hasPerformanceChartTarget) return

    const ctx = this.performanceChartTarget.getContext('2d')
    
    // Sample data - this will be replaced with real data from the backend
    const performanceData = {
      labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
      datasets: [
        {
          label: 'Open Rate (%)',
          data: [25, 30, 28, 35, 32, 38],
          borderColor: 'rgb(59, 130, 246)',
          backgroundColor: 'rgba(59, 130, 246, 0.1)',
          tension: 0.4,
          fill: true
        },
        {
          label: 'Click Rate (%)',
          data: [12, 15, 14, 18, 16, 20],
          borderColor: 'rgb(34, 197, 94)',
          backgroundColor: 'rgba(34, 197, 94, 0.1)',
          tension: 0.4,
          fill: true
        }
      ]
    }

    this.performanceChart = new Chart(ctx, {
      type: 'line',
      data: performanceData,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom',
            labels: {
              usePointStyle: true,
              padding: 20
            }
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            max: 50,
            ticks: {
              callback: function(value) {
                return value + '%'
              }
            }
          }
        },
        elements: {
          point: {
            radius: 4,
            hoverRadius: 6
          }
        }
      }
    })
  }

  initializeStatusChart() {
    if (!this.hasStatusChartTarget) return

    const ctx = this.statusChartTarget.getContext('2d')
    
    // Sample data - this will be replaced with real data from the backend
    const statusData = {
      labels: ['Draft', 'Scheduled', 'Sent', 'Sending'],
      datasets: [{
        data: [12, 5, 25, 2],
        backgroundColor: [
          'rgba(107, 114, 128, 0.8)',
          'rgba(59, 130, 246, 0.8)',
          'rgba(34, 197, 94, 0.8)',
          'rgba(251, 191, 36, 0.8)'
        ],
        borderColor: [
          'rgb(107, 114, 128)',
          'rgb(59, 130, 246)',
          'rgb(34, 197, 94)',
          'rgb(251, 191, 36)'
        ],
        borderWidth: 2
      }]
    }

    this.statusChart = new Chart(ctx, {
      type: 'doughnut',
      data: statusData,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom',
            labels: {
              usePointStyle: true,
              padding: 15
            }
          }
        },
        cutout: '60%'
      }
    })
  }

  destroyCharts() {
    if (this.performanceChart) {
      this.performanceChart.destroy()
      this.performanceChart = null
    }
    if (this.statusChart) {
      this.statusChart.destroy()
      this.statusChart = null
    }
  }

  startAutoRefresh() {
    if (this.refreshIntervalValue > 0) {
      this.refreshTimer = setInterval(() => {
        this.refreshData()
      }, this.refreshIntervalValue)
    }
  }

  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
    }
  }

  refreshData() {
    console.log("Refreshing dashboard data...")

    fetch(window.location.pathname + '.json', {
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.json())
    .then(data => {
      this.updateDashboardData(data)
    })
    .catch(error => {
      console.error('Error refreshing dashboard data:', error)
    })
  }

  // Handle updates from ActionCable
  handleCableUpdate(event) {
    console.log("Received cable update:", event.detail)
    this.updateDashboardData(event.detail)
  }

  updateDashboardData(data) {
    // Update stat cards
    if (this.hasTotalCampaignsTarget) {
      this.totalCampaignsTarget.textContent = data.total_campaigns
    }
    if (this.hasActiveCampaignsTarget) {
      this.activeCampaignsTarget.textContent = data.active_campaigns
    }
    if (this.hasTotalRecipientsTarget) {
      this.totalRecipientsTarget.textContent = data.total_recipients
    }
    if (this.hasAverageOpenRateTarget) {
      this.averageOpenRateTarget.textContent = data.average_open_rate.toFixed(1) + '%'
    }

    // Update charts
    this.updatePerformanceChart(data.performance_data)
    this.updateStatusChart(data.status_distribution)
    
    // Update activity feed
    this.updateActivityFeed(data.recent_activities)
  }

  updatePerformanceChart(performanceData) {
    if (!this.performanceChart || !performanceData) return

    const labels = performanceData.map(d => new Date(d.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }))
    const openRates = performanceData.map(d => d.avg_open_rate)
    const clickRates = performanceData.map(d => d.avg_click_rate)

    this.performanceChart.data.labels = labels
    this.performanceChart.data.datasets[0].data = openRates
    this.performanceChart.data.datasets[1].data = clickRates
    this.performanceChart.update('none')
  }

  updateStatusChart(statusDistribution) {
    if (!this.statusChart || !statusDistribution) return

    const labels = Object.keys(statusDistribution).map(status => status.charAt(0).toUpperCase() + status.slice(1))
    const data = Object.values(statusDistribution)

    this.statusChart.data.labels = labels
    this.statusChart.data.datasets[0].data = data
    this.statusChart.update('none')
  }

  updateActivityFeed(activities) {
    if (!this.hasActivityFeedTarget || !activities) return

    const activityHtml = activities.map(activity => `
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
              ${activity.time_ago} ago
            </p>
          </div>
        </div>
      </div>
    `).join('')

    this.activityFeedTarget.innerHTML = `<div class="divide-y divide-gray-100">${activityHtml}</div>`
  }
}
