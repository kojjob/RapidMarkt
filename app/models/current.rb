class Current < ActiveSupport::CurrentAttributes
  attribute :user, :account, :ip_address, :user_agent, :request_id
  
  def user=(user)
    super
    self.account = user&.account
  end
  
  def account=(account)
    super
    Time.zone = 'UTC' # Could be enhanced with account timezone in the future
  end
  
  def request_id
    super || SecureRandom.hex(8)
  end
  
  def request_context
    {
      user_id: user&.id,
      account_id: account&.id,
      ip_address: ip_address,
      user_agent: user_agent,
      request_id: request_id
    }
  end
end
