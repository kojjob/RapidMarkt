class TemplatesController < ApplicationController
  before_action :set_template, only: [ :show, :edit, :update, :destroy, :duplicate, :preview ]

  def index
    @templates = filter_templates(@current_account.templates)
    @public_templates = filter_templates(Template.public_templates) if params[:include_public]
    @categories = Template.categories.keys
    @design_systems = %w[modern classic minimal]
  end

  def marketplace
    @templates = filter_templates(Template.public_templates.active)
    @featured_templates = Template.public_templates.active.highest_rated.limit(6)
    @popular_templates = Template.public_templates.active.popular.limit(6)
    @free_templates = Template.public_templates.active.free.limit(10)
    @premium_templates = Template.public_templates.active.premium.limit(10)
    @categories = Template.categories.keys
    @design_systems = %w[modern classic minimal]
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
    sample_data = {
      "contact.first_name" => params[:first_name] || "John",
      "contact.last_name" => params[:last_name] || "Doe",
      "contact.email" => params[:email] || "john.doe@example.com"
    }

    @rendered_content = @template.render_preview(sample_data: sample_data)

    respond_to do |format|
      format.html { render layout: false }
      format.json { render json: @rendered_content }
    end
  end

  def use_template
    source_template = Template.find(params[:id])
    
    # Check if template is accessible (public or belongs to account)
    unless source_template.public? || source_template.account == @current_account
      redirect_to templates_path, alert: "Template not accessible."
      return
    end

    # Create a copy for the current account
    @template = source_template.duplicate
    @template.account = @current_account
    @template.user = current_user
    @template.name = "#{source_template.name} (Copy)"
    
    if @template.save
      # Increment usage count on source template
      source_template.increment_usage! if source_template.public?
      
      redirect_to edit_template_path(@template), notice: "Template copied successfully!"
    else
      redirect_to templates_path, alert: "Failed to copy template."
    end
  end

  def rate
    rating = params[:rating].to_i
    
    if rating.between?(1, 5)
      @template.add_rating(rating)
      render json: { success: true, new_rating: @template.rating }
    else
      render json: { success: false, error: "Invalid rating" }, status: :bad_request
    end
  end

  private

  def filter_templates(base_scope)
    templates = base_scope.order(created_at: :desc)

    # Filter by category
    if params[:category].present?
      templates = templates.where(template_type: params[:category])
    end

    # Filter by status
    if params[:status].present?
      templates = templates.where(status: params[:status])
    end

    # Filter by design system
    if params[:design_system].present?
      templates = templates.by_design_system(params[:design_system])
    end

    # Filter by tags
    if params[:tags].present?
      tag_list = params[:tags].split(',').map(&:strip)
      templates = templates.by_tags(tag_list)
    end

    # Search
    if params[:search].present?
      templates = templates.search(params[:search])
    end

    # Filter by premium/free
    case params[:pricing]
    when 'free'
      templates = templates.free
    when 'premium'
      templates = templates.premium
    end

    # Add pagination
    templates.page(params[:page]).per(12)
  end

  def set_template
    @template = @current_account.templates.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to templates_path, alert: "Template not found or you do not have permission to access it."
  end

  def template_params
    params.require(:template).permit(
      :name, :subject, :body, :template_type, :status, :description,
      :design_system, :is_public, :is_premium,
      color_scheme: {}, variables: {}, tags: []
    )
  end
end
