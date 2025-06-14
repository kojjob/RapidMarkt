class TemplatesController < ApplicationController
  before_action :set_template, only: [ :show, :edit, :update, :destroy, :duplicate, :preview ]

  def index
    @templates = @current_account.templates
                                .order(created_at: :desc)
                                .page(params[:page])

    # Filter by category
    if params[:category].present?
      @templates = @templates.where(template_type: params[:category])
    end

    # Filter by status
    if params[:status].present?
      @templates = @templates.where(status: params[:status])
    end

    @categories = Template.categories.keys
  end

  def show
    @usage_count = @template.campaigns.count
  end

  def new
    @template = @current_account.templates.build
    @template.template_type = params[:category] if params[:category].present?
  end

  def create
    @template = @current_account.templates.build(template_params)
    @template.user = current_user

    if @template.save
      redirect_to @template, notice: "Template was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @template.update(template_params)
      redirect_to @template, notice: "Template was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @template.campaigns.exists?
      redirect_to @template, alert: "Cannot delete template that is being used by campaigns."
    else
      @template.destroy
      redirect_to templates_url, notice: "Template was successfully deleted."
    end
  end

  def duplicate
    @new_template = @template.dup
    @new_template.name = "#{@template.name} (Copy)"
    @new_template.user = current_user

    if @new_template.save
      redirect_to edit_template_path(@new_template), notice: "Template was successfully duplicated."
    else
      redirect_to @template, alert: "Failed to duplicate template."
    end
  end

  def preview
    @contact = Contact.new(first_name: "John", last_name: "Doe", email: "john@example.com")
    @rendered_content = TemplateRenderer.new(@template, @contact).render
    render layout: false
  end

  private

  def set_template
    @template = @current_account.templates.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to templates_path, alert: "Template not found or you do not have permission to access it."
  end

  def template_params
    params.require(:template).permit(:name, :subject, :body, :template_type, :status)
  end
end
