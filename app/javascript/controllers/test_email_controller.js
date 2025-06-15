import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="test-email"
export default class extends Controller {
  static targets = ["emailInput", "emailList", "sendButton", "status", "includeTracking", "useTestData"]
  static values = { 
    emails: Array,
    currentUserEmail: String,
    teamEmails: Array
  }

  connect() {
    this.emailsValue = this.emailsValue || []
    this.currentUserEmailValue = this.currentUserEmailValue || ""
    this.teamEmailsValue = this.teamEmailsValue || []
    
    this.updateEmailList()
    this.updateSendButton()
  }

  // Add email to the list
  addEmail() {
    const email = this.emailInputTarget.value.trim()
    
    if (!email) {
      this.showError("Please enter an email address")
      return
    }

    if (!this.isValidEmail(email)) {
      this.showError("Please enter a valid email address")
      return
    }

    if (this.emailsValue.includes(email)) {
      this.showError("Email address already added")
      return
    }

    this.emailsValue = [...this.emailsValue, email]
    this.emailInputTarget.value = ""
    this.updateEmailList()
    this.updateSendButton()
    this.clearStatus()
  }

  // Remove email from the list
  removeEmail(event) {
    const email = event.currentTarget.dataset.email
    this.emailsValue = this.emailsValue.filter(e => e !== email)
    this.updateEmailList()
    this.updateSendButton()
  }

  // Add current user email
  addCurrentUser() {
    if (this.currentUserEmailValue && !this.emailsValue.includes(this.currentUserEmailValue)) {
      this.emailsValue = [...this.emailsValue, this.currentUserEmailValue]
      this.updateEmailList()
      this.updateSendButton()
    }
  }

  // Add team emails
  addTeamEmails() {
    const newEmails = this.teamEmailsValue.filter(email => !this.emailsValue.includes(email))
    if (newEmails.length > 0) {
      this.emailsValue = [...this.emailsValue, ...newEmails]
      this.updateEmailList()
      this.updateSendButton()
    }
  }

  // Send test email
  async sendTest() {
    if (this.emailsValue.length === 0) {
      this.showError("Please add at least one email address")
      return
    }

    this.showLoading()
    this.sendButtonTarget.disabled = true

    try {
      const response = await this.sendTestRequest()
      
      if (response.ok) {
        const data = await response.json()
        this.showSuccess(`Test email sent to ${this.emailsValue.length} recipient(s)`)
      } else {
        const errorData = await response.json()
        this.showError(errorData.message || "Failed to send test email")
      }
    } catch (error) {
      this.showError("Network error. Please try again.")
    } finally {
      this.sendButtonTarget.disabled = false
      this.hideLoading()
    }
  }

  // Send test request to server
  async sendTestRequest() {
    const formData = new FormData()
    formData.append('test_emails', JSON.stringify(this.emailsValue))
    formData.append('include_tracking', this.includeTrackingTarget.checked)
    formData.append('use_test_data', this.useTestDataTarget.checked)
    
    // Add campaign data from the form
    const campaignForm = document.querySelector('.campaign-wizard-form')
    if (campaignForm) {
      const formDataEntries = new FormData(campaignForm)
      for (let [key, value] of formDataEntries.entries()) {
        formData.append(key, value)
      }
    }

    return fetch('/campaigns/send_test', {
      method: 'POST',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      }
    })
  }

  // Update email list display
  updateEmailList() {
    const listContainer = this.emailListTarget
    
    if (this.emailsValue.length === 0) {
      listContainer.innerHTML = `
        <div class="text-center py-4 text-gray-500 text-sm">
          No email addresses added yet
        </div>
      `
      return
    }

    listContainer.innerHTML = this.emailsValue.map(email => `
      <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg border border-gray-200">
        <div class="flex items-center">
          <svg class="w-4 h-4 text-gray-400 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
          </svg>
          <span class="text-sm font-medium text-gray-900">${email}</span>
        </div>
        <button type="button" 
                class="text-red-600 hover:text-red-800 transition-colors duration-200"
                data-email="${email}"
                data-action="click->test-email#removeEmail">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
    `).join('')
  }

  // Update send button state
  updateSendButton() {
    const hasEmails = this.emailsValue.length > 0
    this.sendButtonTarget.disabled = !hasEmails
    
    if (hasEmails) {
      this.sendButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed')
    } else {
      this.sendButtonTarget.classList.add('opacity-50', 'cursor-not-allowed')
    }
  }

  // Show loading state
  showLoading() {
    const originalText = this.sendButtonTarget.innerHTML
    this.sendButtonTarget.dataset.originalText = originalText
    this.sendButtonTarget.innerHTML = `
      <svg class="animate-spin -ml-1 mr-2 h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      Sending...
    `
  }

  // Hide loading state
  hideLoading() {
    const originalText = this.sendButtonTarget.dataset.originalText
    if (originalText) {
      this.sendButtonTarget.innerHTML = originalText
    }
  }

  // Show success message
  showSuccess(message) {
    this.statusTarget.classList.remove('hidden')
    this.statusTarget.innerHTML = `
      <div class="flex items-center p-4 bg-green-50 border border-green-200 rounded-lg">
        <svg class="w-5 h-5 text-green-600 mr-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <span class="text-sm font-medium text-green-800">${message}</span>
      </div>
    `
    
    // Auto-hide after 5 seconds
    setTimeout(() => this.clearStatus(), 5000)
  }

  // Show error message
  showError(message) {
    this.statusTarget.classList.remove('hidden')
    this.statusTarget.innerHTML = `
      <div class="flex items-center p-4 bg-red-50 border border-red-200 rounded-lg">
        <svg class="w-5 h-5 text-red-600 mr-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <span class="text-sm font-medium text-red-800">${message}</span>
      </div>
    `
    
    // Auto-hide after 5 seconds
    setTimeout(() => this.clearStatus(), 5000)
  }

  // Clear status message
  clearStatus() {
    this.statusTarget.classList.add('hidden')
    this.statusTarget.innerHTML = ''
  }

  // Validate email format
  isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return emailRegex.test(email)
  }

  // Handle Enter key in email input
  keydown(event) {
    if (event.target === this.emailInputTarget && event.key === 'Enter') {
      event.preventDefault()
      this.addEmail()
    }
  }

  // Handle emails value changes
  emailsValueChanged() {
    this.updateEmailList()
    this.updateSendButton()
  }

  // Clear all emails
  clearAll() {
    this.emailsValue = []
    this.updateEmailList()
    this.updateSendButton()
  }

  // Get current email list
  getEmails() {
    return this.emailsValue
  }

  // Set emails programmatically
  setEmails(emails) {
    this.emailsValue = emails.filter(email => this.isValidEmail(email))
    this.updateEmailList()
    this.updateSendButton()
  }
}
