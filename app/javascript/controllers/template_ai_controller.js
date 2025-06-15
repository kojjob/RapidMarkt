import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="template-ai"
export default class extends Controller {
  static targets = [
    "generateButton", "promptInput", "templateTypeSelect", "industrySelect",
    "toneSelect", "lengthSelect", "loadingIndicator", "resultContainer",
    "previewArea", "useTemplateButton"
  ]

  static values = {
    apiEndpoint: String,
    maxRetries: Number,
    retryDelay: Number
  }

  connect() {
    this.apiEndpointValue = this.apiEndpointValue || '/api/v1/templates/generate'
    this.maxRetriesValue = this.maxRetriesValue || 3
    this.retryDelayValue = this.retryDelayValue || 1000
    
    this.isGenerating = false
    this.currentGeneration = null
  }

  // Generate AI template
  async generate() {
    if (this.isGenerating) return

    const prompt = this.promptInputTarget.value.trim()
    if (!prompt) {
      this.showError('Please enter a description for your template')
      return
    }

    this.isGenerating = true
    this.showLoading()

    try {
      const templateData = this.collectTemplateData()
      const response = await this.callAIAPI(templateData)
      
      if (response.success) {
        this.displayGeneratedTemplate(response.template)
      } else {
        this.showError(response.error || 'Failed to generate template')
      }
    } catch (error) {
      console.error('AI generation error:', error)
      this.showError('An error occurred while generating the template')
    } finally {
      this.isGenerating = false
      this.hideLoading()
    }
  }

  // Collect template generation data
  collectTemplateData() {
    return {
      prompt: this.promptInputTarget.value.trim(),
      template_type: this.hasTemplateTypeSelectTarget ? this.templateTypeSelectTarget.value : 'email',
      industry: this.hasIndustrySelectTarget ? this.industrySelectTarget.value : 'general',
      tone: this.hasToneSelectTarget ? this.toneSelectTarget.value : 'professional',
      length: this.hasLengthSelectTarget ? this.lengthSelectTarget.value : 'medium',
      preferences: this.getUserPreferences()
    }
  }

  // Get user preferences from local storage or defaults
  getUserPreferences() {
    const stored = localStorage.getItem('rapidmarkt_template_preferences')
    const defaults = {
      color_scheme: 'modern',
      font_family: 'sans-serif',
      layout_style: 'clean',
      include_images: true,
      include_cta: true,
      responsive: true
    }

    return stored ? { ...defaults, ...JSON.parse(stored) } : defaults
  }

  // Call AI API with retry logic
  async callAIAPI(templateData, retryCount = 0) {
    try {
      const response = await fetch(this.apiEndpointValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify({ template: templateData })
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }

      return await response.json()
    } catch (error) {
      if (retryCount < this.maxRetriesValue) {
        await this.delay(this.retryDelayValue * (retryCount + 1))
        return this.callAIAPI(templateData, retryCount + 1)
      }
      throw error
    }
  }

  // Display generated template
  displayGeneratedTemplate(template) {
    this.currentGeneration = template

    // Update preview area
    if (this.hasPreviewAreaTarget) {
      this.previewAreaTarget.innerHTML = this.renderTemplatePreview(template)
    }

    // Show result container
    if (this.hasResultContainerTarget) {
      this.resultContainerTarget.classList.remove('hidden')
    }

    // Enable use template button
    if (this.hasUseTemplateButtonTarget) {
      this.useTemplateButtonTarget.disabled = false
    }

    this.showSuccess('Template generated successfully!')
  }

