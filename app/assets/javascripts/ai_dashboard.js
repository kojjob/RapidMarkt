// AI Dashboard JavaScript functionality
class AIDashboard {
  constructor() {
    this.currentGenerationId = null;
    this.websocket = null;
    this.retryCount = 0;
    this.maxRetries = 3;
    this.init();
  }

  init() {
    this.setupEventListeners();
    this.initializeWebSocket();
    this.loadDashboardData();
    this.startPeriodicUpdates();
  }

  setupEventListeners() {
    // Content generation form
    const form = document.getElementById('content-generation-form');
    if (form) {
      form.addEventListener('submit', (e) => this.handleContentGeneration(e));
    }

    // Content type buttons
    document.querySelectorAll('.content-type-btn').forEach(btn => {
      btn.addEventListener('click', (e) => this.selectContentType(e));
    });

    // Content actions
    document.addEventListener('click', (e) => {
      if (e.target.id === 'approve-content') this.approveContent();
      if (e.target.id === 'reject-content') this.rejectContent();
      if (e.target.id === 'regenerate-content') this.regenerateContent();
      if (e.target.id === 'refresh-dashboard') this.refreshDashboard();
    });

    // Provider health check buttons
    document.addEventListener('click', (e) => {
      if (e.target.classList.contains('health-check-btn')) {
        this.checkProviderHealth(e.target.dataset.providerId);
      }
    });

    // Bulk generation
    const bulkBtn = document.getElementById('bulk-generate-btn');
    if (bulkBtn) {
      bulkBtn.addEventListener('click', () => this.showBulkGenerationModal());
    }
  }

  initializeWebSocket() {
    if (typeof ActionCable !== 'undefined') {
      this.websocket = ActionCable.createConsumer();
      this.websocket.subscriptions.create('AIDashboardChannel', {
        received: (data) => this.handleWebSocketMessage(data),
        connected: () => console.log('AI Dashboard WebSocket connected'),
        disconnected: () => console.log('AI Dashboard WebSocket disconnected')
      });
    }
  }

  handleWebSocketMessage(data) {
    switch (data.type) {
      case 'provider_status_update':
        this.updateProviderStatus(data.provider);
        break;
      case 'generation_complete':
        this.handleGenerationComplete(data.generation);
        break;
      case 'insight_generated':
        this.addNewInsight(data.insight);
        break;
      case 'metrics_update':
        this.updateMetrics(data.metrics);
        break;
    }
  }

  async loadDashboardData() {
    try {
      await Promise.all([
        this.loadAIInsights(),
        this.loadProviders(),
        this.loadPerformanceMetrics(),
        this.loadRecentGenerations()
      ]);
    } catch (error) {
      console.error('Error loading dashboard data:', error);
      this.showNotification('Error loading dashboard data', 'error');
    }
  }

  async loadAIInsights() {
    try {
      const response = await fetch('/ai_dashboard/insights');
      const data = await response.json();
      this.renderInsights(data.insights || []);
    } catch (error) {
      console.error('Error loading insights:', error);
      this.renderInsightsError();
    }
  }

  renderInsights(insights) {
    const container = document.getElementById('ai-insights');
    if (!container) return;

    if (insights.length === 0) {
      container.innerHTML = `
        <div class="text-center py-8">
          <svg class="w-12 h-12 mx-auto text-slate-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"></path>
          </svg>
          <p class="text-slate-600">No insights available yet.</p>
          <p class="text-slate-500 text-sm mt-1">Generate some content to get AI-powered recommendations!</p>
        </div>
      `;
      return;
    }

    container.innerHTML = insights.map(insight => this.renderInsightCard(insight)).join('');
  }

