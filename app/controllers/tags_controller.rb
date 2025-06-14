class TagsController < ApplicationController
  before_action :set_tag, only: [ :show, :edit, :update, :destroy ]

  def index
    @tags = @current_account.tags
                           .left_joins(:contact_tags)
                           .group("tags.id")
                           .select("tags.*, COUNT(contact_tags.id) as contacts_count")
                           .order(:name)
                           .page(params[:page])
  end

  def show
    @contacts = @tag.contacts.order(:last_name, :first_name).page(params[:page])
  end

  def new
    @tag = @current_account.tags.build
  end

  def create
    @tag = @current_account.tags.build(tag_params)

    if @tag.save
      redirect_to tags_path, notice: "Tag was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @tag.update(tag_params)
      redirect_to @tag, notice: "Tag was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tag.destroy
    redirect_to tags_url, notice: "Tag was successfully deleted."
  end

  private

  def set_tag
    @tag = @current_account.tags.find(params[:id])
  end

  def tag_params
    params.require(:tag).permit(:name, :color, :description)
  end
end
