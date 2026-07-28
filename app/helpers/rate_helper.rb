module RateHelper
  # Serializes a single Rate for the read-only REST API.
  # Shared by rates/index.api.rsb and rates/show.api.rsb.
  def render_api_rate(api, rate)
    api.rate do
      api.id             rate.id
      api.amount         rate.amount
      api.date_in_effect rate.date_in_effect
      api.locked         rate.locked?
      # locked rates stay writable while the lock is disabled in the settings
      api.editable       rate.editable?
      api.user(id: rate.user_id, name: rate.user&.name) if rate.user_id
      api.project(id: rate.project_id, name: rate.project&.name) if rate.project_id
    end
  end
end
