import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="campaign-wizard"
export default class extends Controller {
  static targets = ["step", "nextButton", "prevButton", "progressBar", "progressStep", "form"]
  static values = { 
    currentStep: Number,
    totalSteps: Number,
    autoSave: Boolean,
    autoSaveInterval: Number
  }

  connect() {
    this.currentStepValue = this.currentStepValue || 1
    this.totalStepsValue = this.totalStepsValue || 4
    this.autoSaveValue = this.autoSaveValue !== false
    this.autoSaveIntervalValue = this.autoSaveIntervalValue || 30000 // 30 seconds
    
    this.updateUI()
    this.setupAutoSave()
  }

  disconnect() {
    if (this.autoSaveTimer) {
      clearInterval(this.autoSaveTimer)
    }
  }

  // Navigate to next step
  next() {
    if (this.validateCurrentStep()) {
      if (this.currentStepValue < this.totalStepsValue) {
        this.currentStepValue++
        this.updateUI()
        this.triggerAutoSave()
      }
    }
  }

  // Navigate to previous step
  previous() {
    if (this.currentStepValue > 1) {
      this.currentStepValue--
      this.updateUI()
    }
  }

  // Jump to specific step
  goToStep(event) {
    const targetStep = parseInt(event.currentTarget.dataset.step)
    if (targetStep <= this.currentStepValue || this.validateStepsUpTo(targetStep - 1)) {
      this.currentStepValue = targetStep
      this.updateUI()
    }
  }

