// AI Progress Tracking and Real-time Updates
class AiProgressTracker {
  constructor() {
    this.cable = null;
    this.subscriptions = new Map();
    this.progressBars = new Map();
    this.init();
  }

  init() {
    // Initialize ActionCable connection
    if (typeof ActionCable !== 'undefined') {
      this.cable = ActionCable.createConsumer();
      this.subscribeToAiProgress();
    }
  }

  subscribeToAiProgress() {
    if (!this.cable) return;

    const subscription = this.cable.subscriptions.create('AiProgressChannel', {
      connected: () => {
        console.log('Connected to AI Progress Channel');
      },

      disconnected: () => {
        console.log('Disconnected from AI Progress Channel');
      },

      received: (data) => {
        this.handleProgressUpdate(data);
      }
    });

    this.subscriptions.set('ai_progress', subscription);
  }

  subscribeToGeneration(generationId) {
    if (!this.cable || this.subscriptions.has(`generation_${generationId}`)) return;

    const subscription = this.cable.subscriptions.create('AiProgressChannel', {
      connected: () => {
        this.perform('subscribe_to_generation', { generation_id: generationId });
      },

      received: (data) => {
        this.handleGenerationUpdate(generationId, data);
      }
    });

    this.subscriptions.set(`generation_${generationId}`, subscription);
  }

  subscribeToBulkOperation(jobId) {
    if (!this.cable || this.subscriptions.has(`bulk_${jobId}`)) return;

    const subscription = this.cable.subscriptions.create('AiProgressChannel', {
      connected: () => {
        this.perform('subscribe_to_bulk_operation', { job_id: jobId });
      },

      received: (data) => {
        this.handleBulkUpdate(jobId, data);
      }
    });

    this.subscriptions.set(`bulk_${jobId}`, subscription);
  }

  handleProgressUpdate(data) {
    const { type, generation_id, job_id, status, progress, message, content } = data;

    switch (type) {
      case 'content_generation':
        this.updateGenerationProgress(generation_id, status, progress, message, content);
        break;
      case 'bulk_operation':
        this.updateBulkProgress(job_id, status, progress, message);
        break;
      case 'insight_generation':
        this.updateInsightProgress(data);
        break;
      default:
        console.log('Unknown progress update type:', type);
    }
  }

  handleGenerationUpdate(generationId, data) {
    const { status, progress, message, content } = data;
    this.updateGenerationProgress(generationId, status, progress, message, content);
  }

  handleBulkUpdate(jobId, data) {
    const { status, progress, message, completed_count, total_count } = data;
    this.updateBulkProgress(jobId, status, progress, message, completed_count, total_count);
  }

  updateGenerationProgress(generationId, status, progress, message, content) {
    // Update progress bar
    const progressBar = document.querySelector(`[data-generation-id="${generationId}"] .progress-bar`);
    if (progressBar) {
      progressBar.style.width = `${progress}%`;
      progressBar.setAttribute('aria-valuenow', progress);
    }

    // Update status text
    const statusElement = document.querySelector(`[data-generation-id="${generationId}"] .status-text`);
    if (statusElement) {
      statusElement.textContent = this.getStatusText(status, message);
      statusElement.className = `status-text ${this.getStatusClass(status)}`;
    }

    // Update content if generation is complete
    if (status === 'completed' && content) {
      const contentElement = document.querySelector(`[data-generation-id="${generationId}"] .generated-content`);
      if (contentElement) {
        contentElement.innerHTML = this.formatContent(content);
        contentElement.classList.remove('hidden');
      }

      // Show action buttons
      const actionsElement = document.querySelector(`[data-generation-id="${generationId}"] .generation-actions`);
      if (actionsElement) {
        actionsElement.classList.remove('hidden');
      }
    }

    // Handle errors
    if (status === 'failed') {
      this.showError(generationId, message);
    }

    // Show notification
    if (status === 'completed' || status === 'failed') {
      this.showNotification(status, message);
    }
  }

