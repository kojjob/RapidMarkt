require "csv"

class ContactExportService
  def initialize(contacts)
    @contacts = contacts
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << headers

      @contacts.find_each do |contact|
        csv << [
          contact.first_name,
          contact.last_name,
          contact.email,
          contact.status,
          contact.tags.pluck(:name).join(", "),
          contact.subscribed_at&.strftime("%Y-%m-%d %H:%M:%S"),
          contact.unsubscribed_at&.strftime("%Y-%m-%d %H:%M:%S"),
          contact.last_opened_at&.strftime("%Y-%m-%d %H:%M:%S"),
          contact.created_at.strftime("%Y-%m-%d %H:%M:%S"),
          contact.updated_at.strftime("%Y-%m-%d %H:%M:%S")
        ]
      end
    end
  end

  private

  def headers
    [
      "First Name",
      "Last Name",
      "Email",
      "Status",
      "Tags",
      "Subscribed At",
      "Unsubscribed At",
      "Last Opened At",
      "Created At",
      "Updated At"
    ]
  end
end
