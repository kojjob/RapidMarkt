class CampaignsController < ApplicationController
  before_action :set_campaign, only: [:show, :edit, :update, :destroy, :send_campaign, :preview]

  def index
    @campaigns = @current_account.campaigns.includes(:template)
                                .order(created_at: :desc)
                                .page(params[:page])
  end

  def show
    @campaign_stats = calculate_campaign_stats(@campaign)
    @recent_activities = @campaign.campaign_contacts
                                  .includes(:contact)
                                  .where.not(sent_at: nil)
                                  .order(sent_at: :desc)
                                  .limit(10)
  end

  def new
    @campaign = @current_account.campaigns.build
    @templates = @current_account.templates.active
  end

  def create
    @campaign = @current_account.campaigns.build(campaign_params)
    @campaign.user = current_user

    if @campaign.save
      redirect_to @campaign, notice: 'Campaign was successfully created.'
    else
      @templates = @current_account.templates.active
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @templates = @current_account.templates.active
  end

  def update
    if @campaign.update(campaign_params)
      redirect_to @campaign, notice: 'Campaign was successfully updated.'
    else
      @templates = @current_account.templates.active
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @campaign.destroy
    redirect_to campaigns_url, notice: 'Campaign was successfully deleted.'
  end

  def preview
    @contact = @current_account.contacts.first || Contact.new(first_name: 'John', last_name: 'Doe', email: 'john@example.com')
    render layout: false
  end

  def send_campaign
    if @campaign.can_be_sent?
      # Queue the campaign for sending via background job
      CampaignSenderJob.perform_later(@campaign.id)
      
      redirect_to @campaign, notice: 'Campaign is being sent! You will be notified when complete.'
    else
      redirect_to @campaign, alert: 'Campaign cannot be sent in its current state.'
    end
  end

  private

  def set_campaign
    @campaign = @current_account.campaigns.find(params[:id])
  end

  def campaign_params
    params.require(:campaign).permit(:name, :subject, :template_id, :scheduled_at, :status)
  end

  def calculate_campaign_stats(campaign)
    campaign_contacts = campaign.campaign_contacts
    total_sent = campaign_contacts.where.not(sent_at: nil).count
    total_opened = campaign_contacts.where.not(opened_at: nil).count
    total_clicked = campaign_contacts.where.not(clicked_at: nil).count

    {
      total_sent: total_sent,
      total_opened: total_opened,
      total_clicked: total_clicked,
      open_rate: total_sent > 0 ? (total_opened.to_f / total_sent * 100).round(2) : 0,
      click_rate: total_sent > 0 ? (total_clicked.to_f / total_sent * 100).round(2) : 0
    }
  end
end