class RatesController < ApplicationController
  helper :users
  helper :sort
  include SortHelper

  before_action :require_admin
  before_action :require_user_id, only: %i[index new]
  before_action :set_back_url

  # REST API: allows API key / basic auth. All actions require admin
  # (see require_admin above), so the API is effectively admin-only.
  accept_api_auth :index, :show, :create, :update, :destroy

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
      format.api  # index.api.rsb
      format.js
    end
  end

  # GET /rates/1
  # GET /rates/1.xml
  # GET /rates/1.json
  def show
    @rate = Rate.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.api  # show.api.rsb
    end
  end

  # GET /rates/new?user_id=1
  def new
    @rate = Rate.new(user_id: @user.id)
  end

  # GET /rates/1/edit
  def edit
    @rate = Rate.find(params[:id])
  end

  # POST /rates
  # POST /rates.xml
  # POST /rates.json
  def create
    @rate = Rate.new(rate_params)

    respond_to do |format|
      if @rate.save
        format.html do
          flash[:notice] = l(:rate_created_message)
          redirect_back_or_default(rates_url(user_id: @rate.user_id))
        end
        format.js { render action: :create }
        format.api { render action: 'show', status: :created, location: rate_url(@rate) }
      else
        format.html { render action: 'new' }
        format.js do
          flash.now[:error] = l(:rate_error_creating_new_rate)
          render action: :create_error
        end
        format.api { render_validation_errors(@rate) }
      end
    end
  end

  # PUT /rates/1
  # PUT /rates/1.xml
  # PUT /rates/1.json
  def update
    @rate = Rate.find(params[:id])

    respond_to do |format|
      # Locked rates will fail saving here (before_save aborts the callback chain),
      # unless the lock has been disabled in the plugin settings.
      if @rate.update rate_params
        flash[:notice] = l(:rate_updated_message)
        format.html { redirect_back_or_default(rates_url(user_id: @rate.user_id)) }
        format.api { render_api_ok }
      else
        unless @rate.editable?
          flash[:error] = l(:rate_locked_message)
          @rate.reload # Removes attribute changes
          @rate.errors.add(:base, l(:rate_locked_message))
        end
        format.html { render action: 'edit' }
        format.api { render_validation_errors(@rate) }
      end
    end
  end

  # DELETE /rates/1
  # DELETE /rates/1.xml
  # DELETE /rates/1.json
  def destroy
    @rate = Rate.find(params[:id])
    destroyed = @rate.destroy

    respond_to do |format|
      format.html do
        if destroyed
          flash[:notice] = 'Rate was deleted.'
          redirect_back_or_default rates_url(user_id: @rate.user_id)
        else
          flash[:error] = 'Rate is locked and cannot be deleted'
        end
      end
      format.api do
        if destroyed
          render_api_ok
        else
          @rate.errors.add(:base, l(:rate_locked_message)) if @rate.errors.empty?
          render_validation_errors(@rate)
        end
      end
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
      format.api  { render_api_head :not_found }
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
