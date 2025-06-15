import { Controller } from "@hotwired/stimulus"
import { TEMPLATE_TYPES, getTemplateConfig, getComponentsForTemplate } from "../config/template_components"

export default class extends Controller {
  static targets = ["typeCard"]
  static values = { selectedType: String }

  get templateConfigs() {
    return TEMPLATE_TYPES
  }

  connect() {
    this.selectedType = "email" // Default selection
    this.updateSelection()
  }

  selectType(event) {
    const card = event.currentTarget
    const type = card.dataset.type
    
    this.selectedType = type
    this.updateSelection()
    this.updateComponentPalette(type)
    this.updateCanvasForType(type)
    
    // Dispatch custom event for other controllers
    this.dispatch("typeChanged", { detail: { type: type } })
  }

  updateSelection() {
    // Remove selection from all cards
    this.element.querySelectorAll('.template-type-card').forEach(card => {
      card.classList.remove('ring-4', 'ring-white', 'ring-opacity-60')
      card.style.transform = ''
    })
    
    // Add selection to current card
    const selectedCard = this.element.querySelector(`[data-type="${this.selectedType}"]`)
    if (selectedCard) {
      selectedCard.classList.add('ring-4', 'ring-white', 'ring-opacity-60')
      selectedCard.style.transform = 'translateY(-5px) scale(1.02)'
    }
  }

  updateComponentPalette(type) {
    const config = getTemplateConfig(type)
    if (!config) return
    
    const components = getComponentsForTemplate(type)
    
    // Dispatch event to component palette controller
    const event = new CustomEvent('template:changed', {
      detail: { 
        type: type,
        components: components,
        config: config
      }
    })
    
    document.dispatchEvent(event)
  }

  updateCanvasForType(type) {
    const canvas = document.querySelector('[data-controller="template-canvas"]')
    if (canvas) {
      const controller = this.application.getControllerForElementAndIdentifier(canvas, "template-canvas")
      if (controller && controller.setTemplateType) {
        controller.setTemplateType(type)
      }
    }
  }
}