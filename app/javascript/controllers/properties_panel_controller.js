import { Controller } from "@hotwired/stimulus"
import { getComponentDefinition } from "../config/template_components"

export default class extends Controller {
  static targets = ["panel", "componentName", "contentForm", "styleForm", "previewArea"]
  static values = { 
    selectedComponent: Object
  }

  connect() {
    this.selectedComponent = null
    this.setupEventListeners()
  }

  setupEventListeners() {
    // Listen for component selection from canvas
    this.element.addEventListener('template-canvas:componentSelected', (event) => {
      this.selectComponent(event.detail.component)
    })
  }

  selectComponent(component) {
    this.selectedComponent = component
    this.selectedComponentValue = component
    this.showPanel()
    this.renderComponentEditor()
  }

  showPanel() {
    if (this.hasPanelTarget) {
      this.panelTarget.classList.remove('translate-x-full')
      this.panelTarget.classList.add('translate-x-0')
    }
  }

  hidePanel() {
    if (this.hasPanelTarget) {
      this.panelTarget.classList.add('translate-x-full')
      this.panelTarget.classList.remove('translate-x-0')
    }
    this.selectedComponent = null
  }

  renderComponentEditor() {
    if (!this.selectedComponent) return

    // Update component name
    if (this.hasComponentNameTarget) {
      this.componentNameTarget.textContent = this.getComponentDisplayName(this.selectedComponent.type)
    }

    // Render content form
    this.renderContentForm()
    
    // Render style form
    this.renderStyleForm()
    
    // Update preview
    this.updatePreview()
  }

  renderContentForm() {
    if (!this.hasContentFormTarget) return

    const component = this.selectedComponent
    const contentFields = this.getContentFields(component.type)
    
    let formHTML = '<div class="space-y-4">'
    
    contentFields.forEach(field => {
      const value = component.content[field.key] || field.default || ''
      
      formHTML += `
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">${field.label}</label>
          ${this.renderFormField(field, value)}
        </div>
      `
    })
    
    formHTML += '</div>'
    this.contentFormTarget.innerHTML = formHTML
    
    // Add event listeners to form fields
    this.addContentFormListeners()
  }

  renderFormField(field, value) {
    switch (field.type) {
      case 'text':
        return `<input type="text" value="${value}" data-field="${field.key}" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent">`
      
      case 'textarea':
        return `<textarea data-field="${field.key}" rows="3" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent">${value}</textarea>`
      
      case 'url':
        return `<input type="url" value="${value}" data-field="${field.key}" placeholder="https://" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent">`
      
      case 'select':
        let options = field.options.map(opt => 
          `<option value="${opt.value}" ${opt.value === value ? 'selected' : ''}>${opt.label}</option>`
        ).join('')
        return `<select data-field="${field.key}" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent">${options}</select>`
      
      case 'color':
        return `
          <div class="flex space-x-2">
            <input type="color" value="${value}" data-field="${field.key}" class="w-12 h-10 border border-gray-300 rounded-lg">
            <input type="text" value="${value}" data-field="${field.key}-text" class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent">
          </div>
        `
      
      case 'number':
        return `<input type="number" value="${value}" data-field="${field.key}" min="${field.min || 0}" max="${field.max || 100}" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent">`
      
      default:
        return `<input type="text" value="${value}" data-field="${field.key}" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent">`
    }
  }