  renderInsightCard(insight) {
    const priorityColor = {
      high: 'red',
      medium: 'yellow',
      low: 'blue'
    }[insight.priority] || 'blue';

    return `
      <div class="mb-4 p-4 bg-gradient-to-r from-${priorityColor}-50 to-purple-50 rounded-lg border border-${priorityColor}-200 insight-card" data-insight-id="${insight.id}">
        <div class="flex items-start justify-between">
          <div class="flex-1">
            <div class="flex items-center space-x-2 mb-2">
              <h4 class="font-semibold text-slate-900">${insight.title}</h4>
              <span class="text-xs px-2 py-1 rounded-full bg-${priorityColor}-100 text-${priorityColor}-800">${insight.priority}</span>
            </div>
            <p class="text-slate-700 mb-3">${insight.content}</p>
            <div class="flex items-center space-x-4">
              <span class="text-xs text-blue-600 bg-blue-100 px-2 py-1 rounded-full">Confidence: ${insight.confidence_score}%</span>
              <span class="text-xs text-purple-600 bg-purple-100 px-2 py-1 rounded-full">${insight.insight_type}</span>
              <span class="text-xs text-slate-500">${this.formatDate(insight.created_at)}</span>
            </div>
          </div>
          <div class="ml-4 flex space-x-2">
            <button class="implement-insight-btn text-blue-600 hover:text-blue-800 text-sm font-medium px-3 py-1 rounded border border-blue-200 hover:bg-blue-50 transition-colors" data-insight-id="${insight.id}">
              Implement
            </button>
            <button class="dismiss-insight-btn text-slate-600 hover:text-slate-800 text-sm px-2 py-1 rounded hover:bg-slate-100 transition-colors" data-insight-id="${insight.id}">
              ×
            </button>
          </div>
        </div>
      </div>
    `;
  }

  renderInsightsError() {
    const container = document.getElementById('ai-insights');
    if (container) {
      container.innerHTML = `
        <div class="text-center py-8">
          <svg class="w-12 h-12 mx-auto text-red-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
          </svg>
          <p class="text-red-600">Error loading insights</p>
          <button class="mt-2 text-blue-600 hover:text-blue-800 text-sm font-medium" onclick="aiDashboard.loadAIInsights()">Try Again</button>
        </div>
      `;
    }
  }

  async loadProviders() {
    try {
      const response = await fetch('/ai_dashboard/providers');
      const data = await response.json();
      this.renderProviders(data.providers || []);
      this.updateProviderSelect(data.providers || []);
    } catch (error) {
      console.error('Error loading providers:', error);
    }
  }

  renderProviders(providers) {
    const container = document.getElementById('providers-list');
    if (!container) return;

    if (providers.length === 0) {
      container.innerHTML = '<p class="text-slate-600 text-sm text-center py-4">No providers configured</p>';
      return;
    }

    container.innerHTML = providers.map(provider => `
      <div class="flex items-center justify-between py-3 border-b border-slate-100 last:border-b-0 provider-item" data-provider-id="${provider.id}">
        <div class="flex items-center space-x-3">
          <div class="relative">
            <div class="w-3 h-3 rounded-full ${provider.health_status === 'healthy' ? 'bg-green-500' : provider.health_status === 'degraded' ? 'bg-yellow-500' : 'bg-red-500'}"></div>
            ${provider.health_status === 'healthy' ? '<div class="absolute inset-0 w-3 h-3 rounded-full bg-green-500 animate-ping opacity-75"></div>' : ''}
          </div>
          <div>
            <span class="font-medium text-slate-900">${provider.name}</span>
            <div class="text-xs text-slate-500">${provider.provider_type} • ${provider.health_status}</div>
          </div>
        </div>
        <div class="flex items-center space-x-2">
          <span class="text-xs px-2 py-1 rounded-full ${provider.priority === 'high' ? 'bg-red-100 text-red-800' : provider.priority === 'medium' ? 'bg-yellow-100 text-yellow-800' : 'bg-blue-100 text-blue-800'}">P${provider.priority}</span>
          <button class="health-check-btn text-xs text-blue-600 hover:text-blue-800 font-medium" data-provider-id="${provider.id}">
            Check
          </button>
        </div>
      </div>
    `).join('');
  }

  updateProviderSelect(providers) {
    const select = document.getElementById('ai-provider-select');
    if (!select) return;

    const healthyProviders = providers.filter(p => p.health_status === 'healthy');
    const options = healthyProviders.map(provider => 
      `<option value="${provider.id}">${provider.name} (${provider.provider_type})</option>`
    ).join('');
    
    select.innerHTML = '<option value="auto">Auto-select Best Provider</option>' + options;
  }

