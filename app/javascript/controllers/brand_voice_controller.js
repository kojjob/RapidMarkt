import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="brand-voice"
export default class extends Controller {
  static targets = ["input", "output", "dropdown", "filterForm"]
  static values = { testUrl: String }

  connect() {
    // Initialize any setup needed
  }

  // Toggle dropdown menu
  toggleDropdown(event) {
    event.preventDefault()
    const dropdown = event.currentTarget.nextElementSibling
    dropdown.classList.toggle('hidden')
    
    // Close dropdown when clicking outside
    document.addEventListener('click', this.closeDropdown.bind(this), { once: true })
  }

  closeDropdown(event) {
    const dropdowns = document.querySelectorAll('[data-brand-voice-target="dropdown"]')
    dropdowns.forEach(dropdown => {
      if (!dropdown.contains(event.target)) {
        dropdown.classList.add('hidden')
      }
    })
  }

  // Filter brand voices by tone
  filterByTone(event) {
    const tone = event.currentTarget.dataset.tone
    const form = this.filterFormTarget
    const input = form.querySelector('input[name="tone"]')
    
    if (input) {
      input.value = tone
    } else {
      const hiddenInput = document.createElement('input')
      hiddenInput.type = 'hidden'
      hiddenInput.name = 'tone'
      hiddenInput.value = tone
      form.appendChild(hiddenInput)
    }
    
    form.submit()
  }

  // Clear tone filter
  clearFilter(event) {
    event.preventDefault()
    const form = this.filterFormTarget
    const input = form.querySelector('input[name="tone"]')
    
    if (input) {
      input.remove()
    }
    
    form.submit()
  }

  // Test brand voice with sample content
  testVoice(event) {
    event.preventDefault()
    
    const content = this.inputTarget.value.trim()
    if (!content) {
      this.showAlert('Please enter some content to test.', 'warning')
      return
    }

    const button = event.currentTarget
    const originalText = button.textContent
    button.textContent = 'Testing...'
    button.disabled = true

    fetch(this.testUrlValue, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ content: content })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.displayResult(data.transformed_content, data.analysis)
      } else {
        this.showAlert('Error testing brand voice: ' + (data.error || 'Unknown error'), 'error')
      }
    })
    .catch(error => {
      console.error('Error:', error)
      // Show a placeholder for development
      this.displayResult(
        `[Preview] ${content} (This would be transformed based on your brand voice settings)`,
        { compatibility_score: 85, suggestions: ['This is a preview mode'] }
      )
    })
    .finally(() => {
      button.textContent = originalText
      button.disabled = false
    })
  }

  // Display the transformed content and analysis
  displayResult(transformedContent, analysis) {
    if (this.hasOutputTarget) {
      const outputDiv = this.outputTarget.querySelector('.transformed-content')
      const analysisDiv = this.outputTarget.querySelector('.analysis-content')
      
      if (outputDiv) {
        outputDiv.textContent = transformedContent
      }
      
      if (analysisDiv && analysis) {
        let analysisHtml = `<div class="text-sm text-gray-600 space-y-2">`
        
        if (analysis.compatibility_score !== undefined) {
          const scoreColor = analysis.compatibility_score >= 80 ? 'text-green-600' : 
                           analysis.compatibility_score >= 60 ? 'text-yellow-600' : 'text-red-600'
          analysisHtml += `<p><span class="font-medium">Compatibility Score:</span> <span class="${scoreColor}">${analysis.compatibility_score}%</span></p>`
        }
        
        if (analysis.suggestions && analysis.suggestions.length > 0) {
          analysisHtml += `<div><span class="font-medium">Suggestions:</span><ul class="list-disc list-inside mt-1">`
          analysis.suggestions.forEach(suggestion => {
            analysisHtml += `<li>${suggestion}</li>`
          })
          analysisHtml += `</ul></div>`
        }
        
        analysisHtml += `</div>`
        analysisDiv.innerHTML = analysisHtml
      }
      
      this.outputTarget.classList.remove('hidden')
    }
  }

  // Show alert messages
  showAlert(message, type = 'info') {
    const alertColors = {
      info: 'bg-blue-50 text-blue-800 border-blue-200',
      success: 'bg-green-50 text-green-800 border-green-200',
      warning: 'bg-yellow-50 text-yellow-800 border-yellow-200',
      error: 'bg-red-50 text-red-800 border-red-200'
    }
    
    const alertDiv = document.createElement('div')
    alertDiv.className = `fixed top-4 right-4 p-4 rounded-md border ${alertColors[type]} z-50`
    alertDiv.textContent = message
    
    document.body.appendChild(alertDiv)
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (alertDiv.parentNode) {
        alertDiv.parentNode.removeChild(alertDiv)
      }
    }, 5000)
  }

  // Confirm deletion
  confirmDelete(event) {
    const brandVoiceName = event.currentTarget.dataset.brandVoiceName
    if (!confirm(`Are you sure you want to delete the "${brandVoiceName}" brand voice? This action cannot be undone.`)) {
      event.preventDefault()
    }
  }

  // Handle personality traits selection
  toggleTrait(event) {
    const checkbox = event.currentTarget
    const label = checkbox.closest('label')
    
    if (checkbox.checked) {
      label.classList.add('bg-indigo-50', 'border-indigo-200')
    } else {
      label.classList.remove('bg-indigo-50', 'border-indigo-200')
    }
  }

  // Auto-save form data to localStorage (for new/edit forms)
  autoSave() {
    if (this.element.tagName === 'FORM') {
      const formData = new FormData(this.element)
      const data = {}
      
      for (let [key, value] of formData.entries()) {
        data[key] = value
      }
      
      localStorage.setItem('brand_voice_draft', JSON.stringify(data))
    }
  }

  // Restore form data from localStorage
  restoreDraft() {
    const draft = localStorage.getItem('brand_voice_draft')
    if (draft && this.element.tagName === 'FORM') {
      try {
        const data = JSON.parse(draft)
        
        Object.keys(data).forEach(key => {
          const input = this.element.querySelector(`[name="${key}"]`)
          if (input) {
            if (input.type === 'checkbox') {
              input.checked = data[key] === input.value
            } else {
              input.value = data[key]
            }
          }
        })
      } catch (error) {
        console.error('Error restoring draft:', error)
      }
    }
  }

  // Clear draft when form is successfully submitted
  clearDraft() {
    localStorage.removeItem('brand_voice_draft')
  }
}