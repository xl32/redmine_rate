class RatesController < ApplicationController
  helper :users
  helper :sort
  include SortHelper

  before_action :require_admin
  before_action :require_user_id, only: %i[index new]
  before_action :set_back_url

  VALID_SORT_OPTIONS = {
    'date_in_effect' => "#{Rate.table_name}.date_in_effect",
    'project_id' => "#{Project.table_name}.name"
  }.freeze

  # GET /rates?user_id=1
  # GET /rates.xml?user_id=1
  # GET /rates.json?user_id=1
  def index
    sort_init "#{Rate.table_name}.date_in_effect", 'desc'
    sort_update VALID_SORT_OPTIONS

    @rates = Rate.history_for_user(@user, sort_clause)

    respond_to do |format|
      format.html { render action: 'index', layout: !request.xhr? }
      format.xml  { render xml: @rates }
      format.js
    end
  end

  # GET /rates/1
  # GET /rates/1.xml
  def show
    @rate = Rate.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render xml: @rate }
    end
  end

  # GET /rates/new?user_id=1
  # GET /rates/new.xml?user_id=1
  def new
    @rate = Rate.new(user_id: @user.id)

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render xml: @rate }
    end
  end

  # GET /rates/1/edit
  def edit
    @rate = Rate.find(params[:id])
  end

  # POST /rates
  # POST /rates.xml
  def create
    @rate = Rate.new(rate_params)

    respond_to do |format|
      if @rate.save
        format.html do
          flash[:notice] = l(:rate_created_message)
          redirect_back_or_default(rates_url(user_id: @rate.user_id))
        end
        format.xml  { render xml: @rate, status: :created, location: @rate }
        format.js { render action: :create }
      else
        format.html { render action: 'new' }
        format.xml  { render xml: @rate.errors, status: :unprocessable_entity }
        format.js do
          flash.now[:error] = l(:rate_error_creating_new_rate)
          render action: :create_error
        end
      end
    end
  end

  # PUT /rates/1
  # PUT /rates/1.xml
  def update
    @rate = Rate.find(params[:id])

    respond_to do |format|
      # Locked rates will fail saving here.
      if @rate.update rate_params
        flash[:notice] = l(:rate_updated_message)
        format.html { redirect_back_or_default(rates_url(user_id: @rate.user_id)) }
        format.xml  { head :ok }
      else
        if @rate.locked?
          flash[:error] = l(:rate_locked_message)
          @rate.reload # Removes attribute changes
        end
        format.html { render action: 'edit' }
        format.xml  { render xml: @rate.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /rates/1
  # DELETE /rates/1.xml
  def destroy
    @rate = Rate.find(params[:id])
    @rate.destroy

    respond_to do |format|
      format.html do
        if @rate.locked?
          flash[:error] = 'Rate is locked and cannot be deleted'
        else
          flash[:notice] = 'Rate was deleted.'
          redirect_back_or_default rates_url(user_id: @rate.user_id)
        end
      end
      format.xml { head :ok }
    end
  end

  private

  def rate_params
    params.require(:rate).permit :amount, :date_in_effect, :project_id, :user_id
  end

  def require_user_id
    @user = User.find(params[:user_id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      flash[:error] = l(:rate_error_user_not_found)
      format.html { redirect_to(home_url) }
      format.xml  { render xml: 'User not found', status: :not_found }
    end
  end

  def set_back_url
    @back_url = params[:back_url]
    @back_url
  end

  # Override defination from ApplicationController to make sure it follows a
  # whitelist
  def redirect_back_or_default(default)
    whitelist = %r{(rates|/users/edit)}

    back_url = CGI.unescape(params[:back_url].to_s)
    if back_url.present?
      begin
        uri = URI.parse(back_url)
        if uri.path && uri.path.match(whitelist)
          super
          return
        end
      rescue URI::InvalidURIError
        # redirect to default
        logger.debug('Invalid URI sent to redirect_back_or_default: ' + params[:back_url].inspect)
      end
    end
    redirect_to default
  end
end
