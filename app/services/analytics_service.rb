class AnalyticsService
  def initialize(account)
    @account = account
  end

  def overview_stats(date_range = nil)
    campaigns = filter_by_date_range(@account.campaigns, date_range)
    contacts = filter_by_date_range(@account.contacts, date_range)

    {
      total_campaigns: campaigns.count,
      emails_sent: calculate_emails_sent(campaigns),
      average_open_rate: calculate_average_open_rate(campaigns),
      total_contacts: contacts.count
    }
  end

  def campaign_performance(date_range = nil)
    campaigns = filter_by_date_range(@account.campaigns.sent, date_range)

    campaigns.map do |campaign|
      {
        id: campaign.id,
        name: campaign.name,
        subject: campaign.subject,
        sent_at: campaign.sent_at,
        emails_sent: campaign.campaign_contacts.count,
        opens: campaign.campaign_contacts.where.not(opened_at: nil).count,
        clicks: campaign.campaign_contacts.where.not(clicked_at: nil).count,
        open_rate: campaign.open_rate || 0,
        click_rate: campaign.click_rate || 0
      }
    end
  end

  def contact_growth(date_range = nil)
    contacts = @account.contacts

    if date_range
      start_date, end_date = parse_date_range(date_range)
      contacts = contacts.where(created_at: start_date..end_date)
    end

    {
      new_contacts: contacts.count,
      subscribed: contacts.where(status: "subscribed").count,
      unsubscribed: contacts.where(status: "unsubscribed").count,
      total_unsubscribed: @account.contacts.where(status: "unsubscribed").count
    }
  end

  def engagement_trends(date_range = nil)
    campaigns = filter_by_date_range(@account.campaigns.sent, date_range)

    # Group by week for trend analysis
    trends = campaigns.group_by { |c| c.sent_at&.beginning_of_week }
                     .transform_values do |week_campaigns|
                       {
                         campaigns_sent: week_campaigns.count,
                         avg_open_rate: week_campaigns.sum(&:open_rate) / week_campaigns.count.to_f,
                         avg_click_rate: week_campaigns.sum(&:click_rate) / week_campaigns.count.to_f
                       }
                     end

    trends.sort_by { |date, _| date || Time.current }.to_h
  end

  def export_data(format = "csv", date_range = nil)
    case format.downcase
    when "csv"
      export_csv(date_range)
    when "pdf"
      export_pdf(date_range)
    else
      raise ArgumentError, "Unsupported format: #{format}"
    end
  end

  private

  def filter_by_date_range(relation, date_range)
    return relation unless date_range

    start_date, end_date = parse_date_range(date_range)
    relation.where(created_at: start_date..end_date)
  end

  def parse_date_range(date_range)
    case date_range
    when "last_7_days"
      [ 7.days.ago.beginning_of_day, Time.current.end_of_day ]
    when "last_30_days"
      [ 30.days.ago.beginning_of_day, Time.current.end_of_day ]
    when "last_90_days"
      [ 90.days.ago.beginning_of_day, Time.current.end_of_day ]
    when "this_month"
      [ Time.current.beginning_of_month, Time.current.end_of_month ]
    when "last_month"
      [ 1.month.ago.beginning_of_month, 1.month.ago.end_of_month ]
    when Hash
      [ Date.parse(date_range[:start_date]), Date.parse(date_range[:end_date]) ]
    else
      [ 1.year.ago.beginning_of_day, Time.current.end_of_day ]
    end
  end

  def calculate_emails_sent(campaigns)
    campaigns.joins(:campaign_contacts).count
  end

  def calculate_average_open_rate(campaigns)
    sent_campaigns = campaigns.where(status: "sent")
    return 0 if sent_campaigns.empty?

    total_rate = sent_campaigns.sum(:open_rate)
    (total_rate / sent_campaigns.count).round(2)
  end

  def export_csv(date_range)
    require "csv"

    campaigns = filter_by_date_range(@account.campaigns.sent, date_range)

    CSV.generate(headers: true) do |csv|
      csv << [ "Campaign Name", "Subject", "Sent At", "Emails Sent", "Opens", "Clicks", "Open Rate", "Click Rate" ]

      campaigns.each do |campaign|
        csv << [
          campaign.name,
          campaign.subject,
          campaign.sent_at,
          campaign.campaign_contacts.count,
          campaign.campaign_contacts.where.not(opened_at: nil).count,
          campaign.campaign_contacts.where.not(clicked_at: nil).count,
          "#{campaign.open_rate}%",
          "#{campaign.click_rate}%"
        ]
      end
    end
  end

  def export_pdf(date_range)
    # This would require a PDF generation library like Prawn
    # For now, return a placeholder
    "PDF export functionality requires additional setup"
  end
end
