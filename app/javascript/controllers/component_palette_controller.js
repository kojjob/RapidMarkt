import { Controller } from "@hotwired/stimulus"
import { getCategoriesForTemplate, getComponentDefinition } from "../config/template_components"

export default class extends Controller {
  static targets = ["search", "items", "categories"]
  
  connect() {
    this.currentTemplateType = 'email' // Default
    this.initializeDragAndDrop()
    this.setupSearch()
    this.setupTemplateChangeListener()
  }
  
  setupTemplateChangeListener() {
    document.addEventListener('template:changed', (event) => {
      this.updateForTemplateType(event.detail)
    })
  }

  initializeDragAndDrop() {
    const dragItems = this.element.querySelectorAll('.drag-item')
    
    dragItems.forEach(item => {
      item.addEventListener('dragstart', this.handleDragStart.bind(this))
      item.addEventListener('dragend', this.handleDragEnd.bind(this))
    })
  }

  setupSearch() {
    const searchInput = this.element.querySelector('input[type="text"]')
    if (searchInput) {
      searchInput.addEventListener('input', this.handleSearch.bind(this))
    }
  }

  handleDragStart(event) {
    const componentType = event.target.dataset.component
    event.dataTransfer.setData('text/plain', componentType)
    event.dataTransfer.effectAllowed = 'copy'
    
    // Visual feedback
    event.target.style.opacity = '0.5'
    event.target.style.transform = 'scale(0.95)'
    
    // Add dragging class to body for global styling
    document.body.classList.add('dragging')
    
    // Highlight drop zones
    this.highlightDropZones(true)
  }

  handleDragEnd(event) {
    // Reset visual feedback
    event.target.style.opacity = '1'
    event.target.style.transform = ''
    
    // Remove dragging class
    document.body.classList.remove('dragging')
    
    // Remove drop zone highlights
    this.highlightDropZones(false)
  }

  highlightDropZones(highlight) {
    const dropZones = document.querySelectorAll('.drop-zone, [data-droppable="true"]')
    dropZones.forEach(zone => {
      if (highlight) {
        zone.classList.add('drop-zone-highlighted')
      } else {
        zone.classList.remove('drop-zone-highlighted')
      }
    })
  }

  handleSearch(event) {
    const query = event.target.value.toLowerCase()
    const components = this.element.querySelectorAll('.drag-item')
    
    components.forEach(component => {
      const text = component.textContent.toLowerCase()
      const shouldShow = text.includes(query)
      
      component.style.display = shouldShow ? 'block' : 'none'
      
      // Also hide/show parent category if no components are visible
      const category = component.closest('div').parentElement
      const visibleComponents = category.querySelectorAll('.drag-item[style*="block"], .drag-item:not([style*="none"])')
      
      if (query && visibleComponents.length === 0) {
        category.style.display = 'none'
      } else {
        category.style.display = 'block'
      }
    })
  }

  updateForTemplateType(detail) {
    this.currentTemplateType = detail.type
    this.renderComponentPalette(detail.config)
    this.initializeDragAndDrop()
  }
  
  renderComponentPalette(templateConfig) {
    const categories = getCategoriesForTemplate(this.currentTemplateType)
    const paletteHTML = this.generatePaletteHTML(categories)
    
    if (this.hasCategoriesTarget) {
      this.categoriesTarget.innerHTML = paletteHTML
    }
  }
  
  generatePaletteHTML(categories) {
    return Object.entries(categories).map(([categoryKey, category]) => {
      const componentsHTML = category.components.map(componentType => {
        const definition = getComponentDefinition(componentType)
        if (!definition) return ''

        return `
          <div class="drag-item p-4 bg-white/80 backdrop-blur-sm rounded-2xl border-none cursor-move hover:shadow-xl hover:bg-white transition-all duration-300 transform hover:scale-105"
               draggable="true"
               data-component="${componentType}"
               data-component-name="${definition.name}"
               role="button"
               tabindex="0"
               aria-label="Drag ${definition.name} component to canvas">
            <div class="flex items-center space-x-3">
              <div class="w-6 h-6 rounded-xl shadow-lg" style="background: linear-gradient(135deg, ${definition.color}, ${definition.color}dd)"></div>
              <span class="text-sm font-semibold text-gray-800">${definition.name}</span>
            </div>
          </div>
        `
      }).join('')

      return `
        <div class="component-category mb-8" data-template-type="${this.currentTemplateType}">
          <div class="mb-4">
            <h4 class="text-lg font-bold text-gray-900 mb-2 flex items-center">
              <div class="w-6 h-6 bg-gradient-to-br from-purple-100 to-pink-100 rounded-xl flex items-center justify-center mr-2">
                <div class="w-2 h-2 bg-purple-500 rounded-full"></div>
              </div>
              ${category.name}
            </h4>
            <p class="text-sm text-gray-600 font-medium">Drag components to your canvas</p>
          </div>
          <div class="space-y-3">
            ${componentsHTML}
          </div>
        </div>
      `
    }).join('')
  }

  filterComponents(allowedComponents) {
    // This method is kept for search functionality
    const items = this.itemsTarget.querySelectorAll('.drag-item')
    items.forEach(item => {
      const componentType = item.dataset.component
      if (allowedComponents.includes(componentType)) {
        item.style.display = 'block'
      } else {
        item.style.display = 'none'
      }
    })
  }

  hideEmptyCategories() {
    const categories = this.element.querySelectorAll('div > h4')
    
    categories.forEach(categoryHeader => {
      const category = categoryHeader.parentElement
      const visibleComponents = category.querySelectorAll('.drag-item[style*="block"], .drag-item:not([style*="none"])')
      
      if (visibleComponents.length === 0) {
        category.style.display = 'none'
      } else {
        category.style.display = 'block'
      }
    })
  }
}