  // Update UI based on current step
  updateUI() {
    // Update step visibility
    this.stepTargets.forEach((step, index) => {
      const stepNumber = index + 1
      if (stepNumber === this.currentStepValue) {
        step.classList.remove('hidden')
        step.classList.add('animate-fadeIn')
      } else {
        step.classList.add('hidden')
        step.classList.remove('animate-fadeIn')
      }
    })

    // Update progress bar
    const progressPercentage = (this.currentStepValue / this.totalStepsValue) * 100
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${progressPercentage}%`
    }

    // Update progress steps
    this.progressStepTargets.forEach((progressStep, index) => {
      const stepNumber = index + 1
      const circle = progressStep.querySelector('.step-circle')
      const label = progressStep.querySelector('.step-label')
      
      if (stepNumber < this.currentStepValue) {
        // Completed step
        circle.className = 'step-circle w-8 h-8 rounded-full flex items-center justify-center bg-gradient-to-r from-green-500 to-emerald-600 text-white text-sm font-semibold transition-all duration-300'
        circle.innerHTML = `
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
          </svg>
        `
        label.className = 'step-label text-sm font-medium text-green-600 mt-2'
      } else if (stepNumber === this.currentStepValue) {
        // Current step
        circle.className = 'step-circle w-8 h-8 rounded-full flex items-center justify-center bg-gradient-to-r from-indigo-600 to-purple-600 text-white text-sm font-semibold transition-all duration-300 ring-4 ring-indigo-100'
        circle.textContent = stepNumber
        label.className = 'step-label text-sm font-medium text-indigo-600 mt-2'
      } else {
        // Future step
        circle.className = 'step-circle w-8 h-8 rounded-full flex items-center justify-center bg-gray-200 text-gray-500 text-sm font-semibold transition-all duration-300'
        circle.textContent = stepNumber
        label.className = 'step-label text-sm font-medium text-gray-400 mt-2'
      }
    })

    // Update navigation buttons
    if (this.hasPrevButtonTarget) {
      this.prevButtonTarget.disabled = this.currentStepValue === 1
      this.prevButtonTarget.classList.toggle('opacity-50', this.currentStepValue === 1)
    }

    if (this.hasNextButtonTarget) {
      const isLastStep = this.currentStepValue === this.totalStepsValue
      this.nextButtonTarget.textContent = isLastStep ? 'Create Campaign' : 'Next Step'
      this.nextButtonTarget.classList.toggle('from-green-600', isLastStep)
      this.nextButtonTarget.classList.toggle('to-emerald-600', isLastStep)
      this.nextButtonTarget.classList.toggle('from-indigo-600', !isLastStep)
      this.nextButtonTarget.classList.toggle('to-purple-600', !isLastStep)
    }

    // Scroll to top of current step
    this.scrollToCurrentStep()
  }

  // Validate current step
  validateCurrentStep() {
    const currentStep = this.stepTargets[this.currentStepValue - 1]
    if (!currentStep) return true

    const requiredFields = currentStep.querySelectorAll('[required]')
    let isValid = true

    requiredFields.forEach(field => {
      if (!field.value.trim()) {
        this.showFieldError(field, 'This field is required')
        isValid = false
      } else {
        this.clearFieldError(field)
      }
    })

    // Custom validation for specific steps
    if (this.currentStepValue === 1) {
      isValid = this.validateStep1() && isValid
    } else if (this.currentStepValue === 2) {
      isValid = this.validateStep2() && isValid
    } else if (this.currentStepValue === 3) {
      isValid = this.validateStep3() && isValid
    }

    return isValid
  }

  // Step-specific validations
  validateStep1() {
    const nameField = this.element.querySelector('[name="campaign[name]"]')
    const subjectField = this.element.querySelector('[name="campaign[subject]"]')
    
    let isValid = true

    if (nameField && nameField.value.length > 100) {
      this.showFieldError(nameField, 'Campaign name must be 100 characters or less')
      isValid = false
    }

    if (subjectField && subjectField.value.length > 78) {
      this.showFieldError(subjectField, 'Subject line should be 78 characters or less for optimal display')
      isValid = false
    }

    return isValid
  }

  validateStep2() {
    const audienceType = this.element.querySelector('[name="campaign[audience_type]"]:checked')
    if (!audienceType) {
      this.showToast('Please select a target audience', 'error')
      return false
    }
    return true
  }

  validateStep3() {
    const templateChoice = this.element.querySelector('[name="campaign[template_choice]"]:checked')
    if (!templateChoice) {
      this.showToast('Please select a template or choose to create from scratch', 'error')
      return false
    }
    return true
  }

  // Validate steps up to a certain point
  validateStepsUpTo(stepNumber) {
    const originalStep = this.currentStepValue
    let allValid = true

    for (let i = 1; i <= stepNumber; i++) {
      this.currentStepValue = i
      if (!this.validateCurrentStep()) {
        allValid = false
        break
      }
    }

    this.currentStepValue = originalStep
    return allValid
  }

  // Show field error
  showFieldError(field, message) {
    this.clearFieldError(field)
    
    field.classList.add('border-red-300', 'focus:border-red-500', 'focus:ring-red-500')
    field.classList.remove('border-gray-300', 'focus:border-indigo-500', 'focus:ring-indigo-500')

    const errorDiv = document.createElement('div')
    errorDiv.className = 'field-error text-red-600 text-sm mt-1'
    errorDiv.textContent = message
    
    field.parentNode.appendChild(errorDiv)
  }

  // Clear field error
  clearFieldError(field) {
    field.classList.remove('border-red-300', 'focus:border-red-500', 'focus:ring-red-500')
    field.classList.add('border-gray-300', 'focus:border-indigo-500', 'focus:ring-indigo-500')

    const existingError = field.parentNode.querySelector('.field-error')
    if (existingError) {
      existingError.remove()
    }
  }

  // Setup auto-save functionality
  setupAutoSave() {
    if (this.autoSaveValue && this.hasFormTarget) {
      this.autoSaveTimer = setInterval(() => {
        this.triggerAutoSave()
      }, this.autoSaveIntervalValue)

      // Also save on form changes
      this.formTarget.addEventListener('input', this.debounce(() => {
        this.triggerAutoSave()
      }, 2000))
    }
  }

  // Trigger auto-save
  async triggerAutoSave() {
    if (!this.hasFormTarget) return

    try {
      const formData = new FormData(this.formTarget)
      formData.append('auto_save', 'true')

      const response = await fetch(this.formTarget.action, {
        method: 'POST',
        body: formData,
        headers: {
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (response.ok) {
        this.showAutoSaveIndicator()
      }
    } catch (error) {
      console.error('Auto-save failed:', error)
    }
  }

  // Show auto-save indicator
  showAutoSaveIndicator() {
    const indicator = document.createElement('div')
    indicator.className = 'fixed top-4 right-4 bg-green-500 text-white px-4 py-2 rounded-lg shadow-lg z-50 transition-all duration-300'
    indicator.textContent = 'Draft saved'
    
    document.body.appendChild(indicator)
    
    setTimeout(() => {
      indicator.style.opacity = '0'
      setTimeout(() => {
        document.body.removeChild(indicator)
      }, 300)
    }, 2000)
  }

  // Scroll to current step
  scrollToCurrentStep() {
    const currentStep = this.stepTargets[this.currentStepValue - 1]
    if (currentStep) {
      currentStep.scrollIntoView({ behavior: 'smooth', block: 'start' })
    }
  }

  // Show toast notification
  showToast(message, type = 'info') {
    // Dispatch custom event for toast controller
    this.dispatch('toast', { 
      detail: { message, type }
    })
  }

  // Utility: Debounce function
  debounce(func, wait) {
    let timeout
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout)
        func(...args)
      }
      clearTimeout(timeout)
      timeout = setTimeout(later, wait)
    }
  }

  // Handle form submission
  submit(event) {
    if (!this.validateCurrentStep()) {
      event.preventDefault()
      return false
    }

    // Show loading state
    if (this.hasNextButtonTarget) {
      this.nextButtonTarget.disabled = true
      this.nextButtonTarget.innerHTML = `
        <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Creating Campaign...
      `
    }
  }
}
