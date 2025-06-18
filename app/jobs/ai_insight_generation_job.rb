class AiInsightGenerationJob < ApplicationJob
  queue_as :ai_analytics
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  def perform(account_id, insight_type = 'general', options = {})
    account = Account.find(account_id)
    ai_service = AiService.new(account)
    
    begin
      case insight_type
      when 'campaign_performance'
        generate_campaign_insights(account, ai_service, options)
      when 'contact_engagement'
        generate_contact_insights(account, ai_service, options)
      when 'content_optimization'
        generate_content_insights(account, ai_service, options)
      when 'automation_effectiveness'
        generate_automation_insights(account, ai_service, options)
      else
        generate_general_insights(account, ai_service, options)
      end
      
    rescue => error
      Rails.logger.error "AI insight generation failed for account #{account_id}: #{error.message}"
      
      # Log failed operation
      AiUsageLog.create!(
        account: account,
        operation_type: 'insight_generation',
        success: false,
        error_message: error.message,
        metadata: {
          insight_type: insight_type,
          options: options
        }
      )
      
      raise error
    end
  end
  
  private
  
  def generate_campaign_insights(account, ai_service, options)
    campaigns = account.campaigns.includes(:campaign_contacts)
                      .where(created_at: 30.days.ago..Time.current)
    
    return if campaigns.empty?
    
    campaign_data = campaigns.map do |campaign|
      {
        name: campaign.name,
        sent_count: campaign.campaign_contacts.count,
        open_rate: campaign.open_rate,
        click_rate: campaign.click_rate,
        subject: campaign.subject,
        created_at: campaign.created_at
      }
    end
    
    prompt = build_campaign_analysis_prompt(campaign_data)
    result = ai_service.generate_insights(prompt, { type: 'campaign_performance' })
    
    create_insight(
      account: account,
      insight_type: 'campaign_performance',
      title: 'Campaign Performance Analysis',
      content: result[:content],
      confidence_score: result[:confidence_score] || 0.8,
      metadata: {
        campaigns_analyzed: campaigns.count,
        date_range: '30 days',
        tokens_used: result[:tokens_used],
        cost: result[:cost]
      },
      ai_service: ai_service,
      result: result
    )
  end
  
  def generate_contact_insights(account, ai_service, options)
    contacts = account.contacts.includes(:contact_tags, :campaign_contacts)
                     .where('last_opened_at > ? OR created_at > ?', 30.days.ago, 30.days.ago)
    
    return if contacts.empty?
    
    contact_data = {
      total_contacts: contacts.count,
      engaged_contacts: contacts.where('last_opened_at > ?', 7.days.ago).count,
      new_contacts: contacts.where(created_at: 7.days.ago..Time.current).count,
      top_tags: contacts.joins(:contact_tags, :tags).group('tags.name').count.first(5)
    }
    
    prompt = build_contact_analysis_prompt(contact_data)
    result = ai_service.generate_insights(prompt, { type: 'contact_engagement' })
    
    create_insight(
      account: account,
      insight_type: 'contact_engagement',
      title: 'Contact Engagement Analysis',
      content: result[:content],
      confidence_score: result[:confidence_score] || 0.8,
      metadata: {
        contacts_analyzed: contacts.count,
        date_range: '30 days',
        tokens_used: result[:tokens_used],
        cost: result[:cost]
      },
      ai_service: ai_service,
      result: result
    )
  end
  
  def generate_content_insights(account, ai_service, options)
    content_generations = account.content_generations
                                .where(status: 'completed')
                                .where(created_at: 30.days.ago..Time.current)
    
    return if content_generations.empty?
    
    content_data = {
      total_generations: content_generations.count,
      content_types: content_generations.group(:content_type).count,
      average_tokens: content_generations.average(:tokens_used),
      total_cost: content_generations.sum(:cost)
    }
    
    prompt = build_content_analysis_prompt(content_data)
    result = ai_service.generate_insights(prompt, { type: 'content_optimization' })
    
    create_insight(
      account: account,
      insight_type: 'content_optimization',
      title: 'Content Generation Analysis',
      content: result[:content],
      confidence_score: result[:confidence_score] || 0.8,
      metadata: {
        generations_analyzed: content_generations.count,
        date_range: '30 days',
        tokens_used: result[:tokens_used],
        cost: result[:cost]
      },
      ai_service: ai_service,
      result: result
    )
  end
  
  def generate_automation_insights(account, ai_service, options)
    automations = account.email_automations.includes(:automation_executions)
    
    return if automations.empty?
    
    automation_data = automations.map do |automation|
      executions = automation.automation_executions.where(created_at: 30.days.ago..Time.current)
      {
        name: automation.name,
        total_executions: executions.count,
        successful_executions: executions.where(status: 'completed').count,
        trigger_type: automation.trigger_type
      }
    end
    
    prompt = build_automation_analysis_prompt(automation_data)
    result = ai_service.generate_insights(prompt, { type: 'automation_effectiveness' })
    
    create_insight(
      account: account,
      insight_type: 'automation_effectiveness',
      title: 'Automation Effectiveness Analysis',
      content: result[:content],
      confidence_score: result[:confidence_score] || 0.8,
      metadata: {
        automations_analyzed: automations.count,
        date_range: '30 days',
        tokens_used: result[:tokens_used],
        cost: result[:cost]
      },
      ai_service: ai_service,
      result: result
    )
  end
  
  def generate_general_insights(account, ai_service, options)
    # Generate general account insights
    account_data = {
      total_campaigns: account.campaigns.count,
      total_contacts: account.contacts.count,
      recent_activity: account.campaigns.where(created_at: 7.days.ago..Time.current).count,
      account_age: (Time.current - account.created_at).to_i / 1.day
    }
    
    prompt = build_general_analysis_prompt(account_data)
    result = ai_service.generate_insights(prompt, { type: 'general' })
    
    create_insight(
      account: account,
      insight_type: 'general',
      title: 'Account Overview Insights',
      content: result[:content],
      confidence_score: result[:confidence_score] || 0.8,
      metadata: {
        date_range: 'all time',
        tokens_used: result[:tokens_used],
        cost: result[:cost]
      },
      ai_service: ai_service,
      result: result
    )
  end
  
  def create_insight(account:, insight_type:, title:, content:, confidence_score:, metadata:, ai_service:, result:)
    AiInsight.create!(
      account: account,
      insight_type: insight_type,
      title: title,
      content: content,
      confidence_score: confidence_score,
      metadata: metadata,
      expires_at: 7.days.from_now
    )
    
    # Log successful operation
    AiUsageLog.create!(
      account: account,
      ai_provider: result[:ai_provider],
      operation_type: 'insight_generation',
      tokens_used: result[:tokens_used],
      cost: result[:cost],
      success: true,
      response_time_ms: result[:response_time_ms],
      metadata: {
        insight_type: insight_type,
        title: title
      }
    )
  end
  
  def build_campaign_analysis_prompt(campaign_data)
    "Analyze the following campaign performance data and provide actionable insights:\n\n" +
    campaign_data.map { |c| "Campaign: #{c[:name]}, Sent: #{c[:sent_count]}, Open Rate: #{c[:open_rate]}%, Click Rate: #{c[:click_rate]}%" }.join("\n") +
    "\n\nProvide specific recommendations for improving campaign performance."
  end
  
  def build_contact_analysis_prompt(contact_data)
    "Analyze the following contact engagement data and provide insights:\n\n" +
    "Total Contacts: #{contact_data[:total_contacts]}\n" +
    "Engaged Contacts (7 days): #{contact_data[:engaged_contacts]}\n" +
    "New Contacts (7 days): #{contact_data[:new_contacts]}\n" +
    "Top Tags: #{contact_data[:top_tags].map { |tag, count| "#{tag} (#{count})" }.join(', ')}\n\n" +
    "Provide recommendations for improving contact engagement and segmentation."
  end
  
  def build_content_analysis_prompt(content_data)
    "Analyze the following content generation data and provide optimization insights:\n\n" +
    "Total Generations: #{content_data[:total_generations]}\n" +
    "Content Types: #{content_data[:content_types].map { |type, count| "#{type} (#{count})" }.join(', ')}\n" +
    "Average Tokens: #{content_data[:average_tokens]&.round(2)}\n" +
    "Total Cost: $#{content_data[:total_cost]&.round(4)}\n\n" +
    "Provide recommendations for optimizing content generation efficiency and cost."
  end
  
  def build_automation_analysis_prompt(automation_data)
    "Analyze the following automation performance data and provide insights:\n\n" +
    automation_data.map { |a| "Automation: #{a[:name]}, Executions: #{a[:total_executions]}, Success Rate: #{((a[:successful_executions].to_f / a[:total_executions]) * 100).round(2)}%" }.join("\n") +
    "\n\nProvide recommendations for improving automation effectiveness."
  end
  
  def build_general_analysis_prompt(account_data)
    "Analyze the following account data and provide general insights:\n\n" +
    "Total Campaigns: #{account_data[:total_campaigns]}\n" +
    "Total Contacts: #{account_data[:total_contacts]}\n" +
    "Recent Activity (7 days): #{account_data[:recent_activity]} campaigns\n" +
    "Account Age: #{account_data[:account_age]} days\n\n" +
    "Provide general recommendations for improving overall marketing performance."
  end
end