  async loadPerformanceMetrics() {
    try {
      const response = await fetch('/ai_dashboard/analytics');
      const data = await response.json();
      this.renderPerformanceMetrics(data);
    } catch (error) {
      console.error('Error loading performance metrics:', error);
    }
  }

  renderPerformanceMetrics(data) {
    const container = document.getElementById('performance-metrics');
    if (!container) return;

    container.innerHTML = `
      <div class="space-y-4">
        <div class="grid grid-cols-2 gap-4">
          <div class="text-center p-3 bg-blue-50 rounded-lg">
            <div class="text-2xl font-bold text-blue-600">${data.total_generations || 0}</div>
            <div class="text-xs text-blue-800">Total Generations</div>
          </div>
          <div class="text-center p-3 bg-green-50 rounded-lg">
            <div class="text-2xl font-bold text-green-600">${data.success_rate || 0}%</div>
            <div class="text-xs text-green-800">Success Rate</div>
          </div>
        </div>
        <div class="space-y-2">
          <div class="flex justify-between items-center">
            <span class="text-sm text-slate-600">Avg Response Time</span>
            <span class="font-semibold text-slate-900">${data.avg_response_time || 0}ms</span>
          </div>
          <div class="flex justify-between items-center">
            <span class="text-sm text-slate-600">Total Cost</span>
            <span class="font-semibold text-slate-900">$${(data.total_cost || 0).toFixed(2)}</span>
          </div>
          <div class="flex justify-between items-center">
            <span class="text-sm text-slate-600">Cost per Generation</span>
            <span class="font-semibold text-slate-900">$${(data.cost_per_generation || 0).toFixed(4)}</span>
          </div>
        </div>
      </div>
    `;
  }

  async loadRecentGenerations() {
    try {
      const response = await fetch('/ai_dashboard/content_generations');
      const data = await response.json();
      this.renderRecentGenerations(data.generations || []);
    } catch (error) {
      console.error('Error loading recent generations:', error);
    }
  }

  renderRecentGenerations(generations) {
    const container = document.getElementById('recent-generations');
    if (!container) return;

    if (generations.length === 0) {
      container.innerHTML = '<p class="text-slate-600 text-sm text-center py-4">No generations yet</p>';
      return;
    }

    container.innerHTML = generations.slice(0, 5).map(gen => `
      <div class="py-3 border-b border-slate-100 last:border-b-0 generation-item" data-generation-id="${gen.id}">
        <div class="flex items-center justify-between mb-2">
          <span class="text-sm font-medium text-slate-900">${gen.content_type.replace('_', ' ').toUpperCase()}</span>
          <span class="text-xs px-2 py-1 rounded-full ${
            gen.status === 'approved' ? 'bg-green-100 text-green-800' :
            gen.status === 'rejected' ? 'bg-red-100 text-red-800' :
            gen.status === 'published' ? 'bg-blue-100 text-blue-800' :
            'bg-yellow-100 text-yellow-800'
          }">${gen.status}</span>
        </div>
        <p class="text-xs text-slate-600 mb-2 line-clamp-2">${gen.generated_content}</p>
        <div class="flex items-center justify-between text-xs text-slate-500">
          <span>${gen.ai_provider_name}</span>
          <span>${this.formatDate(gen.created_at)}</span>
        </div>
      </div>
    `).join('');
  }

  selectContentType(e) {
    e.preventDefault();
    
    // Remove active class from all buttons
    document.querySelectorAll('.content-type-btn').forEach(btn => {
      const div = btn.querySelector('div');
      const span = btn.querySelector('span');
      const svg = btn.querySelector('svg');
      
      div.className = 'p-4 border-2 border-slate-200 rounded-lg text-center hover:border-slate-300 transition-colors';
      span.className = 'text-sm font-medium text-slate-700';
      svg.className = 'w-6 h-6 mx-auto mb-2 text-slate-600';
    });
    
    // Add active class to clicked button
    const div = e.currentTarget.querySelector('div');
    const span = e.currentTarget.querySelector('span');
    const svg = e.currentTarget.querySelector('svg');
    
    div.className = 'p-4 border-2 border-blue-200 bg-blue-50 rounded-lg text-center hover:border-blue-300 transition-colors';
    span.className = 'text-sm font-medium text-blue-900';
    svg.className = 'w-6 h-6 mx-auto mb-2 text-blue-600';
    
    // Update placeholder text based on content type
    const contentType = e.currentTarget.dataset.type;
    const promptTextarea = document.getElementById('generation-prompt');
    if (promptTextarea) {
      const placeholders = {
        email_subject: 'Describe the email subject you want to generate...',
        email_body: 'Describe the email content you want to generate...',
        social_post: 'Describe the social media post you want to create...',
        ad_copy: 'Describe the advertisement copy you want to generate...'
      };
      promptTextarea.placeholder = placeholders[contentType] || 'Describe what you want to generate...';
    }
  }

