class BrandVoicesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_brand_voice, only: [ :show, :edit, :update, :destroy ]
  before_action :ensure_account_access

  def index
    @brand_voices = current_user.account.brand_voices.includes(:account)
    @brand_voices = @brand_voices.by_tone(params[:tone]) if params[:tone].present?
  end

  def show
    @sample_content = "Hello! Thank you for your interest in our services. We're excited to help you achieve your goals."
    @voice_analysis = BrandVoiceService.new(@brand_voice).analyze_content_compatibility(@sample_content)
  end

  def new
    @brand_voice = current_user.account.brand_voices.build
    set_form_data
  end

  def create
    @brand_voice = current_user.account.brand_voices.build(brand_voice_params)

    if @brand_voice.save
      redirect_to @brand_voice, notice: "Brand voice was successfully created."
    else
      set_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    set_form_data
  end

  def update
    if @brand_voice.update(brand_voice_params)
      redirect_to @brand_voice, notice: "Brand voice was successfully updated."
    else
      set_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @brand_voice.destroy
    redirect_to brand_voices_url, notice: "Brand voice was successfully deleted."
  end

  # AJAX endpoint for testing voice on content
  def test_voice
    @brand_voice = current_user.account.brand_voices.find(params[:id])
    content = params[:content]

    if content.present?
      service = BrandVoiceService.new(@brand_voice)
      @transformed_content = service.apply_voice(content)
      @analysis = service.analyze_content_compatibility(content)

      render json: {
        original: content,
        transformed: @transformed_content,
        analysis: @analysis
      }
    else
      render json: { error: "Content is required" }, status: :bad_request
    end
  end

  private

  def set_brand_voice
    @brand_voice = current_user.account.brand_voices.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to brand_voices_path, alert: "Brand voice not found."
  end

  def ensure_account_access
    redirect_to root_path, alert: "Access denied." unless current_user.account
  end

  def brand_voice_params
    params.require(:brand_voice).permit(
      :name, :tone, :description,
      personality_traits: [],
      vocabulary_preferences: [
        { preferred_words: [ :from, :to ] },
        { avoid_words: [] },
        :emoji_usage
      ],
      writing_style_rules: [
        :type, :preference, :style, :structure
      ]
    )
  end

  def set_form_data
    @tone_options = BrandVoice.tones.keys.map { |tone| [ tone.humanize, tone ] }
    @personality_traits_options = [
      [ "Enthusiastic", "enthusiastic" ],
      [ "Helpful", "helpful" ],
      [ "Expert", "expert" ],
      [ "Approachable", "approachable" ],
      [ "Confident", "confident" ],
      [ "Empathetic", "empathetic" ],
      [ "Professional", "professional" ],
      [ "Creative", "creative" ]
    ]
    @emoji_usage_options = [
      [ "None", "none" ],
      [ "Low", "low" ],
      [ "Moderate", "moderate" ],
      [ "High", "high" ]
    ]
  end
end
