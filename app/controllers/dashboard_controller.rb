class DashboardController < ApplicationController
  def index
    @campaigns_count = @current_account.campaigns.count
    @contacts_count = @current_account.contacts.count
    @recent_campaigns = @current_account.campaigns.recent.limit(5)
    @campaign_stats = calculate_campaign_stats
  end

  private

  def calculate_campaign_stats
    campaigns = @current_account.campaigns
    {
      total_sent: campaigns.joins(:campaign_contacts).where.not(campaign_contacts: { sent_at: nil }).count,
      total_opened: campaigns.joins(:campaign_contacts).where.not(campaign_contacts: { opened_at: nil }).count,
      total_clicked: campaigns.joins(:campaign_contacts).where.not(campaign_contacts: { clicked_at: nil }).count
    }
  end
end