  async handleContentGeneration(e) {
    e.preventDefault();
    
    const form = e.target;
    const submitBtn = form.querySelector('button[type="submit"]');
    const originalText = submitBtn.innerHTML;
    
    // Validate form
    const prompt = document.getElementById('generation-prompt').value.trim();
    if (!prompt) {
      this.showNotification('Please enter a prompt', 'error');
      return;
    }
    
    // Show loading state
    this.setLoadingState(submitBtn, true);
    
    const formData = {
      content_type: document.querySelector('.content-type-btn.active')?.dataset.type || 'email_subject',
      prompt: prompt,
      ai_provider_id: document.getElementById('ai-provider-select').value,
      tone: document.getElementById('tone-select').value,
      options: this.getGenerationOptions()
    };
    
    try {
      const response = await fetch('/ai_dashboard/generate_content', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify(formData)
      });
      
      const data = await response.json();
      
      if (data.success) {
        this.displayGeneratedContent(data);
        this.showNotification('Content generated successfully!', 'success');
        this.loadRecentGenerations(); // Refresh recent generations
      } else {
        this.showNotification('Error: ' + data.error, 'error');
      }
    } catch (error) {
      console.error('Generation error:', error);
      this.showNotification('Network error. Please try again.', 'error');
    } finally {
      this.setLoadingState(submitBtn, false, originalText);
    }
  }

  getGenerationOptions() {
    return {
      temperature: 0.7,
      max_tokens: 1000,
      include_metadata: true
    };
  }

  displayGeneratedContent(data) {
    const container = document.getElementById('generated-content');
    const output = document.getElementById('content-output');
    
    if (!container || !output) return;
    
    this.currentGenerationId = data.generation_id;
    
    output.innerHTML = `
      <div class="space-y-4">
        <div class="bg-white p-4 rounded-lg border border-slate-200">
          <div class="prose max-w-none">
            <p class="text-slate-900 whitespace-pre-wrap">${data.content}</p>
          </div>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
          <div class="flex items-center justify-between p-3 bg-slate-50 rounded-lg">
            <span class="text-slate-600">Provider:</span>
            <span class="font-medium text-slate-900">${data.provider_name}</span>
          </div>
          <div class="flex items-center justify-between p-3 bg-slate-50 rounded-lg">
            <span class="text-slate-600">Quality Score:</span>
            <span class="font-medium ${data.quality_score >= 80 ? 'text-green-600' : data.quality_score >= 60 ? 'text-yellow-600' : 'text-red-600'}">${data.quality_score}/100</span>
          </div>
          <div class="flex items-center justify-between p-3 bg-slate-50 rounded-lg">
            <span class="text-slate-600">Response Time:</span>
            <span class="font-medium text-slate-900">${data.response_time}ms</span>
          </div>
        </div>
      </div>
    `;
    
    container.classList.remove('hidden');
    container.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }

  async approveContent() {
    if (!this.currentGenerationId) return;
    
    try {
      const response = await fetch(`/ai_dashboard/content_generations/${this.currentGenerationId}/approve`, {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      });
      
      const data = await response.json();
      
      if (data.success) {
        this.showNotification('Content approved!', 'success');
        this.hideGeneratedContent();
        this.loadRecentGenerations();
      } else {
        this.showNotification('Error approving content', 'error');
      }
    } catch (error) {
      console.error('Approval error:', error);
      this.showNotification('Network error', 'error');
    }
  }

  async rejectContent() {
    if (!this.currentGenerationId) return;
    
    const reason = prompt('Reason for rejection (optional):');
    
    try {
      const response = await fetch(`/ai_dashboard/content_generations/${this.currentGenerationId}/reject`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ reason: reason })
      });
      
      const data = await response.json();
      
      if (data.success) {
        this.showNotification('Content rejected', 'info');
        this.hideGeneratedContent();
        this.loadRecentGenerations();
      } else {
        this.showNotification('Error rejecting content', 'error');
      }
    } catch (error) {
      console.error('Rejection error:', error);
      this.showNotification('Network error', 'error');
    }
  }

  regenerateContent() {
    // Clear current content and regenerate
    this.hideGeneratedContent();
    document.getElementById('content-generation-form').dispatchEvent(new Event('submit'));
  }

  hideGeneratedContent() {
    const container = document.getElementById('generated-content');
    if (container) {
      container.classList.add('hidden');
    }
    this.currentGenerationId = null;
  }

  async checkProviderHealth(providerId) {
    try {
      const response = await fetch(`/ai_dashboard/providers/${providerId}/health_check`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      });
      
      const data = await response.json();
      
      if (data.success) {
        this.showNotification(`Provider health: ${data.status}`, 'info');
        this.loadProviders(); // Refresh provider list
      } else {
        this.showNotification('Health check failed', 'error');
      }
    } catch (error) {
      console.error('Health check error:', error);
      this.showNotification('Network error', 'error');
    }
  }

  refreshDashboard() {
    const refreshBtn = document.getElementById('refresh-dashboard');
    if (refreshBtn) {
      refreshBtn.classList.add('animate-spin');
    }
    
    this.loadDashboardData().finally(() => {
      if (refreshBtn) {
        setTimeout(() => refreshBtn.classList.remove('animate-spin'), 500);
      }
    });
  }

  startPeriodicUpdates() {
    // Update metrics every 30 seconds
    setInterval(() => {
      this.loadPerformanceMetrics();
    }, 30000);
    
    // Update provider status every 60 seconds
    setInterval(() => {
      this.loadProviders();
    }, 60000);
  }

  setLoadingState(button, loading, originalText = null) {
    if (loading) {
      button.innerHTML = `
        <span class="flex items-center justify-center">
          <div class="animate-spin rounded-full h-5 w-5 border-b-2 border-white mr-2"></div>
          Generating...
        </span>
      `;
      button.disabled = true;
    } else {
      button.innerHTML = originalText || button.innerHTML;
      button.disabled = false;
    }
  }

  showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `fixed top-4 right-4 z-50 p-4 rounded-lg shadow-lg transition-all duration-300 transform translate-x-full ${
      type === 'success' ? 'bg-green-500 text-white' :
      type === 'error' ? 'bg-red-500 text-white' :
      type === 'warning' ? 'bg-yellow-500 text-white' :
      'bg-blue-500 text-white'
    }`;
    
    notification.innerHTML = `
      <div class="flex items-center space-x-2">
        <span>${message}</span>
        <button class="ml-2 text-white hover:text-gray-200" onclick="this.parentElement.parentElement.remove()">
          ×
        </button>
      </div>
    `;
    
    document.body.appendChild(notification);
    
    // Animate in
    setTimeout(() => {
      notification.classList.remove('translate-x-full');
    }, 100);
    
    // Auto remove after 5 seconds
    setTimeout(() => {
      notification.classList.add('translate-x-full');
      setTimeout(() => notification.remove(), 300);
    }, 5000);
  }

  formatDate(dateString) {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);
    
    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;
    
    return date.toLocaleDateString();
  }

  // Utility methods for future enhancements
  updateProviderStatus(provider) {
    const providerItem = document.querySelector(`[data-provider-id="${provider.id}"]`);
    if (providerItem) {
      // Update provider status in real-time
      this.loadProviders();
    }
  }

  handleGenerationComplete(generation) {
    if (generation.id === this.currentGenerationId) {
      // Update the current generation display
      this.loadRecentGenerations();
    }
  }

  addNewInsight(insight) {
    // Add new insight to the top of the list
    this.loadAIInsights();
  }

  updateMetrics(metrics) {
    // Update real-time metrics
    this.renderPerformanceMetrics(metrics);
  }
}

// Initialize AI Dashboard when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
  if (document.getElementById('ai-insights')) {
    window.aiDashboard = new AIDashboard();
  }
});