  renderStyleForm() {
    if (!this.hasStyleFormTarget) return

    const component = this.selectedComponent
    const styles = component.styles || {}
    
    const styleHTML = `
      <div class="space-y-4">
        <!-- Typography -->
        <div class="border-b border-gray-200 pb-4">
          <h4 class="text-sm font-semibold text-gray-900 mb-3">Typography</h4>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Font Size</label>
              <select data-style="fontSize" class="w-full px-2 py-1 text-sm border border-gray-300 rounded">
                <option value="0.75rem" ${styles.fontSize === '0.75rem' ? 'selected' : ''}>12px</option>
                <option value="0.875rem" ${styles.fontSize === '0.875rem' ? 'selected' : ''}>14px</option>
                <option value="1rem" ${styles.fontSize === '1rem' ? 'selected' : ''}>16px</option>
                <option value="1.125rem" ${styles.fontSize === '1.125rem' ? 'selected' : ''}>18px</option>
                <option value="1.25rem" ${styles.fontSize === '1.25rem' ? 'selected' : ''}>20px</option>
                <option value="1.5rem" ${styles.fontSize === '1.5rem' ? 'selected' : ''}>24px</option>
                <option value="2rem" ${styles.fontSize === '2rem' ? 'selected' : ''}>32px</option>
              </select>
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Font Weight</label>
              <select data-style="fontWeight" class="w-full px-2 py-1 text-sm border border-gray-300 rounded">
                <option value="300" ${styles.fontWeight === '300' ? 'selected' : ''}>Light</option>
                <option value="400" ${styles.fontWeight === '400' ? 'selected' : ''}>Normal</option>
                <option value="500" ${styles.fontWeight === '500' ? 'selected' : ''}>Medium</option>
                <option value="600" ${styles.fontWeight === '600' ? 'selected' : ''}>Semibold</option>
                <option value="700" ${styles.fontWeight === '700' ? 'selected' : ''}>Bold</option>
              </select>
            </div>
          </div>
          <div class="mt-3">
            <label class="block text-xs font-medium text-gray-700 mb-1">Text Color</label>
            <div class="flex space-x-2">
              <input type="color" value="${styles.textColor || '#374151'}" data-style="textColor" class="w-8 h-8 border border-gray-300 rounded">
              <input type="text" value="${styles.textColor || '#374151'}" data-style="textColor-text" class="flex-1 px-2 py-1 text-sm border border-gray-300 rounded">
            </div>
          </div>
        </div>

        <!-- Spacing -->
        <div class="border-b border-gray-200 pb-4">
          <h4 class="text-sm font-semibold text-gray-900 mb-3">Spacing</h4>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Padding</label>
              <input type="text" value="${styles.padding || '1rem'}" data-style="padding" placeholder="1rem" class="w-full px-2 py-1 text-sm border border-gray-300 rounded">
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Margin</label>
              <input type="text" value="${styles.margin || '0.5rem 0'}" data-style="margin" placeholder="0.5rem 0" class="w-full px-2 py-1 text-sm border border-gray-300 rounded">
            </div>
          </div>
        </div>

        <!-- Background -->
        <div class="border-b border-gray-200 pb-4">
          <h4 class="text-sm font-semibold text-gray-900 mb-3">Background</h4>
          <div>
            <label class="block text-xs font-medium text-gray-700 mb-1">Background Color</label>
            <div class="flex space-x-2">
              <input type="color" value="${styles.backgroundColor || '#ffffff'}" data-style="backgroundColor" class="w-8 h-8 border border-gray-300 rounded">
              <input type="text" value="${styles.backgroundColor || '#ffffff'}" data-style="backgroundColor-text" class="flex-1 px-2 py-1 text-sm border border-gray-300 rounded">
            </div>
          </div>
        </div>

        <!-- Border -->
        <div class="border-b border-gray-200 pb-4">
          <h4 class="text-sm font-semibold text-gray-900 mb-3">Border</h4>
          <div class="space-y-3">
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Border Width</label>
              <input type="text" value="${styles.borderWidth || '0'}" data-style="borderWidth" placeholder="1px" class="w-full px-2 py-1 text-sm border border-gray-300 rounded">
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Border Color</label>
              <div class="flex space-x-2">
                <input type="color" value="${styles.borderColor || '#e5e7eb'}" data-style="borderColor" class="w-8 h-8 border border-gray-300 rounded">
                <input type="text" value="${styles.borderColor || '#e5e7eb'}" data-style="borderColor-text" class="flex-1 px-2 py-1 text-sm border border-gray-300 rounded">
              </div>
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Border Radius</label>
              <input type="text" value="${styles.borderRadius || '0.5rem'}" data-style="borderRadius" placeholder="0.5rem" class="w-full px-2 py-1 text-sm border border-gray-300 rounded">
            </div>
          </div>
        </div>

        <!-- Layout -->
        <div>
          <h4 class="text-sm font-semibold text-gray-900 mb-3">Layout</h4>
          <div class="space-y-3">
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Text Align</label>
              <select data-style="textAlign" class="w-full px-2 py-1 text-sm border border-gray-300 rounded">
                <option value="left" ${styles.textAlign === 'left' ? 'selected' : ''}>Left</option>
                <option value="center" ${styles.textAlign === 'center' ? 'selected' : ''}>Center</option>
                <option value="right" ${styles.textAlign === 'right' ? 'selected' : ''}>Right</option>
                <option value="justify" ${styles.textAlign === 'justify' ? 'selected' : ''}>Justify</option>
              </select>
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Width</label>
              <input type="text" value="${styles.width || 'auto'}" data-style="width" placeholder="auto" class="w-full px-2 py-1 text-sm border border-gray-300 rounded">
            </div>
          </div>
        </div>
      </div>
    `
    
    this.styleFormTarget.innerHTML = styleHTML
    this.addStyleFormListeners()
  }

  addContentFormListeners() {
    const inputs = this.contentFormTarget.querySelectorAll('input, textarea, select')
    inputs.forEach(input => {
      input.addEventListener('input', (e) => {
        this.updateComponentContent(e.target.dataset.field, e.target.value)
      })
    })
  }