  updateBulkProgress(jobId, status, progress, message, completedCount, totalCount) {
    // Update overall progress
    const progressBar = document.querySelector(`[data-job-id="${jobId}"] .bulk-progress-bar`);
    if (progressBar) {
      progressBar.style.width = `${progress}%`;
      progressBar.setAttribute('aria-valuenow', progress);
    }

    // Update status and counts
    const statusElement = document.querySelector(`[data-job-id="${jobId}"] .bulk-status`);
    if (statusElement) {
      const statusText = completedCount && totalCount 
        ? `${completedCount}/${totalCount} completed`
        : this.getStatusText(status, message);
      statusElement.textContent = statusText;
      statusElement.className = `bulk-status ${this.getStatusClass(status)}`;
    }

    // Show notification when complete
    if (status === 'completed' || status === 'failed') {
      this.showNotification(status, message || `Bulk operation ${status}`);
    }
  }

  updateInsightProgress(data) {
    const { insight_type, status, message } = data;
    
    // Update insights section
    const insightsContainer = document.querySelector('.ai-insights-container');
    if (insightsContainer && status === 'completed') {
      // Refresh insights or add new insight
      this.refreshInsights();
    }

    this.showNotification(status, `${insight_type} insight ${status}`);
  }

  getStatusText(status, message) {
    const statusTexts = {
      pending: 'Queued for processing...',
      processing: 'Generating content...',
      completed: 'Generation complete!',
      failed: message || 'Generation failed',
      draft: 'Ready for review',
      approved: 'Approved',
      rejected: 'Rejected'
    };
    return statusTexts[status] || status;
  }

  getStatusClass(status) {
    const statusClasses = {
      pending: 'text-yellow-600',
      processing: 'text-blue-600',
      completed: 'text-green-600',
      failed: 'text-red-600',
      draft: 'text-purple-600',
      approved: 'text-green-600',
      rejected: 'text-red-600'
    };
    return statusClasses[status] || 'text-gray-600';
  }

  formatContent(content) {
    // Basic content formatting - can be enhanced based on content type
    return content.replace(/\n/g, '<br>');
  }

  showError(generationId, message) {
    const errorElement = document.querySelector(`[data-generation-id="${generationId}"] .error-message`);
    if (errorElement) {
      errorElement.textContent = message;
      errorElement.classList.remove('hidden');
    }
  }

  showNotification(status, message) {
    // Create and show toast notification
    const notification = document.createElement('div');
    notification.className = `fixed top-4 right-4 p-4 rounded-lg shadow-lg z-50 ${
      status === 'completed' ? 'bg-green-500' : 
      status === 'failed' ? 'bg-red-500' : 'bg-blue-500'
    } text-white`;
    notification.textContent = message;

    document.body.appendChild(notification);

    // Auto-remove after 5 seconds
    setTimeout(() => {
      notification.remove();
    }, 5000);
  }

  refreshInsights() {
    // Reload insights section
    fetch('/ai_dashboard/insights')
      .then(response => response.json())
      .then(data => {
        // Update insights UI
        console.log('Insights updated:', data);
      })
      .catch(error => {
        console.error('Failed to refresh insights:', error);
      });
  }

  // Utility method to start tracking a generation
  trackGeneration(generationId) {
    this.subscribeToGeneration(generationId);
    
    // Poll for status updates as fallback
    const pollInterval = setInterval(() => {
      fetch(`/ai_dashboard/generation_status/${generationId}`)
        .then(response => response.json())
        .then(data => {
          if (data.success) {
            const generation = data.generation;
            this.updateGenerationProgress(
              generationId,
              generation.status,
              generation.progress_percentage,
              null,
              generation.generated_content
            );

            // Stop polling when complete
            if (['completed', 'failed', 'approved', 'rejected'].includes(generation.status)) {
              clearInterval(pollInterval);
            }
          }
        })
        .catch(error => {
          console.error('Failed to poll generation status:', error);
        });
    }, 2000); // Poll every 2 seconds

    // Clear interval after 5 minutes to prevent infinite polling
    setTimeout(() => {
      clearInterval(pollInterval);
    }, 300000);
  }

  // Utility method to start tracking a bulk operation
  trackBulkOperation(jobId) {
    this.subscribeToBulkOperation(jobId);
  }

  // Clean up subscriptions
  cleanup() {
    this.subscriptions.forEach((subscription) => {
      subscription.unsubscribe();
    });
    this.subscriptions.clear();
  }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  window.aiProgressTracker = new AiProgressTracker();
});

// Clean up on page unload
window.addEventListener('beforeunload', () => {
  if (window.aiProgressTracker) {
    window.aiProgressTracker.cleanup();
  }
});