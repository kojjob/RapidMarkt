class MigrateTagsToNewSystem < ActiveRecord::Migration[8.0]
  def up
    # Migrate existing text-based tags to new Tag model
    Contact.where("tags IS NOT NULL AND tags != ''").find_each do |contact|
      tags_text = contact.read_attribute(:tags)
      next if tags_text.blank?
      
      # Parse the comma-separated tags
      tag_names = tags_text.split(',').map(&:strip).reject(&:blank?)
      
      tag_names.each do |tag_name|
        # Find or create the tag for this account
        tag = Tag.find_or_create_by(
          account: contact.account,
          name: tag_name.downcase
        )
        
        # Create the association if it doesn't exist
        ContactTag.find_or_create_by(
          contact: contact,
          tag: tag
        )
      end
    end
  end
  
  def down
    # Convert back to text-based tags
    Contact.joins(:tags).group('contacts.id').find_each do |contact|
      tag_names = contact.tags.pluck(:name)
      contact.update_column(:tags, tag_names.join(', '))
    end
    
    # Clean up the new tables
    ContactTag.delete_all
    Tag.delete_all
  end
end
