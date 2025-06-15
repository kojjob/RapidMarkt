// Enhanced Toast System for RapidMarkt
// Provides easy-to-use JavaScript API for showing toasts

class Toast {
  constructor() {
    this.defaultOptions = {
      position: 'top-right',
      duration: 5000,
      autoDismiss: true,
      showProgress: true
    };
  }

  // Show a success toast
  success(message, options = {}) {
    return this.show('success', message, {
      title: 'Success',
      ...options
    });
  }

  // Show an error toast
  error(message, options = {}) {
    return this.show('error', message, {
      title: 'Error',
      duration: 7000, // Longer duration for errors
      ...options
    });
  }

  // Show a warning toast
  warning(message, options = {}) {
    return this.show('warning', message, {
      title: 'Warning',
      duration: 6000,
      ...options
    });
  }

  // Show an info toast
  info(message, options = {}) {
    return this.show('info', message, {
      title: 'Info',
      ...options
    });
  }

  // Show a loading toast
  loading(message, options = {}) {
    return this.show('loading', message, {
      title: 'Loading',
      autoDismiss: false,
      showProgress: false,
      ...options
    });
  }

  // Generic show method
  show(type, message, options = {}) {
    const finalOptions = { ...this.defaultOptions, ...options };
    
    if (window.ToastManager) {
      return window.ToastManager.show(type, message, finalOptions);
    } else {
      console.warn('ToastManager not available, falling back to alert');
      alert(`${type.toUpperCase()}: ${message}`);
      return null;
    }
  }

  // Show a toast with custom actions
  withActions(type, message, actions, options = {}) {
    // For now, we'll show the basic toast and log the actions
    // In a full implementation, you'd extend the toast HTML to include action buttons
    console.log('Toast actions:', actions);
    return this.show(type, message, options);
  }

  // Dismiss all toasts
  dismissAll() {
    const toastContainers = document.querySelectorAll('.toast-container .toast-stack');
    toastContainers.forEach(container => {
      const toasts = container.querySelectorAll('[data-controller="flash"]');
      toasts.forEach(toast => {
        const controller = this.getControllerForElement(toast, 'flash');
        if (controller && controller.dismiss) {
          controller.dismiss();
        } else {
          toast.remove();
        }
      });
    });
  }

  // Helper to get Stimulus controller
  getControllerForElement(element, identifier) {
    if (window.application && window.application.getControllerForElementAndIdentifier) {
      return window.application.getControllerForElementAndIdentifier(element, identifier);
    }
    return null;
  }

  // Campaign-specific toasts
  campaign = {
    created: (campaignName) => {
      return this.success(`Campaign "${campaignName}" created successfully!`, {
        title: 'Campaign Created',
        actions: [
          { text: 'View Campaign', url: '#' },
          { text: 'Create Another', url: '#' }
        ]
      });
    },

    sent: (campaignName, recipientCount) => {
      return this.success(`Campaign "${campaignName}" sent to ${recipientCount} recipients!`, {
        title: 'Campaign Sent',
        duration: 8000
      });
    },

    scheduled: (campaignName, scheduledTime) => {
      return this.info(`Campaign "${campaignName}" scheduled for ${scheduledTime}`, {
        title: 'Campaign Scheduled'
      });
    },

    failed: (campaignName, error) => {
      return this.error(`Failed to send campaign "${campaignName}": ${error}`, {
        title: 'Campaign Failed',
        duration: 10000
      });
    }
  };

  // Contact-specific toasts
  contact = {
    imported: (count) => {
      return this.success(`Successfully imported ${count} contacts!`, {
        title: 'Import Complete'
      });
    },

    subscribed: (email) => {
      return this.success(`${email} subscribed to your mailing list!`, {
        title: 'New Subscriber'
      });
    },

    unsubscribed: (email) => {
      return this.warning(`${email} unsubscribed from your mailing list`, {
        title: 'Unsubscribed'
      });
    }
  };

  // System-specific toasts
  system = {
    saved: () => {
      return this.success('Changes saved successfully!', {
        title: 'Saved',
        duration: 3000
      });
    },

    autoSaved: () => {
      return this.info('Auto-saved', {
        duration: 2000,
        showProgress: false,
        position: 'bottom-right'
      });
    },

    offline: () => {
      return this.warning('You are currently offline. Changes will be saved when connection is restored.', {
        title: 'Offline',
        autoDismiss: false
      });
    },

    online: () => {
      return this.success('Connection restored!', {
        title: 'Online',
        duration: 3000
      });
    },

    updateAvailable: () => {
      return this.info('A new version is available. Refresh to update.', {
        title: 'Update Available',
        autoDismiss: false,
        actions: [
          { text: 'Refresh Now', action: () => window.location.reload() },
          { text: 'Later', action: 'dismiss' }
        ]
      });
    }
  };
}

// Create global toast instance
window.toast = new Toast();

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
  module.exports = Toast;
}

// Auto-initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
  // Initialize toast containers
  if (window.ToastManager) {
    window.ToastManager.initContainer('top-right');
  }

  // Listen for custom toast events
  document.addEventListener('show-toast', function(event) {
    const { type, message, options } = event.detail;
    window.toast.show(type, message, options);
  });

  // Listen for Turbo events to show appropriate toasts
  document.addEventListener('turbo:submit-end', function(event) {
    const response = event.detail.fetchResponse;
    if (response && response.succeeded) {
      // You can customize this based on your needs
      const form = event.target;
      const action = form.action;
      
      if (action.includes('/campaigns') && form.method.toLowerCase() === 'post') {
        window.toast.success('Campaign saved successfully!');
      }
    }
  });

  // Handle network status
  window.addEventListener('online', () => {
    window.toast.system.online();
  });

  window.addEventListener('offline', () => {
    window.toast.system.offline();
  });
});

// Utility function to trigger toasts from Rails
window.showToast = function(type, message, options = {}) {
  return window.toast.show(type, message, options);
};

// Rails UJS compatibility
document.addEventListener('ajax:success', function(event) {
  const response = event.detail[0];
  if (response && response.flash) {
    Object.entries(response.flash).forEach(([type, message]) => {
      const toastType = type === 'notice' ? 'success' : type === 'alert' ? 'error' : type;
      window.toast.show(toastType, message);
    });
  }
});

console.log('🍞 Enhanced Toast System loaded successfully!');
