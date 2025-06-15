import { Controller } from "@hotwired/stimulus"

// Production-ready Template Builder Controller
export default class extends Controller {
  static targets = [
    "form", "nameInput", "typeSelect", "previewBtn", "saveBtn", "publishBtn",
    "statusText", "lastSaved", "sidebar", "canvas", "dropZone", "toolbar",
    "searchInput", "categoryFilter", "componentsGrid", "aiPrompt", "aiPlatform",
    "aiContentType", "aiIndustry", "aiTone", "generateBtn", "aiLoading", "aiResults",
    "canvasSize", "backgroundColor", "backgroundColorText", "gridToggle", "exportFormat", "exportQuality"
  ]

  static values = {
    templateId: String,
    userId: String,
    autoSave: Boolean,
    apiEndpoint: String,
    csrfToken: String
  }

  connect() {
    console.log('🚀 Production Template Builder initialized')
    
    // Initialize values
    this.apiEndpointValue = this.apiEndpointValue || '/api/v1/templates'
    this.csrfTokenValue = document.querySelector('meta[name="csrf-token"]')?.content
    this.autoSaveValue = this.autoSaveValue !== false
    
    // Initialize state
    this.components = []
    this.history = []
    this.historyIndex = -1
    this.isDirty = false
    this.isGenerating = false
    
    // Setup
    this.setupEventListeners()
    this.loadComponents()
    this.setupAutoSave()
    this.setupKeyboardShortcuts()
    this.initializeCanvas()
    
    // Load existing template if editing
    if (this.templateIdValue && this.templateIdValue !== 'new') {
      this.loadTemplate()
    }
  }

  disconnect() {
    this.cleanup()
  }

  // Setup event listeners
  setupEventListeners() {
    // Form changes
    if (this.hasNameInputTarget) {
      this.nameInputTarget.addEventListener('input', () => {
        this.markDirty()
        this.updateStatus('editing')
      })
    }

    if (this.hasTypeSelectTarget) {
      this.typeSelectTarget.addEventListener('change', () => {
        this.handleTypeChange()
      })
    }

    // Canvas events
    this.setupCanvasEvents()
    
    // Window events
    window.addEventListener('beforeunload', this.handleBeforeUnload.bind(this))
  }

  // Setup canvas events
  setupCanvasEvents() {
    if (this.hasCanvasTarget) {
      // Drag and drop
      this.canvasTarget.addEventListener('dragover', this.handleDragOver.bind(this))
      this.canvasTarget.addEventListener('drop', this.handleDrop.bind(this))
      this.canvasTarget.addEventListener('dragleave', this.handleDragLeave.bind(this))
      
      // Click events
      this.canvasTarget.addEventListener('click', this.handleCanvasClick.bind(this))
    }
  }

  // Load components from API
  async loadComponents() {
    try {
      const response = await fetch(`${this.apiEndpointValue}/components`, {
        headers: {
          'X-CSRF-Token': this.csrfTokenValue,
          'Content-Type': 'application/json'
        }
      })

      if (response.ok) {
        this.components = await response.json()
        this.renderComponents()
      } else {
        // Fallback to default components
        this.components = this.getDefaultComponents()
        this.renderComponents()
      }
    } catch (error) {
      console.error('Failed to load components:', error)
      this.components = this.getDefaultComponents()
      this.renderComponents()
    }
  }