  addStyleFormListeners() {
    const inputs = this.styleFormTarget.querySelectorAll('input, select')
    inputs.forEach(input => {
      input.addEventListener('input', (e) => {
        const field = e.target.dataset.style
        if (field.endsWith('-text')) {
          // Handle color text input
          const colorField = field.replace('-text', '')
          this.updateComponentStyle(colorField, e.target.value)
          // Update color picker
          const colorPicker = this.styleFormTarget.querySelector(`[data-style="${colorField}"]`)
          if (colorPicker) colorPicker.value = e.target.value
        } else {
          this.updateComponentStyle(field, e.target.value)
          // Update text input for color fields
          const textInput = this.styleFormTarget.querySelector(`[data-style="${field}-text"]`)
          if (textInput) textInput.value = e.target.value
        }
      })
    })
  }

  updateComponentContent(field, value) {
    if (this.selectedComponent) {
      this.selectedComponent.content[field] = value
      this.updatePreview()
      this.notifyCanvasUpdate()
    }
  }

  updateComponentStyle(field, value) {
    if (this.selectedComponent) {
      this.selectedComponent.styles[field] = value
      this.updatePreview()
      this.notifyCanvasUpdate()
    }
  }

  updatePreview() {
    if (!this.hasPreviewAreaTarget || !this.selectedComponent) return

    // Generate preview HTML with current styles
    const previewHTML = this.generateStyledPreview(this.selectedComponent)
    this.previewAreaTarget.innerHTML = previewHTML
  }

  generateStyledPreview(component) {
    const styles = component.styles || {}
    const styleString = Object.entries(styles)
      .map(([key, value]) => `${this.camelToKebab(key)}: ${value}`)
      .join('; ')

    // Get base HTML and apply styles
    const baseHTML = this.getComponentHTML(component)
    return `<div style="${styleString}">${baseHTML}</div>`
  }

  getComponentHTML(component) {
    // Simplified version of component HTML for preview
    const content = component.content
    
    switch (component.type) {
      case 'header':
        return `<h1>${content.title || 'Header Title'}</h1><p>${content.subtitle || 'Subtitle'}</p>`
      case 'text':
        return `<h3>${content.title || 'Text Block'}</h3><p>${content.text || 'Sample text'}</p>`
      case 'button':
        return `<button>${content.text || 'Button'}</button>`
      case 'image':
        return `<div class="w-full h-32 bg-gray-200 flex items-center justify-center">📷</div><p>${content.caption || 'Image'}</p>`
      default:
        return `<div>Preview for ${component.type}</div>`
    }
  }

  notifyCanvasUpdate() {
    // Dispatch event to update canvas
    this.dispatch('componentUpdated', { 
      detail: { 
        component: this.selectedComponent 
      } 
    })
  }

  getContentFields(type) {
    const definition = getComponentDefinition(type)
    if (!definition || !definition.properties) {
      return [{ name: 'content', label: 'Content', type: 'text' }]
    }
    
    return Object.entries(definition.properties).map(([key, config]) => ({
      name: key,
      label: config.label || this.formatLabel(key),
      type: config.type || 'text',
      options: config.options || null
    }))
  }
  
  formatLabel(key) {
    return key.charAt(0).toUpperCase() + key.slice(1).replace(/([A-Z])/g, ' $1')
  }

  getComponentDisplayName(type) {
    const names = {
      header: 'Header',
      footer: 'Footer', 
      section: 'Section',
      text: 'Text Block',
      image: 'Image',
      button: 'Button',
      video: 'Video',
      form: 'Form',
      social: 'Social Links'
    }
    
    return names[type] || type.charAt(0).toUpperCase() + type.slice(1)
  }

  camelToKebab(str) {
    return str.replace(/([a-z0-9]|(?=[A-Z]))([A-Z])/g, '$1-$2').toLowerCase()
  }

  // Action methods
  resetStyles() {
    if (this.selectedComponent) {
      this.selectedComponent.styles = this.getDefaultStyles(this.selectedComponent.type)
      this.renderStyleForm()
      this.updatePreview()
      this.notifyCanvasUpdate()
    }
  }

  getDefaultStyles(type) {
    const definition = getComponentDefinition(type)
    if (definition && definition.styles) {
      return { ...definition.styles }
    }
    
    return {
      backgroundColor: 'transparent',
      textColor: '#374151',
      fontSize: '1rem',
      padding: '1rem',
      margin: '0.5rem 0',
      borderRadius: '0.375rem',
      textAlign: 'left',
      fontWeight: 'normal'
    }
  }
}