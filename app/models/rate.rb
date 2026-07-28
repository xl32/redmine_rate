require 'lockfile'

class Rate < ActiveRecord::Base
  class InvalidParameterException < RuntimeError; end
  CACHING_LOCK_FILE_NAME = 'rate_cache'.freeze

  belongs_to :project
  belongs_to :user
  has_many :time_entries

  validates :user_id, presence: true
  validates :date_in_effect, presence: true
  validates :amount, numericality: true

  # NOTE: since Rails 5 a callback returning +false+ no longer halts the chain;
  # a locked rate must abort the save/destroy explicitly via +throw :abort+
  # (see #ensure_unlocked). Required for Redmine 6.1 (Rails 7.2) / 7.0 (Rails 8.0).
  # Editing a locked rate stays possible when the lock is disabled in the plugin
  # settings; the associated time entries keep their rate_id and only have their
  # cached cost recomputed (see #update_time_entry_cost_cache).
  before_save :ensure_unlocked
  after_save :update_time_entry_cost_cache
  before_destroy :ensure_unlocked
  after_destroy :update_time_entry_cost_cache

  scope :history_for_user, (->(user, order) { where(user_id: user.id).order(order).includes(:project) })

  # Whether locked rates are protected from changes. Admins can turn the lock
  # off in the plugin settings (Administration -> Plugins -> Rate).
  def self.lock_enforced?
    !RedmineRate.setting?(:disable_rate_lock)
  end

  def locked?
    !time_entries.empty?
  end

  def unlocked?
    !locked?
  end

  # Whether the rate may still be edited or deleted: either it has no time
  # entries yet, or the lock has been disabled in the plugin settings.
  def editable?
    unlocked? || !Rate.lock_enforced?
  end

  def default?
    project.nil?
  end

  def specific?
    !default?
  end

  # API to find the Rate for a +user+ on a +project+ at a +date+
  def self.for(user, project = nil, date = Time.zone.today.to_s)
    # Check input since it's a "public" API
    raise Rate::InvalidParameterException.new('user must be a Principal instance') unless user.is_a?(Principal)
    raise Rate::InvalidParameterException.new('project must be a Project instance') unless project.nil? || project.is_a?(Project)
    Rate.check_date_string(date)

    rate = for_user_project_and_date(user, project, date)
    # Check for a default (non-project) rate
    rate = default_for_user_and_date(user, date) if rate.nil? && project
    rate
  end

  # API to find the amount for a +user+ on a +project+ at a +date+
  def self.amount_for(user, project = nil, date = Time.zone.today.to_s)
    rate = self.for(user, project, date)
    return nil if rate.nil?
    rate.amount
  end

  def self.update_all_time_entries_with_missing_cost(options = {})
    with_common_lockfile(options[:force]) do
      TimeEntry.where(cost: nil).each do |time_entry|
        begin
          time_entry.recalculate_cost!
        rescue Rate::InvalidParameterException => ex
          Rails.logger.error "Error saving #{time_entry.id}: #{ex.message}"
        end
      end
      TimeEntry.where(cost: nil).find_each(&:recalculate_cost!)
    end
    store_cache_timestamp(:last_caching_run, Time.now.utc.to_s)
  end

  def self.update_all_time_entries_to_refresh_cache(options = {})
    with_common_lockfile(options[:force]) do
      TimeEntry.find_each do |time_entry| # batch find
        begin
          time_entry.recalculate_cost!
        rescue Rate::InvalidParameterException => ex
          Rails.logger.error "Error saving #{time_entry.id}: #{ex.message}"
        end
      end
    end
    store_cache_timestamp(:last_cache_clearing_run, Time.now.utc.to_s)
  end

  def self.for_user_project_and_date(user, project, date)
    if project.nil?
      Rate.where('user_id IN (?) AND date_in_effect <= ? AND project_id IS NULL', user.id, date)
          .order('date_in_effect DESC')
          .first
    else
      Rate.where('user_id IN (?) AND project_id IN (?) AND date_in_effect <= ?', user.id, project.id, date)
          .order('date_in_effect DESC')
          .first
    end
  end

  def self.default_for_user_and_date(user, date)
    for_user_project_and_date(user, nil, date)
  end

  # Checks a date string to make sure it is in format of +YYYY-MM-DD+, throwing
  # a Rate::InvalidParameterException otherwise
  def self.check_date_string(date)
    raise Rate::InvalidParameterException.new('date must be a valid Date string (e.g. YYYY-MM-DD)') unless date.is_a?(String)

    begin
      Date.parse(date)
    rescue ArgumentError
      raise Rate::InvalidParameterException.new('date must be a valid Date string (e.g. YYYY-MM-DD)')
    end
  end

  def self.store_cache_timestamp(cache_name, timestamp)
    # Persist a plain Hash, never ActionController::Parameters: Rails 7.1+ (Redmine
    # 6.1/7.0) serializes Settings through YAML safe-load, which rejects the
    # Parameters class and would raise on read.
    Setting.plugin_redmine_rate = RedmineRate.settings.merge(cache_name => timestamp).to_unsafe_h
  end

  def self.with_common_lockfile(force = false, &block)
    # Wait 1 second after stealing a forced lock
    options = { retries: 0, suspend: 1 }
    options[:max_age] = 1 if force

    Lockfile(lock_file, options) do
      block.call
    end
  end

  def self.lock_file
    Rails.root + 'tmp' + Rate::CACHING_LOCK_FILE_NAME
  end

  private

  # Halts the save/destroy callback chain when the rate is locked (has time
  # entries). Kept separate from #unlocked?, which must stay a plain predicate
  # for controllers and views.
  def ensure_unlocked
    throw :abort unless editable?
  end

  def update_time_entry_cost_cache
    TimeEntry.update_cost_cache(user, project)
  end
end
