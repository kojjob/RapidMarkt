class CampaignTag < ApplicationRecord
  belongs_to :campaign
  belongs_to :tag
  
  validates :campaign_id, uniqueness: { scope: :tag_id }
end