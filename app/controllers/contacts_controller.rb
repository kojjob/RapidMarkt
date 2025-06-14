class ContactsController < ApplicationController
  before_action :set_contact, only: [:show, :edit, :update, :destroy]

  def index
    @contacts = @current_account.contacts
                               .includes(:tags)
                               .order(:last_name, :first_name)
    
    # Filter by search query
    if params[:search].present?
      @contacts = @contacts.where(
        "first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?",
        "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end

    # Filter by tag
    if params[:tag].present?
      @contacts = @contacts.joins(:tags).where(tags: { name: params[:tag] })
    end

    # Filter by status
    if params[:status].present?
      @contacts = @contacts.where(status: params[:status])
    end

    @contacts = @contacts.page(params[:page])
    @tags = @current_account.tags.order(:name)
  end

  def show
    @campaign_history = @contact.campaign_contacts
                               .includes(:campaign)
                               .order(created_at: :desc)
                               .limit(10)
  end

  def new
    @contact = @current_account.contacts.build
    @tags = @current_account.tags.order(:name)
  end

  def create
    @contact = @current_account.contacts.build(contact_params)

    if @contact.save
      redirect_to @contact, notice: 'Contact was successfully created.'
    else
      @tags = @current_account.tags.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @tags = @current_account.tags.order(:name)
  end

  def update
    if @contact.update(contact_params)
      redirect_to @contact, notice: 'Contact was successfully updated.'
    else
      @tags = @current_account.tags.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @contact.destroy
    redirect_to contacts_url, notice: 'Contact was successfully deleted.'
  end

  def import
    if request.post?
      if params[:file].present?
        result = ContactImportService.new(@current_account, params[:file]).call
        if result[:success]
          redirect_to contacts_path, notice: "Successfully imported #{result[:imported_count]} contacts."
        else
          flash.now[:alert] = result[:error]
          render :import
        end
      else
        flash.now[:alert] = 'Please select a file to import.'
        render :import
      end
    end
  end

  def export
    contacts = @current_account.contacts.includes(:tags)
    
    respond_to do |format|
      format.csv do
        send_data ContactExportService.new(contacts).to_csv,
                  filename: "contacts_#{Date.current}.csv",
                  type: 'text/csv'
      end
    end
  end

  private

  def set_contact
    @contact = @current_account.contacts.find(params[:id])
  end

  def contact_params
    params.require(:contact).permit(:first_name, :last_name, :email, :phone, :company, :status, tag_ids: [])
  end
end