  // Get default components (fallback)
  getDefaultComponents() {
    return [
      {
        id: 'header-simple',
        name: 'Simple Header',
        category: 'headers',
        platform: 'email',
        description: 'Clean header with logo and navigation',
        thumbnail: '/assets/components/header-simple.svg',
        html: '<div class="header-simple"><h1>Your Header</h1></div>',
        css: '.header-simple { padding: 20px; background: #f8f9fa; text-align: center; }',
        responsive: true
      },
      {
        id: 'tiktok-video',
        name: 'TikTok Video',
        category: 'tiktok',
        platform: 'tiktok',
        description: 'Vertical video template with effects',
        thumbnail: '/assets/components/tiktok-video.svg',
        html: '<div class="tiktok-video"><div class="video-overlay"><h2>Your TikTok Content</h2></div></div>',
        css: '.tiktok-video { aspect-ratio: 9/16; background: #000; color: white; position: relative; }',
        aspectRatio: '9:16'
      },
      {
        id: 'instagram-story',
        name: 'Instagram Story',
        category: 'instagram',
        platform: 'instagram',
        description: 'Story template with interactive elements',
        thumbnail: '/assets/components/instagram-story.svg',
        html: '<div class="instagram-story"><div class="story-content"><h2>Your Story</h2></div></div>',
        css: '.instagram-story { aspect-ratio: 9/16; background: linear-gradient(45deg, #f09433, #e6683c); }',
        aspectRatio: '9:16'
      },
      {
        id: 'cta-button',
        name: 'Call-to-Action Button',
        category: 'buttons',
        platform: 'universal',
        description: 'Prominent action button',
        thumbnail: '/assets/components/cta-button.svg',
        html: '<div class="cta-container"><button class="cta-button">Call to Action</button></div>',
        css: '.cta-button { background: #007bff; color: white; padding: 12px 24px; border: none; border-radius: 6px; }'
      }
    ]
  }

  // Render components in grid
  renderComponents() {
    if (!this.hasComponentsGridTarget) return

    const filteredComponents = this.getFilteredComponents()
    
    const html = filteredComponents.map(component => `
      <div class="component-item" 
           draggable="true" 
           data-component-id="${component.id}"
           data-action="dragstart->production-template-builder#handleComponentDragStart">
        <div class="component-thumbnail">
          ${component.thumbnail ? 
            `<img src="${component.thumbnail}" alt="${component.name}" />` : 
            `<div class="component-placeholder">${this.getComponentIcon(component.category)}</div>`
          }
        </div>
        <div class="component-info">
          <h4>${component.name}</h4>
          <p>${component.description}</p>
          <div class="component-meta">
            <span class="platform-tag platform-${component.platform}">${component.platform}</span>
            ${component.responsive ? '<span class="feature-tag">Responsive</span>' : ''}
          </div>
        </div>
        <div class="component-actions">
          <button type="button" 
                  class="btn btn-sm btn-secondary"
                  data-action="click->production-template-builder#previewComponent"
                  data-component-id="${component.id}">
            Preview
          </button>
          <button type="button" 
                  class="btn btn-sm btn-primary"
                  data-action="click->production-template-builder#addComponent"
                  data-component-id="${component.id}">
            Add
          </button>
        </div>
      </div>
    `).join('')

    this.componentsGridTarget.innerHTML = html
  }

  // Get filtered components based on search and category
  getFilteredComponents() {
    let filtered = [...this.components]

    // Filter by search
    if (this.hasSearchInputTarget && this.searchInputTarget.value) {
      const search = this.searchInputTarget.value.toLowerCase()
      filtered = filtered.filter(component => 
        component.name.toLowerCase().includes(search) ||
        component.description.toLowerCase().includes(search) ||
        component.category.toLowerCase().includes(search)
      )
    }

    // Filter by category
    if (this.hasCategoryFilterTarget && this.categoryFilterTarget.value) {
      const category = this.categoryFilterTarget.value
      filtered = filtered.filter(component => component.category === category)
    }

    return filtered
  }

  // Get component icon based on category
  getComponentIcon(category) {
    const icons = {
      headers: '📰',
      content: '📝',
      buttons: '🔘',
      images: '🖼️',
      social: '📱',
      tiktok: '🎵',
      instagram: '📸',
      youtube: '📺',
      linkedin: '💼',
      ecommerce: '🛒',
      forms: '📋'
    }
    return icons[category] || '📦'
  }

  // Handle component drag start
  handleComponentDragStart(event) {
    const componentId = event.target.closest('.component-item').dataset.componentId
    event.dataTransfer.setData('text/plain', componentId)
    event.dataTransfer.effectAllowed = 'copy'
  }

