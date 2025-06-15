import { Controller } from "@hotwired/stimulus"
import { getComponentDefinition, validateComponent } from "../config/template_components"

export default class extends Controller {
  static targets = ["dropZone", "form", "nameField", "typeField", "bodyField", "subjectField", "descriptionField"]
  static values = { 
    templateType: String,
    autoSave: Boolean
  }

  connect() {
    this.components = []
    this.history = []
    this.historyIndex = -1
    this.templateTypeValue = "email"
    this.autoSaveValue = true
    
    this.initializeDropZone()
    this.setupAutoSave()
    this.loadFromLocalStorage()
  }

  initializeDropZone() {
    if (this.hasDropZoneTarget) {
      this.dropZoneTarget.addEventListener('dragover', this.handleDragOver.bind(this))
      this.dropZoneTarget.addEventListener('dragleave', this.handleDragLeave.bind(this))
      this.dropZoneTarget.addEventListener('drop', this.handleDrop.bind(this))
    }
  }

  setupAutoSave() {
    if (this.autoSaveValue) {
      setInterval(() => {
        this.saveToLocalStorage()
      }, 30000) // Auto-save every 30 seconds
    }
  }

  handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'copy'
    
    this.dropZoneTarget.classList.add('drag-over')
    
    // Add visual feedback
    this.dropZoneTarget.style.transform = 'scale(1.02)'
  }

  handleDragLeave(event) {
    // Only remove highlight if we're actually leaving the drop zone
    if (!this.dropZoneTarget.contains(event.relatedTarget)) {
      this.dropZoneTarget.classList.remove('drag-over')
      this.dropZoneTarget.style.transform = ''
    }
  }

  handleDrop(event) {
    event.preventDefault()
    
    this.dropZoneTarget.classList.remove('drag-over')
    this.dropZoneTarget.style.transform = ''
    
    const componentType = event.dataTransfer.getData('text/plain')
    
    if (componentType) {
      this.addComponent(componentType)
      this.saveState()
    }
  }

  addComponent(type, position = null) {
    const componentData = {
      id: this.generateId(),
      type: type,
      content: this.getDefaultContent(type),
      styles: this.getDefaultStyles(type),
      position: position || this.components.length
    }
    
    if (position !== null) {
      this.components.splice(position, 0, componentData)
    } else {
      this.components.push(componentData)
    }
    
    this.renderComponent(componentData)
    this.updateFormData()
    
    // Show success feedback
    this.showToast(`${type.charAt(0).toUpperCase() + type.slice(1)} component added`, 'success')
  }

  renderComponent(componentData) {
    const { type, content, styles } = componentData
    const definition = getComponentDefinition(type)
    
    if (!definition) {
      return this.renderUnknownComponent(type)
    }
    
    const wrapper = document.createElement('div')
    wrapper.className = 'component-wrapper mb-4 p-4 border border-gray-200 rounded-lg hover:border-purple-500 transition-all duration-200 group'
    wrapper.dataset.componentId = componentData.id
    wrapper.dataset.componentType = componentData.type
    
    // Make the drop zone a proper container if it's the first component
    if (this.dropZoneTarget.querySelector('svg')) {
      this.dropZoneTarget.innerHTML = ''
      this.dropZoneTarget.className = 'drop-zone p-4 min-h-96'
    }
    
    // Apply styles to wrapper
    if (styles) {
      Object.assign(wrapper.style, styles)
    }
    
    // Generate component HTML using the definition's render function
    const html = definition.render ? definition.render(content || definition.defaultContent) : this.generateComponentHTML(componentData)
    wrapper.innerHTML = html
    
    // Add component controls
    this.addComponentControls(wrapper, componentData)
    
    // Make component sortable
    this.makeComponentSortable(wrapper)
    
    this.dropZoneTarget.appendChild(wrapper)
  }
  
  renderUnknownComponent(type) {
    const wrapper = document.createElement('div')
    wrapper.className = 'component-wrapper mb-4 p-4 border border-red-300 rounded-lg bg-red-50'
    wrapper.innerHTML = `
      <div class="unknown-component p-4 bg-red-50 border border-red-200 rounded">
        <p class="text-red-600">Unknown component: ${type}</p>
        <p class="text-sm text-red-500">This component type is not defined in the template configuration.</p>
      </div>
    `
    return wrapper
  }

  renderComponentHTML(component) {
    const { type, id, data } = component
    
    // Common controls for all components
    const controls = `
      <div class="component-controls">
        <button class="edit-btn" data-action="click->template-canvas#editComponent" data-component-id="${id}">Edit</button>
        <button class="duplicate-btn" data-action="click->template-canvas#duplicateComponent" data-component-id="${id}">Duplicate</button>
        <button class="delete-btn" data-action="click->template-canvas#deleteComponent" data-component-id="${id}">Delete</button>
      </div>
    `
    
    switch(type) {
      // Email Components
      case 'header':
        return `
          <div class="component-item bg-blue-50 border-2 border-blue-200 p-4 rounded-lg" data-component-id="${id}">
            ${controls}
            <h2 class="text-xl font-bold text-blue-800">${data.title || 'Header Title'}</h2>
            <p class="text-blue-600">${data.subtitle || 'Header subtitle'}</p>
          </div>
        `
      case 'text':
        return `
          <div class="component-item bg-gray-50 border-2 border-gray-200 p-4 rounded-lg" data-component-id="${id}">
            ${controls}
            <p class="text-gray-800">${data.content || 'Your text content here...'}</p>
          </div>
        `
      case 'image':
        return `
          <div class="component-item bg-yellow-50 border-2 border-yellow-200 p-4 rounded-lg" data-component-id="${id}">
            ${controls}
            <div class="bg-yellow-100 h-32 rounded flex items-center justify-center">
              <span class="text-yellow-600">📷 ${data.alt || 'Image placeholder'}</span>
            </div>
            ${data.caption ? `<p class="text-sm text-gray-600 mt-2">${data.caption}</p>` : ''}
          </div>
        `
      case 'button':
        return `
          <div class="component-item bg-red-50 border-2 border-red-200 p-4 rounded-lg" data-component-id="${id}">
            ${controls}
            <button class="bg-red-500 text-white px-6 py-2 rounded hover:bg-red-600">
              ${data.text || 'Click Me'}
            </button>
          </div>
        `
      case 'footer':
        return `
          <div class="component-item bg-green-50 border-2 border-green-200 p-4 rounded-lg" data-component-id="${id}">
            ${controls}
            <div class="text-center text-green-800">
              <p>${data.content || 'Footer content'}</p>
              <p class="text-sm text-green-600">${data.copyright || '© 2024 Your Company'}</p>
            </div>
          </div>
        `
      case 'divider':
        return `
          <div class="component-item bg-gray-50 border-2 border-gray-200 p-4 rounded-lg" data-component-id="${id}">
            ${controls}
            <hr class="border-gray-400" style="${data.style || 'border-width: 1px;'}">
          </div>
        `
      case 'section':
        return `
          <div class="component-item bg-purple-50 border-2 border-purple-200 p-4 rounded-lg" data-component-id="${id}">
            ${controls}
            <div class="bg-purple-100 p-4 rounded">
              <h3 class="font-semibold text-purple-800">${data.title || 'Section Title'}</h3>
              <p class="text-purple-600">${data.content || 'Section content goes here...'}</p>
            </div>
          </div>
        `
      
      // Website Components
      case 'navbar':
        return `
          <div class="component-item bg-blue-50 border-2 border-blue-200 p-4 rounded-lg" data-component-id="${id}">
            ${controls}
            <nav class="bg-blue-600 text-white p-3 rounded">
              <div class="flex justify-between items-center">
                <span class="font-bold">${data.brand || 'Brand'}</span>
                <div class="space-x-4">
                  <span>Home</span>
                  <span>About</span>
                  <span>Contact</span>
                </div>
              </div>
            </nav>
          </div>
        `
      case 'hero':
        return `
          <div class="component-item bg-indigo-50 border-2 border-indigo-200 p-4 rounded-lg" data-component-id="${id}">
            ${controls}
            <div class="bg-indigo-600 text-white p-8 rounded text-center">
              <h1 class="text-3xl font-bold mb-4">${data.title || 'Hero Title'}</h1>
              <p class="text-xl mb-6">${data.subtitle || 'Hero subtitle'}</p>
              <button class="bg-white text-indigo-600 px-6 py-2 rounded">${data.cta || 'Get Started'}</button>
            </div>
          </div>
        `
      
      // Facebook Components
      case 'fb-post-header':
        return `
          <div class="component-item bg-blue-50 border-2 border-blue-200 p-4 rounded-lg" data-component-id="${id}">
            ${controls}
            <div class="flex items-center space-x-3 p-3 bg-white rounded border">
              <div class="w-10 h-10 bg-blue-500 rounded-full flex items-center justify-center text-white font-bold">
                ${(data.name || 'Page')[0]}
              </div>
              <div>
                <p class="font-semibold">${data.name || 'Page Name'}</p>
                <p class="text-sm text-gray-500">${data.time || '2 hours ago'} • 🌍</p>
              </div>
            </div>
          </div>
        `
      case 'fb-text':
        return `
          <div class="component-item bg-gray-50 border-2 border-gray-200 p-4 rounded-lg" data-component-id="${id}">
            ${controls}
            <div class="bg-white p-4 rounded border">
              <p class="text-gray-800">${data.content || 'What\'s on your mind?'}</p>
            </div>
          </div>
        `
      case 'fb-image':
        return `
          <div class="component-item bg-green-50 border-2 border-green-200 p-4 rounded-lg" data-component-id="${id}">
            ${controls}
            <div class="bg-white rounded border">
              <div class="bg-gray-200 h-48 flex items-center justify-center">
                <span class="text-gray-500">📷 ${data.alt || 'Facebook Image'}</span>
              </div>
            </div>
          </div>
        `
      case 'fb-cta-button':
        return `
          <div class="component-item bg-orange-50 border-2 border-orange-200 p-4 rounded-lg" data-component-id="${id}">
            ${controls}
            <div class="bg-white p-4 rounded border">
              <button class="bg-blue-600 text-white px-6 py-2 rounded font-semibold w-full">
                ${data.text || 'Learn More'}
              </button>
            </div>
          </div>
        `
      
      // Instagram Components
      case 'ig-square-post':
        return `
          <div class="component-item bg-purple-50 border-2 border-purple-200 p-4 rounded-lg" data-component-id="${id}">
            ${controls}
            <div class="bg-white rounded-lg border max-w-sm">
              <div class="bg-gradient-to-br from-purple-400 to-pink-400 h-64 flex items-center justify-center">
                <span class="text-white text-lg">📷 ${data.content || 'Instagram Post'}</span>
              </div>
              <div class="p-3">
                <p class="text-sm">${data.caption || 'Your caption here...'}</p>
              </div>
            </div>
          </div>
        `
      case 'ig-story':
        return `
          <div class="component-item bg-pink-50 border-2 border-pink-200 p-4 rounded-lg" data-component-id="${id}">
            ${controls}
            <div class="bg-white rounded-lg border max-w-xs">
              <div class="bg-gradient-to-br from-pink-400 to-purple-400 h-96 flex items-center justify-center rounded-lg">
                <span class="text-white text-lg">📱 ${data.content || 'Story'}</span>
              </div>
            </div>
          </div>
        `
      case 'ig-hashtags':
        return `
          <div class="component-item bg-cyan-50 border-2 border-cyan-200 p-4 rounded-lg" data-component-id="${id}">
            ${controls}
            <div class="bg-white p-3 rounded border">
              <p class="text-blue-600">${data.hashtags || '#instagram #social #marketing'}</p>
            </div>
          </div>
        `
      
      default:
        return `
          <div class="component-item bg-purple-50 border-2 border-purple-200 p-4 rounded-lg" data-component-id="${id}">
            ${controls}
            <p class="text-purple-800">${type} Component</p>
            <p class="text-sm text-purple-600">Component data: ${JSON.stringify(data)}</p>
          </div>
        `
    }
  }

  addComponentControls(wrapper, componentData) {
    const controls = document.createElement('div')
    controls.className = 'component-controls absolute top-2 right-2 flex space-x-1 opacity-0 group-hover:opacity-100 transition-opacity'
    
    // Edit button
    const editBtn = this.createControlButton('✏️', 'Edit component', () => {
      this.editComponent(componentData.id)
    })
    
    // Duplicate button
    const duplicateBtn = this.createControlButton('📋', 'Duplicate component', () => {
      this.duplicateComponent(componentData.id)
    })
    
    // Delete button
    const deleteBtn = this.createControlButton('🗑️', 'Delete component', () => {
      this.deleteComponent(componentData.id)
    })
    
    controls.appendChild(editBtn)
    controls.appendChild(duplicateBtn)
    controls.appendChild(deleteBtn)
    
    wrapper.style.position = 'relative'
    wrapper.appendChild(controls)
  }

  createControlButton(icon, title, onClick) {
    const button = document.createElement('button')
    button.className = 'w-8 h-8 bg-white border border-gray-300 rounded-lg text-sm hover:bg-gray-50 transition-colors shadow-sm'
    button.innerHTML = icon
    button.title = title
    button.onclick = onClick
    return button
  }

  makeComponentSortable(wrapper) {
    wrapper.draggable = true
    wrapper.addEventListener('dragstart', (e) => {
      e.dataTransfer.setData('text/component-id', wrapper.dataset.componentId)
      wrapper.style.opacity = '0.5'
    })
    
    wrapper.addEventListener('dragend', () => {
      wrapper.style.opacity = '1'
    })
    
    wrapper.addEventListener('dragover', (e) => {
      e.preventDefault()
      wrapper.classList.add('drag-over-component')
    })
    
    wrapper.addEventListener('dragleave', () => {
      wrapper.classList.remove('drag-over-component')
    })
    
    wrapper.addEventListener('drop', (e) => {
      e.preventDefault()
      wrapper.classList.remove('drag-over-component')
      
      const draggedId = e.dataTransfer.getData('text/component-id')
      if (draggedId && draggedId !== wrapper.dataset.componentId) {
        this.reorderComponents(draggedId, wrapper.dataset.componentId)
      }
    })
  }

  editComponent(componentId) {
    const component = this.components.find(c => c.id === componentId)
    if (component) {
      // Dispatch event to properties panel
      this.dispatch('componentSelected', { detail: { component: component } })
    }
  }

  duplicateComponent(componentId) {
    const component = this.components.find(c => c.id === componentId)
    if (component) {
      const duplicate = {
        ...component,
        id: this.generateId(),
        position: component.position + 1
      }
      
      this.components.splice(component.position + 1, 0, duplicate)
      this.renderComponent(duplicate)
      this.updateFormData()
      this.saveState()
      
      this.showToast('Component duplicated', 'success')
    }
  }

  deleteComponent(componentId) {
    const componentIndex = this.components.findIndex(c => c.id === componentId)
    if (componentIndex !== -1) {
      this.components.splice(componentIndex, 1)
      
      const wrapper = this.element.querySelector(`[data-component-id="${componentId}"]`)
      if (wrapper) {
        wrapper.remove()
      }
      
      this.updateFormData()
      this.saveState()
      
      this.showToast('Component deleted', 'info')
      
      // Show empty state if no components left
      if (this.components.length === 0) {
        this.showEmptyState()
      }
    }
  }

  reorderComponents(draggedId, targetId) {
    const draggedIndex = this.components.findIndex(c => c.id === draggedId)
    const targetIndex = this.components.findIndex(c => c.id === targetId)
    
    if (draggedIndex !== -1 && targetIndex !== -1) {
      const [draggedComponent] = this.components.splice(draggedIndex, 1)
      this.components.splice(targetIndex, 0, draggedComponent)
      
      this.rerenderAllComponents()
      this.updateFormData()
      this.saveState()
    }
  }

  rerenderAllComponents() {
    // Clear current components
    this.dropZoneTarget.innerHTML = ''
    
    // Re-render all components in order
    this.components.forEach(component => {
      this.renderComponent(component)
    })
    
    if (this.components.length === 0) {
      this.showEmptyState()
    }
  }

  showEmptyState() {
    this.dropZoneTarget.innerHTML = `
      <div class="max-w-sm mx-auto text-center">
        <svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path>
        </svg>
        <h3 class="text-lg font-semibold text-gray-900 mb-2">Start Building Your Template</h3>
        <p class="text-gray-600 mb-4">Drag components from the left panel to start creating your template</p>
        <div class="flex flex-wrap gap-2 justify-center">
          <span class="px-3 py-1 bg-purple-100 text-purple-800 text-xs font-medium rounded-full">Drag & Drop</span>
          <span class="px-3 py-1 bg-blue-100 text-blue-800 text-xs font-medium rounded-full">AI Powered</span>
          <span class="px-3 py-1 bg-green-100 text-green-800 text-xs font-medium rounded-full">Responsive</span>
        </div>
      </div>
    `
    this.dropZoneTarget.className = 'drop-zone p-8 rounded-xl border-2 border-dashed border-gray-300 text-center'
  }

  generateComponentHTML(componentData) {
    const components = {
      header: `<div class="bg-gradient-to-r from-purple-600 to-pink-600 text-white p-6 rounded-lg">
                <h1 class="text-2xl font-bold">${componentData.content.title || 'Header Title'}</h1>
                <p class="text-purple-100">${componentData.content.subtitle || 'Subtitle or description'}</p>
               </div>`,
      footer: `<div class="bg-gray-800 text-white p-6 rounded-lg text-center">
                <p>${componentData.content.text || '© 2024 Your Company. All rights reserved.'}</p>
               </div>`,
      section: `<div class="p-6 bg-gray-50 rounded-lg">
                 <h2 class="text-xl font-semibold mb-4">${componentData.content.title || 'Section Title'}</h2>
                 <p class="text-gray-600">${componentData.content.text || 'Section content goes here...'}</p>
                </div>`,
      text: `<div class="p-4">
              <h3 class="text-lg font-semibold mb-2">${componentData.content.title || 'Text Block'}</h3>
              <p class="text-gray-600">${componentData.content.text || 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.'}</p>
             </div>`,
      image: `<div class="text-center p-4">
               <div class="w-full h-48 bg-gray-200 rounded-lg flex items-center justify-center">
                 <svg class="w-12 h-12 text-gray-400" fill="currentColor" viewBox="0 0 24 24">
                   <path d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z"/>
                 </svg>
               </div>
               <p class="text-sm text-gray-500 mt-2">${componentData.content.caption || 'Image placeholder'}</p>
              </div>`,
      button: `<div class="text-center p-4">
                <button class="px-6 py-3 bg-gradient-to-r from-purple-600 to-pink-600 text-white font-semibold rounded-lg hover:from-purple-700 hover:to-pink-700 transition-all">
                  ${componentData.content.text || 'Call to Action'}
                </button>
               </div>`,
      video: `<div class="p-4">
               <div class="w-full h-64 bg-black rounded-lg flex items-center justify-center">
                 <svg class="w-16 h-16 text-white" fill="currentColor" viewBox="0 0 24 24">
                   <path d="M8 5v14l11-7z"/>
                 </svg>
               </div>
               <p class="text-sm text-gray-500 mt-2 text-center">${componentData.content.caption || 'Video placeholder'}</p>
              </div>`,
      form: `<div class="p-4 bg-white border border-gray-200 rounded-lg">
              <h3 class="text-lg font-semibold mb-4">${componentData.content.title || 'Contact Form'}</h3>
              <div class="space-y-3">
                <input type="text" placeholder="Name" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
                <input type="email" placeholder="Email" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
                <textarea placeholder="Message" rows="3" class="w-full px-3 py-2 border border-gray-300 rounded-lg"></textarea>
                <button class="w-full px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors">
                  ${componentData.content.buttonText || 'Submit'}
                </button>
              </div>
             </div>`,
      social: `<div class="flex justify-center space-x-4 p-4">
                <a href="#" class="w-10 h-10 bg-blue-600 text-white rounded-full flex items-center justify-center hover:bg-blue-700 transition-colors">f</a>
                <a href="#" class="w-10 h-10 bg-blue-400 text-white rounded-full flex items-center justify-center hover:bg-blue-500 transition-colors">t</a>
                <a href="#" class="w-10 h-10 bg-pink-600 text-white rounded-full flex items-center justify-center hover:bg-pink-700 transition-colors">i</a>
               </div>`
    }
    
    return components[componentData.type] || '<div class="p-4 text-center text-gray-500">Unknown component</div>'
  }

  getDefaultContent(type) {
    const definition = getComponentDefinition(type)
    return definition ? { ...definition.defaultContent } : { content: 'Default content' }
  }

  getDefaultStyles(type) {
    const definition = getComponentDefinition(type)
    return definition ? { ...definition.styles } : { padding: '10px' }
  }

  setTemplateType(type) {
    this.templateTypeValue = type
    if (this.hasTypeFieldTarget) {
      this.typeFieldTarget.value = type
    }
  }

  updateFormData() {
    if (this.hasBodyFieldTarget) {
      this.bodyFieldTarget.value = JSON.stringify({
        components: this.components,
        templateType: this.templateTypeValue,
        version: '1.0'
      })
    }
  }

  saveState() {
    const state = {
      components: this.components,
      templateType: this.templateTypeValue
    }
    
    this.history = this.history.slice(0, this.historyIndex + 1)
    this.history.push(JSON.parse(JSON.stringify(state)))
    this.historyIndex = this.history.length - 1
    
    // Limit history size
    if (this.history.length > 50) {
      this.history.shift()
      this.historyIndex--
    }
  }

  undo() {
    if (this.historyIndex > 0) {
      this.historyIndex--
      this.restoreState(this.history[this.historyIndex])
    }
  }

  redo() {
    if (this.historyIndex < this.history.length - 1) {
      this.historyIndex++
      this.restoreState(this.history[this.historyIndex])
    }
  }

  restoreState(state) {
    this.components = JSON.parse(JSON.stringify(state.components))
    this.templateTypeValue = state.templateType
    this.rerenderAllComponents()
    this.updateFormData()
  }

  saveToLocalStorage() {
    const data = {
      components: this.components,
      templateType: this.templateTypeValue,
      timestamp: Date.now()
    }
    
    localStorage.setItem('template_builder_draft', JSON.stringify(data))
  }

  loadFromLocalStorage() {
    const saved = localStorage.getItem('template_builder_draft')
    if (saved) {
      try {
        const data = JSON.parse(saved)
        // Only load if it's recent (within 24 hours)
        if (Date.now() - data.timestamp < 24 * 60 * 60 * 1000) {
          this.components = data.components || []
          this.templateTypeValue = data.templateType || 'email'
          
          if (this.components.length > 0) {
            this.rerenderAllComponents()
            this.showToast('Draft restored from previous session', 'info')
          }
        }
      } catch (error) {
        console.warn('Failed to load draft from localStorage:', error)
      }
    }
  }

  clearDraft() {
    localStorage.removeItem('template_builder_draft')
    this.components = []
    this.showEmptyState()
    this.updateFormData()
  }

  generateId() {
    return 'component_' + Math.random().toString(36).substr(2, 9)
  }

  showToast(message, type = 'info') {
    // Dispatch event for toast notification
    this.dispatch('showToast', { detail: { message, type } })
  }
}