  // Render template preview
  renderTemplatePreview(template) {
    return `
      <div class="template-preview bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
        <div class="preview-header bg-gradient-to-r from-purple-600 to-pink-600 text-white p-4">
          <h3 class="font-bold text-lg">${template.title || 'Generated Template'}</h3>
          <p class="text-sm opacity-90">${template.description || 'AI-generated template'}</p>
        </div>
        
        <div class="preview-content p-6">
          <div class="template-html-preview border border-gray-200 rounded-lg p-4 bg-gray-50 max-h-96 overflow-y-auto">
            ${template.html_content || '<p>No content generated</p>'}
          </div>
          
          <div class="template-metadata mt-4 grid grid-cols-2 gap-4 text-sm">
            <div>
              <span class="font-medium text-gray-700">Type:</span>
              <span class="text-gray-600">${template.type || 'Email'}</span>
            </div>
            <div>
              <span class="font-medium text-gray-700">Style:</span>
              <span class="text-gray-600">${template.style || 'Modern'}</span>
            </div>
            <div>
              <span class="font-medium text-gray-700">Components:</span>
              <span class="text-gray-600">${template.components?.length || 0} elements</span>
            </div>
            <div>
              <span class="font-medium text-gray-700">Responsive:</span>
              <span class="text-gray-600">${template.responsive ? 'Yes' : 'No'}</span>
            </div>
          </div>
        </div>
        
        <div class="preview-actions bg-gray-50 px-6 py-4 flex justify-between items-center">
          <div class="flex space-x-2">
            <button type="button" 
                    class="regenerate-btn px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors duration-200"
                    data-action="click->template-ai#regenerate">
              🔄 Regenerate
            </button>
            <button type="button" 
                    class="customize-btn px-4 py-2 text-sm font-medium text-purple-700 bg-purple-100 border border-purple-300 rounded-lg hover:bg-purple-200 transition-colors duration-200"
                    data-action="click->template-ai#customize">
              ✨ Customize
            </button>
          </div>
          
          <button type="button" 
                  class="use-template-btn px-6 py-2 text-sm font-medium text-white bg-gradient-to-r from-purple-600 to-pink-600 rounded-lg hover:from-purple-700 hover:to-pink-700 transition-all duration-200 transform hover:scale-105"
                  data-action="click->template-ai#useTemplate">
            Use This Template
          </button>
        </div>
      </div>
    `
  }

  // Use generated template
  useTemplate() {
    if (!this.currentGeneration) return

    // Dispatch custom event with template data
    const event = new CustomEvent('template:use', {
      detail: {
        template: this.currentGeneration,
        source: 'ai-generated'
      },
      bubbles: true
    })

    this.element.dispatchEvent(event)
    this.showSuccess('Template applied to builder!')
  }

  // Regenerate template with same parameters
  async regenerate() {
    if (this.isGenerating) return
    
    // Add slight variation to prompt for different results
    const originalPrompt = this.promptInputTarget.value
    this.promptInputTarget.value = `${originalPrompt} (variation)`
    
    await this.generate()
    
    // Restore original prompt
    this.promptInputTarget.value = originalPrompt
  }

  // Customize template (open customization modal)
  customize() {
    if (!this.currentGeneration) return

    // Dispatch custom event to open customization
    const event = new CustomEvent('template:customize', {
      detail: {
        template: this.currentGeneration
      },
      bubbles: true
    })

    this.element.dispatchEvent(event)
  }

  // Show loading state
  showLoading() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.remove('hidden')
    }
    
    if (this.hasGenerateButtonTarget) {
      this.generateButtonTarget.disabled = true
      this.generateButtonTarget.innerHTML = `
        <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Generating...
      `
    }
  }

  // Hide loading state
  hideLoading() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.add('hidden')
    }
    
    if (this.hasGenerateButtonTarget) {
      this.generateButtonTarget.disabled = false
      this.generateButtonTarget.innerHTML = '✨ Generate Template'
    }
  }

  // Show success message
  showSuccess(message) {
    this.showNotification(message, 'success')
  }

  // Show error message
  showError(message) {
    this.showNotification(message, 'error')
  }

  // Show notification
  showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 z-50 p-4 rounded-lg shadow-lg transition-all duration-300 transform translate-x-full ${
      type === 'success' ? 'bg-green-500 text-white' :
      type === 'error' ? 'bg-red-500 text-white' :
      'bg-blue-500 text-white'
    }`
    notification.textContent = message

    document.body.appendChild(notification)

    // Animate in
    setTimeout(() => {
      notification.classList.remove('translate-x-full')
    }, 100)

    // Remove after delay
    setTimeout(() => {
      notification.classList.add('translate-x-full')
      setTimeout(() => {
        document.body.removeChild(notification)
      }, 300)
    }, 3000)
  }

  // Utility: delay function
  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms))
  }
}
