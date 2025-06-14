class TemplateRenderer
  def initialize(template, contact)
    @template = template
    @contact = contact
  end

  def render
    @template.render_for_contact(@contact)
  end
end
