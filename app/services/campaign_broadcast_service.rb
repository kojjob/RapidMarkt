class CampaignBroadcastService
  def self.broadcast_status_change(campaign)
    new(campaign).broadcast_status_change
  end

  def self.broadcast_new_activity(campaign_contact)
    new(campaign_contact.campaign).broadcast_new_activity(campaign_contact)
  end

  def self.broadcast_dashboard_update(account)
    new(nil, account).broadcast_dashboard_update
  end

  def initialize(campaign, account = nil)
    @campaign = campaign
    @account = account || campaign&.account
  end

  def broadcast_status_change
    return unless @campaign && @account

    ActionCable.server.broadcast(
      "campaign_dashboard_#{@account.id}",
      {
        type: "campaign_status_change",
        data: {
          id: @campaign.id,
          name: @campaign.name,
          status: @campaign.status,
          updated_at: @campaign.updated_at.iso8601
        }
      }
    )

    Rails.logger.info "Broadcasted status change for campaign #{@campaign.id} to account #{@account.id}"
  end

  def broadcast_new_activity(campaign_contact)
    return unless @campaign && @account && campaign_contact

    ActionCable.server.broadcast(
      "campaign_dashboard_#{@account.id}",
      {
        type: "new_activity",
        data: {
          id: campaign_contact.id,
          contact_email: campaign_contact.contact.email,
          campaign_name: @campaign.name,
          campaign_id: @campaign.id,
          action: determine_action(campaign_contact),
          timestamp: (campaign_contact.opened_at || campaign_contact.sent_at).iso8601
        }
      }
    )

    Rails.logger.info "Broadcasted new activity for campaign #{@campaign.id} to account #{@account.id}"
  end

  def broadcast_dashboard_update
    return unless @account

    dashboard_data = calculate_dashboard_data

    ActionCable.server.broadcast(
      "campaign_dashboard_#{@account.id}",
      {
        type: "dashboard_update",
        data: dashboard_data
      }
    )

    Rails.logger.info "Broadcasted dashboard update to account #{@account.id}"
  end

  private

  def determine_action(campaign_contact)
    return "clicked" if campaign_contact.clicked_at.present?
    return "opened" if campaign_contact.opened_at.present?
    return "sent" if campaign_contact.sent_at.present?
    "unknown"
  end

  def calculate_dashboard_data
    # Total campaigns
    total_campaigns = @account.campaigns.count

    # Active campaigns
    active_campaigns = @account.campaigns.active.count

    # Total recipients
    total_recipients = @account.campaigns.joins(:campaign_contacts)
                              .where.not(campaign_contacts: { sent_at: nil })
                              .count

    # Calculate average open rate
    sent_campaigns = @account.campaigns.sent.where.not(open_rate: nil)
    average_open_rate = sent_campaigns.any? ? sent_campaigns.average(:open_rate) : 0

    # Recent activities
    recent_activities = @account.campaigns
                               .joins(:campaign_contacts)
                               .includes(campaign_contacts: :contact)
                               .where.not(campaign_contacts: { opened_at: nil })
                               .order("campaign_contacts.opened_at DESC")
                               .limit(10)
                               .map(&:campaign_contacts)
                               .flatten
                               .select { |cc| cc.opened_at.present? }
                               .sort_by(&:opened_at)
                               .reverse
                               .first(10)

    # Performance data for charts
    performance_data = calculate_performance_data
    status_distribution = calculate_status_distribution

    {
      total_campaigns: total_campaigns,
      active_campaigns: active_campaigns,
      total_recipients: total_recipients,
      average_open_rate: average_open_rate.to_f.round(1),
      performance_data: performance_data,
      status_distribution: status_distribution,
      recent_activities: recent_activities.map do |activity|
        {
          id: activity.id,
          contact_email: activity.contact.email,
          campaign_name: activity.campaign.name,
          action: activity.opened_at ? "opened" : "sent",
          timestamp: activity.opened_at || activity.sent_at,
          time_ago: time_ago_in_words(activity.opened_at || activity.sent_at)
        }
      end,
      updated_at: Time.current.iso8601
    }
  end

  def calculate_performance_data
    # Get campaigns from the last 30 days
    campaigns = @account.campaigns.sent
                        .where(sent_at: 30.days.ago..Time.current)
                        .order(:sent_at)

    performance_data = campaigns.map do |campaign|
      {
        date: campaign.sent_at.strftime("%Y-%m-%d"),
        campaign_name: campaign.name,
        open_rate: campaign.open_rate || 0,
        click_rate: campaign.click_rate || 0,
        recipients: campaign.campaign_contacts.where.not(sent_at: nil).count
      }
    end

    # Group by date and calculate averages
    grouped_data = performance_data.group_by { |d| d[:date] }

    grouped_data.map do |date, campaigns_data|
      {
        date: date,
        avg_open_rate: campaigns_data.sum { |c| c[:open_rate] } / campaigns_data.size.to_f,
        avg_click_rate: campaigns_data.sum { |c| c[:click_rate] } / campaigns_data.size.to_f,
        total_recipients: campaigns_data.sum { |c| c[:recipients] }
      }
    end.sort_by { |d| d[:date] }
  end

  def calculate_status_distribution
    @account.campaigns.group(:status).count
  end

  def time_ago_in_words(time)
    return "" unless time

    distance = Time.current - time

    case distance
    when 0..59
      "#{distance.to_i} seconds"
    when 60..3599
      "#{(distance / 60).to_i} minutes"
    when 3600..86399
      "#{(distance / 3600).to_i} hours"
    else
      "#{(distance / 86400).to_i} days"
    end
  end
end
