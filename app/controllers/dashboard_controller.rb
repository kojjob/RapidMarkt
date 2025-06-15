class DashboardController < ApplicationController
  def index
    # Check if user needs onboarding
    @onboarding_progress = current_user.onboarding_progress
    if @onboarding_progress && !@onboarding_progress.completed?
      redirect_to onboarding_path and return
    end

    # Core metrics for indie users
    @overview_stats = calculate_overview_stats
    @recent_activity = get_recent_activity
    @quick_actions = get_quick_actions
    @performance_metrics = calculate_performance_metrics
    @upcoming_tasks = get_upcoming_tasks
    @growth_insights = calculate_growth_insights
    @template_recommendations = get_template_recommendations
    @recent_campaigns = get_recent_campaigns
    
    # Real-time data for live updates
    @realtime_stats = {
      active_campaigns: @current_account.campaigns.where(status: 'sending').count,
      recent_opens: recent_engagement_count('opened_at'),
      recent_clicks: recent_engagement_count('clicked_at'),
      online_team_members: @current_account.users.joins(:user_sessions)
                                           .where(user_sessions: { active: true })
                                           .where('user_sessions.last_activity_at > ?', 15.minutes.ago)
                                           .distinct.count
    }
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          overview: @overview_stats,
          activity: @recent_activity,
          performance: @performance_metrics,
          realtime: @realtime_stats,
          insights: @growth_insights
        }
      end
    end
  end

  private

  def calculate_overview_stats
    campaigns = @current_account.campaigns
    contacts = @current_account.contacts
    
    # This month's data
    this_month = Time.current.beginning_of_month..Time.current
    last_month = 1.month.ago.beginning_of_month..1.month.ago.end_of_month
    
    this_month_campaigns = campaigns.where(created_at: this_month).count
    last_month_campaigns = campaigns.where(created_at: last_month).count
    
    this_month_contacts = contacts.where(created_at: this_month).count
    last_month_contacts = contacts.where(created_at: last_month).count
    
    # Email performance
    campaign_contacts = CampaignContact.joins(:campaign)
                                     .where(campaigns: { account: @current_account })

    total_sent = campaign_contacts.where.not('campaign_contacts.sent_at' => nil).count
    total_opened = campaign_contacts.where.not(opened_at: nil).count
    total_clicked = campaign_contacts.where.not(clicked_at: nil).count
    
    {
      campaigns: {
        total: campaigns.count,
        this_month: this_month_campaigns,
        growth: calculate_growth_percentage(last_month_campaigns, this_month_campaigns),
        draft: campaigns.where(status: 'draft').count,
        sent: campaigns.where(status: 'sent').count,
        active: campaigns.where(status: ['sending', 'scheduled']).count
      },
      contacts: {
        total: contacts.count,
        this_month: this_month_contacts,
        growth: calculate_growth_percentage(last_month_contacts, this_month_contacts),
        subscribed: contacts.where(status: 'subscribed').count,
        unsubscribed: contacts.where(status: 'unsubscribed').count,
        engagement_rate: contacts.count > 0 ? (total_opened.to_f / contacts.count * 100).round(1) : 0
      },
      emails: {
        sent: total_sent,
        opened: total_opened,
        clicked: total_clicked,
        open_rate: total_sent > 0 ? (total_opened.to_f / total_sent * 100).round(1) : 0,
        click_rate: total_sent > 0 ? (total_clicked.to_f / total_sent * 100).round(1) : 0,
        bounce_rate: 0.8 # Placeholder - would be calculated from bounce tracking
      },
      revenue: {
        mrr: calculate_mrr,
        growth: 12.5, # Placeholder
        churn_rate: 2.1 # Placeholder
      }
    }
  end

  def get_recent_activity
    activities = []
    
    # Recent campaigns
    @current_account.campaigns.includes(:user)
                   .where('created_at > ?', 7.days.ago)
                   .order(created_at: :desc)
                   .limit(10)
                   .each do |campaign|
      activities << {
        type: 'campaign_created',
        title: "Campaign \"#{campaign.name}\" created",
        subtitle: "by #{campaign.user.display_name}",
        time: campaign.created_at,
        icon: 'mail',
        color: 'blue',
        link: campaign_path(campaign)
      }
    end
    
    # Recent contacts
    @current_account.contacts.where('created_at > ?', 7.days.ago)
                   .order(created_at: :desc)
                   .limit(5)
                   .each do |contact|
      activities << {
        type: 'contact_added',
        title: "New contact: #{contact.first_name} #{contact.last_name}",
        subtitle: contact.email,
        time: contact.created_at,
        icon: 'user-plus',
        color: 'green',
        link: contact_path(contact)
      }
    end
    
    # Recent opens/clicks
    recent_opens = CampaignContact.joins(:campaign, :contact)
                                 .where(campaigns: { account: @current_account })
                                 .where('opened_at > ?', 24.hours.ago)
                                 .order(opened_at: :desc)
                                 .limit(5)
    
    recent_opens.each do |cc|
      activities << {
        type: 'email_opened',
        title: "#{cc.contact.display_name} opened email",
        subtitle: cc.campaign.name,
        time: cc.opened_at,
        icon: 'mail-open',
        color: 'purple',
        link: campaign_path(cc.campaign)
      }
    end
    
    activities.sort_by { |a| a[:time] }.reverse.first(15)
  end

  def get_quick_actions
    actions = []
    
    # Personalized suggestions based on account state
    if @current_account.campaigns.count == 0
      actions << {
        title: 'Create Your First Campaign',
        description: 'Get started with a welcome email',
        icon: 'plus-circle',
        color: 'blue',
        link: new_campaign_path,
        priority: 'high'
      }
    elsif @current_account.campaigns.where(status: 'draft').any?
      actions << {
        title: 'Send Draft Campaigns',
        description: "#{@current_account.campaigns.where(status: 'draft').count} campaigns ready to send",
        icon: 'send',
        color: 'green',
        link: campaigns_path(status: 'draft'),
        priority: 'high'
      }
    else
      actions << {
        title: 'Create New Campaign',
        description: 'Design your next marketing message',
        icon: 'plus-circle',
        color: 'blue',
        link: new_campaign_path,
        priority: 'medium'
      }
    end
    
    if @current_account.contacts.count < 10
      actions << {
        title: 'Import Contacts',
        description: 'Upload your customer list',
        icon: 'upload',
        color: 'indigo',
        link: import_contacts_path,
        priority: 'high'
      }
    end
    
    if @current_account.templates.count < 3
      actions << {
        title: 'Browse Templates',
        description: 'Find professional email designs',
        icon: 'template',
        color: 'purple',
        link: marketplace_templates_path,
        priority: 'medium'
      }
    end
    
    # Always available actions
    actions += [
      {
        title: 'View Analytics',
        description: 'See how your campaigns perform',
        icon: 'chart-bar',
        color: 'orange',
        link: analytics_path,
        priority: 'low'
      },
      {
        title: 'Account Settings',
        description: 'Manage your account and team',
        icon: 'cog',
        color: 'gray',
        link: account_path,
        priority: 'low'
      }
    ]
    
    actions.sort_by { |a| ['high', 'medium', 'low'].index(a[:priority]) }
  end

  def calculate_performance_metrics
    last_30_days = 30.days.ago..Time.current
    campaign_contacts = CampaignContact.joins(:campaign)
                                     .where(campaigns: { account: @current_account })
                                     .where('campaign_contacts.sent_at' => last_30_days)

    # Daily performance for charts
    daily_data = []
    (29.days.ago.to_date..Date.current).each do |date|
      day_contacts = campaign_contacts.where('campaign_contacts.sent_at' => date.beginning_of_day..date.end_of_day)
      sent_count = day_contacts.count
      opened_count = day_contacts.where.not(opened_at: nil).count
      clicked_count = day_contacts.where.not(clicked_at: nil).count
      
      daily_data << {
        date: date.strftime('%Y-%m-%d'),
        sent: sent_count,
        opened: opened_count,
        clicked: clicked_count,
        open_rate: sent_count > 0 ? (opened_count.to_f / sent_count * 100).round(1) : 0
      }
    end
    
    {
      daily_performance: daily_data,
      top_campaigns: get_top_performing_campaigns,
      engagement_by_day: calculate_engagement_by_day
    }
  end

  def get_upcoming_tasks
    tasks = []
    
    # Scheduled campaigns
    scheduled = @current_account.campaigns.where(status: 'scheduled')
                               .where('scheduled_at > ?', Time.current)
                               .order(scheduled_at: :asc)
                               .limit(5)
    
    scheduled.each do |campaign|
      tasks << {
        title: "Send \"#{campaign.name}\"",
        due_date: campaign.scheduled_at,
        type: 'campaign',
        priority: 'high',
        link: campaign_path(campaign)
      }
    end
    
    # Account limits warnings
    plan_limits = @current_account.plan_limits
    if @current_account.contacts.count > plan_limits[:contacts] * 0.8
      tasks << {
        title: 'Contact limit approaching',
        due_date: nil,
        type: 'warning',
        priority: 'medium',
        link: account_billing_path
      }
    end
    
    # Suggested tasks based on usage
    if @current_account.campaigns.where('created_at > ?', 30.days.ago).count == 0
      tasks << {
        title: 'Create monthly newsletter',
        due_date: nil,
        type: 'suggestion',
        priority: 'low',
        link: new_campaign_path
      }
    end
    
    tasks.sort_by { |t| t[:due_date] || 1.year.from_now }
  end

  def calculate_growth_insights
    insights = []
    
    # Open rate insights
    avg_open_rate = @overview_stats[:emails][:open_rate]
    industry_avg = 21.3 # Industry average for small businesses
    
    if avg_open_rate > industry_avg
      insights << {
        type: 'success',
        title: 'Great open rates!',
        description: "Your #{avg_open_rate}% open rate is above the #{industry_avg}% industry average",
        action: 'Keep using engaging subject lines',
        icon: 'trending-up'
      }
    elsif avg_open_rate < industry_avg * 0.8
      insights << {
        type: 'improvement',
        title: 'Improve your open rates',
        description: "Your #{avg_open_rate}% open rate could be improved",
        action: 'Try A/B testing subject lines',
        icon: 'lightbulb'
      }
    end
    
    # Contact growth
    contact_growth = @overview_stats[:contacts][:growth]
    if contact_growth > 0
      insights << {
        type: 'growth',
        title: 'Growing audience!',
        description: "#{contact_growth}% contact growth this month",
        action: 'Consider increasing campaign frequency',
        icon: 'users'
      }
    end
    
    # Plan usage insights
    plan_limits = @current_account.plan_limits
    contact_usage = (@current_account.contacts.count.to_f / plan_limits[:contacts] * 100).round
    
    if contact_usage > 80
      insights << {
        type: 'warning',
        title: 'Plan limit approaching',
        description: "You're using #{contact_usage}% of your contact limit",
        action: 'Consider upgrading your plan',
        icon: 'exclamation-triangle'
      }
    end
    
    insights
  end

  def get_template_recommendations
    # Simple recommendations based on account activity
    recs = []
    
    if @current_account.business_type == 'E-commerce Store'
      recs << {
        name: 'Abandoned Cart Recovery',
        description: 'Win back customers who left items in their cart',
        category: 'automation',
        popularity: 'high'
      }
    end
    
    recs << {
      name: 'Monthly Newsletter',
      description: 'Keep your audience engaged with regular updates',
      category: 'newsletter',
      popularity: 'high'
    }
    
    recs.first(3)
  end

  def calculate_growth_percentage(old_value, new_value)
    return 0 if old_value == 0
    ((new_value - old_value).to_f / old_value * 100).round(1)
  end

  def recent_engagement_count(column)
    CampaignContact.joins(:campaign)
                  .where(campaigns: { account: @current_account })
                  .where("#{column} > ?", 1.hour.ago)
                  .count
  end

  def calculate_mrr
    # Placeholder - would integrate with billing system
    case @current_account.plan
    when 'starter' then 29
    when 'professional' then 99
    when 'enterprise' then 299
    else 0
    end
  end

  def get_top_performing_campaigns
    @current_account.campaigns
                   .joins(:campaign_contacts)
                   .where('campaign_contacts.sent_at BETWEEN ? AND ?', 30.days.ago, Time.current)
                   .group('campaigns.id, campaigns.name')
                   .select('campaigns.*,
                          COUNT(campaign_contacts.id) as sent_count,
                          COUNT(CASE WHEN campaign_contacts.opened_at IS NOT NULL THEN 1 END) as opened_count')
                   .having('COUNT(campaign_contacts.id) > 0')
                   .order(Arel.sql('COUNT(CASE WHEN campaign_contacts.opened_at IS NOT NULL THEN 1 END)::float / COUNT(campaign_contacts.id) DESC'))
                   .limit(5)
                   .map do |campaign|
      {
        name: campaign.name,
        sent: campaign.sent_count,
        opened: campaign.opened_count,
        open_rate: (campaign.opened_count.to_f / campaign.sent_count * 100).round(1)
      }
    end
  end

  def calculate_engagement_by_day
    # Day of week engagement analysis
    campaign_contacts = CampaignContact.joins(:campaign)
                                     .where(campaigns: { account: @current_account })
                                     .where('campaign_contacts.sent_at > ?', 30.days.ago)

    days = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]
    days.map.with_index do |day, index|
      day_contacts = campaign_contacts.where("EXTRACT(dow FROM campaign_contacts.sent_at) = ?", index)
      sent_count = day_contacts.count
      opened_count = day_contacts.where.not(opened_at: nil).count

      {
        day: day,
        sent: sent_count,
        opened: opened_count,
        open_rate: sent_count > 0 ? (opened_count.to_f / sent_count * 100).round(1) : 0
      }
    end
  end

  def get_recent_campaigns
    @current_account.campaigns
                   .includes(:user, :template)
                   .order(created_at: :desc)
                   .limit(5)
  end
end