  // Handle canvas drag over
  handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'copy'
    this.canvasTarget.classList.add('drag-over')
  }

  // Handle canvas drag leave
  handleDragLeave(event) {
    if (!this.canvasTarget.contains(event.relatedTarget)) {
      this.canvasTarget.classList.remove('drag-over')
    }
  }

  // Handle canvas drop
  handleDrop(event) {
    event.preventDefault()
    this.canvasTarget.classList.remove('drag-over')
    
    const componentId = event.dataTransfer.getData('text/plain')
    const rect = this.canvasTarget.getBoundingClientRect()
    const x = event.clientX - rect.left
    const y = event.clientY - rect.top
    
    this.addComponentToCanvas(componentId, x, y)
  }

  // Add component to canvas
  addComponentToCanvas(componentId, x = 0, y = 0) {
    const component = this.components.find(c => c.id === componentId)
    if (!component) return

    this.saveState()

    const element = document.createElement('div')
    element.className = 'canvas-component'
    element.dataset.componentId = componentId
    element.style.position = 'absolute'
    element.style.left = `${x}px`
    element.style.top = `${y}px`
    element.innerHTML = component.html

    // Add component styles
    if (component.css) {
      this.addComponentStyles(component.css)
    }

    // Make component interactive
    this.makeComponentInteractive(element)

    this.canvasTarget.appendChild(element)
    this.markDirty()
    this.showNotification(`${component.name} added to canvas`, 'success')
  }

  // Make component interactive
  makeComponentInteractive(element) {
    element.addEventListener('click', (e) => {
      e.stopPropagation()
      this.selectComponent(element)
    })

    element.addEventListener('dblclick', (e) => {
      e.stopPropagation()
      this.editComponent(element)
    })

    // Make draggable within canvas
    this.makeDraggable(element)
  }

  // Make element draggable within canvas
  makeDraggable(element) {
    let isDragging = false
    let startX, startY, initialX, initialY

    element.addEventListener('mousedown', (e) => {
      if (e.target.closest('.component-handle') || e.ctrlKey || e.metaKey) {
        isDragging = true
        startX = e.clientX
        startY = e.clientY
        initialX = parseInt(element.style.left) || 0
        initialY = parseInt(element.style.top) || 0
        
        element.style.zIndex = '1000'
        document.addEventListener('mousemove', handleMouseMove)
        document.addEventListener('mouseup', handleMouseUp)
      }
    })

    const handleMouseMove = (e) => {
      if (!isDragging) return
      
      const deltaX = e.clientX - startX
      const deltaY = e.clientY - startY
      
      element.style.left = `${initialX + deltaX}px`
      element.style.top = `${initialY + deltaY}px`
    }

    const handleMouseUp = () => {
      if (isDragging) {
        isDragging = false
        element.style.zIndex = ''
        this.markDirty()
        document.removeEventListener('mousemove', handleMouseMove)
        document.removeEventListener('mouseup', handleMouseUp)
      }
    }
  }

  // Switch tabs
  switchTab(event) {
    const tabName = event.target.dataset.tab
    
    // Update tab buttons
    this.element.querySelectorAll('.tab-btn').forEach(btn => {
      btn.classList.remove('active')
    })
    event.target.classList.add('active')

    // Update tab content
    this.element.querySelectorAll('.tab-content').forEach(content => {
      content.classList.remove('active')
    })
    this.element.querySelector(`[data-tab-content="${tabName}"]`).classList.add('active')
  }

  // Search components
  searchComponents() {
    this.renderComponents()
  }

  // Filter by category
  filterByCategory() {
    this.renderComponents()
  }

  // Generate with AI
  async generateWithAI() {
    if (this.isGenerating) return

    const prompt = this.aiPromptTarget.value.trim()
    if (!prompt) {
      this.showNotification('Please enter a description for your template', 'error')
      return
    }

    this.isGenerating = true
    this.showAILoading()

    try {
      const templateData = {
        prompt: prompt,
        platform: this.aiPlatformTarget.value,
        content_type: this.aiContentTypeTarget.value,
        industry: this.aiIndustryTarget.value,
        tone: this.aiToneTarget.value,
        user_id: this.userIdValue
      }

      const response = await fetch(`${this.apiEndpointValue}/generate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfTokenValue
        },
        body: JSON.stringify({ template: templateData })
      })

      if (response.ok) {
        const result = await response.json()
        this.displayAIResult(result)
      } else {
        throw new Error('AI generation failed')
      }
    } catch (error) {
      console.error('AI generation error:', error)
      this.showNotification('Failed to generate template. Please try again.', 'error')
    } finally {
      this.isGenerating = false
      this.hideAILoading()
    }
  }

  // Show AI loading state
  showAILoading() {
    if (this.hasAiLoadingTarget) {
      this.aiLoadingTarget.classList.remove('hidden')
    }
    if (this.hasGenerateBtnTarget) {
      this.generateBtnTarget.disabled = true
      this.generateBtnTarget.innerHTML = `
        <div class="loading-spinner"></div>
        Generating...
      `
    }
  }

  // Hide AI loading state
  hideAILoading() {
    if (this.hasAiLoadingTarget) {
      this.aiLoadingTarget.classList.add('hidden')
    }
    if (this.hasGenerateBtnTarget) {
      this.generateBtnTarget.disabled = false
      this.generateBtnTarget.innerHTML = `
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M12 2L2 7l10 5 10-5-10-5z"/>
          <path d="M2 17l10 5 10-5"/>
          <path d="M2 12l10 5 10-5"/>
        </svg>
        Generate Template
      `
    }
  }

  // Display AI result
  displayAIResult(result) {
    if (this.hasAiResultsTarget) {
      this.aiResultsTarget.innerHTML = `
        <div class="ai-result">
          <h4>Generated Template</h4>
          <div class="result-preview">${result.html}</div>
          <div class="result-actions">
            <button type="button" 
                    class="btn btn-primary"
                    data-action="click->production-template-builder#useAIResult"
                    data-result='${JSON.stringify(result)}'>
              Use This Template
            </button>
            <button type="button" 
                    class="btn btn-secondary"
                    data-action="click->production-template-builder#regenerateAI">
              Regenerate
            </button>
          </div>
        </div>
      `
      this.aiResultsTarget.classList.remove('hidden')
    }
  }

  // Use AI result
  useAIResult(event) {
    const result = JSON.parse(event.target.dataset.result)
    this.saveState()
    
    if (this.hasCanvasTarget) {
      this.canvasTarget.innerHTML = result.html
    }
    
    this.markDirty()
    this.showNotification('AI template applied to canvas', 'success')
  }

  // Save template
  async saveDraft() {
    await this.saveTemplate('draft')
  }

  // Publish template
  async publish() {
    await this.saveTemplate('published')
  }

  // Save template with status
  async saveTemplate(status = 'draft') {
    const templateData = this.getTemplateData()
    templateData.status = status

    try {
      const url = this.templateIdValue && this.templateIdValue !== 'new' 
        ? `${this.apiEndpointValue}/${this.templateIdValue}`
        : this.apiEndpointValue

      const method = this.templateIdValue && this.templateIdValue !== 'new' ? 'PATCH' : 'POST'

      const response = await fetch(url, {
        method: method,
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfTokenValue
        },
        body: JSON.stringify({ template: templateData })
      })

      if (response.ok) {
        const result = await response.json()
        this.templateIdValue = result.id
        this.isDirty = false
        this.updateLastSaved()
        this.updateStatus(status)
        this.showNotification(`Template ${status === 'published' ? 'published' : 'saved'} successfully`, 'success')
      } else {
        throw new Error('Save failed')
      }
    } catch (error) {
      console.error('Save error:', error)
      this.showNotification('Failed to save template', 'error')
    }
  }

  // Get template data
  getTemplateData() {
    return {
      name: this.hasNameInputTarget ? this.nameInputTarget.value : '',
      template_type: this.hasTypeSelectTarget ? this.typeSelectTarget.value : 'email',
      body: this.hasCanvasTarget ? this.canvasTarget.innerHTML : '',
      settings: this.getTemplateSettings(),
      user_id: this.userIdValue
    }
  }

  // Get template settings
  getTemplateSettings() {
    return {
      canvas_size: this.hasCanvasSizeTarget ? this.canvasSizeTarget.value : 'email',
      background_color: this.hasBackgroundColorTarget ? this.backgroundColorTarget.value : '#ffffff',
      grid_enabled: this.hasGridToggleTarget ? this.gridToggleTarget.checked : false,
      export_format: this.hasExportFormatTarget ? this.exportFormatTarget.value : 'html',
      export_quality: this.hasExportQualityTarget ? this.exportQualityTarget.value : 'high'
    }
  }

  // Setup auto-save
  setupAutoSave() {
    if (this.autoSaveValue) {
      setInterval(() => {
        if (this.isDirty && !this.isGenerating) {
          this.autoSave()
        }
      }, 30000) // Auto-save every 30 seconds
    }
  }

  // Auto-save
  async autoSave() {
    if (this.templateIdValue && this.templateIdValue !== 'new') {
      try {
        const templateData = this.getTemplateData()
        
        const response = await fetch(`/templates/auto_save`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': this.csrfTokenValue
          },
          body: JSON.stringify({
            template_id: this.templateIdValue,
            content: templateData.body
          })
        })

        if (response.ok) {
          this.updateLastSaved()
        }
      } catch (error) {
        console.error('Auto-save failed:', error)
      }
    }
  }

  // Setup keyboard shortcuts
  setupKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {
      if (e.ctrlKey || e.metaKey) {
        switch (e.key) {
          case 's':
            e.preventDefault()
            this.saveDraft()
            break
          case 'z':
            e.preventDefault()
            if (e.shiftKey) {
              this.redo()
            } else {
              this.undo()
            }
            break
        }
      }
    })
  }

  // Initialize canvas
  initializeCanvas() {
    if (this.hasCanvasTarget) {
      this.canvasTarget.addEventListener('click', () => {
        this.clearSelection()
      })
    }
  }

  // Utility methods
  markDirty() {
    this.isDirty = true
    this.updateStatus('editing')
  }

  updateStatus(status) {
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = status.charAt(0).toUpperCase() + status.slice(1)
    }
  }

  updateLastSaved() {
    if (this.hasLastSavedTarget) {
      this.lastSavedTarget.textContent = new Date().toLocaleTimeString()
    }
  }

  showNotification(message, type = 'info') {
    // Create and show notification
    const notification = document.createElement('div')
    notification.className = `notification notification-${type}`
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    setTimeout(() => notification.classList.add('show'), 100)
    setTimeout(() => {
      notification.classList.remove('show')
      setTimeout(() => document.body.removeChild(notification), 300)
    }, 3000)
  }

  handleBeforeUnload(event) {
    if (this.isDirty) {
      event.preventDefault()
      event.returnValue = 'You have unsaved changes. Are you sure you want to leave?'
    }
  }

  cleanup() {
    window.removeEventListener('beforeunload', this.handleBeforeUnload.bind(this))
  }

  // Save state for undo/redo
  saveState() {
    const state = this.hasCanvasTarget ? this.canvasTarget.innerHTML : ''
    this.history = this.history.slice(0, this.historyIndex + 1)
    this.history.push(state)
    this.historyIndex++

    if (this.history.length > 50) {
      this.history.shift()
      this.historyIndex--
    }
  }

  // Undo
  undo() {
    if (this.historyIndex > 0) {
      this.historyIndex--
      this.restoreState()
    }
  }

  // Redo
  redo() {
    if (this.historyIndex < this.history.length - 1) {
      this.historyIndex++
      this.restoreState()
    }
  }

  // Restore state
  restoreState() {
    if (this.hasCanvasTarget && this.history[this.historyIndex]) {
      this.canvasTarget.innerHTML = this.history[this.historyIndex]
      this.markDirty()
    }
  }
}
