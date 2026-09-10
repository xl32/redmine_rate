require_relative '../test_helper'

class RateTest < ActiveSupport::TestCase
  def rate_valid_attributes
    {
      user: User.generate!,
      project: Project.generate!,
      date_in_effect: Date.new(Time.zone.today.year, 1, 1),
      amount: 100.50
    }
  end

  def setup
    TimeEntryActivity.generate!
  end

  should belong_to :project
  should belong_to :user
  should have_many :time_entries

  should validate_presence_of :user_id
  should validate_presence_of :date_in_effect
  should validate_numericality_of :amount

  context '#locked?' do
    should 'should be true if a Time Entry is associated' do
      rate = Rate.new
      rate.time_entries << TimeEntry.generate!
      assert rate.locked?
    end

    should 'should be false if no Time Entries are associated' do
      rate = Rate.new
      assert !rate.locked?
    end
  end

  context '#unlocked?' do
    should 'should be false if a Time Entry is associated' do
      rate = Rate.new
      rate.time_entries << TimeEntry.generate!
      assert !rate.unlocked?
    end

    should 'should be true if no Time Entries are associated' do
      rate = Rate.new
      assert rate.unlocked?
    end
  end

  context '#editable?' do
    should 'should be true if no Time Entries are associated' do
      assert Rate.new.editable?
    end

    should 'should be false if a Time Entry is associated' do
      rate = Rate.new
      rate.time_entries << TimeEntry.generate!
      assert !rate.editable?
    end

    should 'should be true for a locked Rate when the lock is disabled in the settings' do
      rate = Rate.new
      rate.time_entries << TimeEntry.generate!

      with_rate_lock_disabled do
        assert rate.editable?
      end
    end

    should 'should be false for a deleted Rate' do
      rate = Rate.create!(rate_valid_attributes)
      assert rate.soft_delete
      assert !rate.editable?
    end

    should 'should be false for a deleted Rate even when the lock is disabled in the settings' do
      rate = Rate.create!(rate_valid_attributes)
      assert rate.soft_delete

      with_rate_lock_disabled do
        assert !rate.editable?
      end
    end
  end

  context '#deleted?' do
    should 'should be false for a new Rate' do
      assert !Rate.new.deleted?
    end

    should 'should be true once soft-deleted' do
      rate = Rate.create!(rate_valid_attributes)
      rate.soft_delete
      assert rate.deleted?
    end
  end

  context 'with the rate lock disabled' do
    setup do
      @user = User.generate!
      @project = Project.generate!
      @date = Time.zone.today.to_s
      @rate = Rate.generate!(user: @user, project: @project, date_in_effect: @date, amount: 200.0)
      @time_entry = TimeEntry.generate!(user: @user,
                                        project: @project,
                                        spent_on: @date,
                                        hours: 10.0,
                                        activity: TimeEntryActivity.generate!)
      # Assigning the Time Entry sets its rate_id, which is what locks the Rate
      @rate.time_entries << @time_entry
    end

    should 'should save a locked Rate' do
      assert @rate.locked?

      with_rate_lock_disabled do
        @rate.amount = 150.0
        assert @rate.save
      end

      assert_equal 150.0, @rate.reload.amount
    end

    should 'should keep the Time Entries on the Rate and refresh their cached cost' do
      assert_equal 2000.0, @time_entry.reload.cost.to_f
      assert_equal @rate.id, @time_entry.rate_id

      with_rate_lock_disabled do
        assert @rate.update(amount: 150.0)
      end

      @time_entry.reload
      assert_equal @rate.id, @time_entry.rate_id
      assert_equal 1500.0, @time_entry.cost.to_f
    end

    should 'should destroy a locked Rate' do
      assert_difference('Rate.count', -1) do
        with_rate_lock_disabled { @rate.destroy }
      end
    end
  end

  context '#save' do
    should 'should save if a Rate is unlocked' do
      rate = Rate.new(rate_valid_attributes)
      assert rate.save
    end

    should 'should not save if a Rate is locked' do
      rate = Rate.new(rate_valid_attributes)
      rate.time_entries << TimeEntry.generate!
      assert !rate.save
    end
  end

  context 'timestamps' do
    should 'set created_on and updated_on when created' do
      rate = Rate.generate!

      assert_not_nil rate.created_on
      assert_not_nil rate.updated_on
    end

    should 'advance updated_on but not created_on on a later save' do
      rate = Rate.generate!
      # Backdate created_on (bypassing callbacks) so the assertion below doesn't
      # depend on clock precision between the two saves.
      rate.update_column(:created_on, 1.hour.ago)
      original_created_on = rate.reload.created_on

      rate.update(amount: rate.amount + 1)

      assert_equal original_created_on, rate.reload.created_on
      assert_operator rate.updated_on, :>, original_created_on
    end
  end

  context '#destroy' do
    should 'should destroy the Rate if should is unlocked' do
      rate = Rate.create(rate_valid_attributes)
      assert_difference('Rate.count', -1) do
        rate.destroy
      end
    end

    should 'should not destroy the Rate if should is locked' do
      rate = Rate.create(rate_valid_attributes)
      rate.time_entries << TimeEntry.generate!

      assert_difference('Rate.count', 0) do
        rate.destroy
      end
    end
  end

  context '#soft_delete' do
    should 'should set deleted_on and leave the row in the table if the Rate is unlocked' do
      rate = Rate.create!(rate_valid_attributes)

      assert_no_difference('Rate.count') do
        assert rate.soft_delete
      end

      assert rate.reload.deleted?
      assert_not_nil rate.deleted_on
    end

    should 'should bump updated_on' do
      rate = Rate.create!(rate_valid_attributes)
      rate.update_column(:updated_on, 1.hour.ago)
      original_updated_on = rate.reload.updated_on

      rate.soft_delete

      assert_operator rate.reload.updated_on, :>, original_updated_on
    end

    should 'should refresh the cached cost of the user\'s Time Entries' do
      user = User.generate!
      project = Project.generate!
      date = Time.zone.today.to_s
      rate = Rate.generate!(user: user, project: project, date_in_effect: date, amount: 200.0)
      time_entry = TimeEntry.generate!(user: user,
                                        project: project,
                                        spent_on: date,
                                        hours: 10.0,
                                        activity: TimeEntryActivity.generate!)
      assert_equal 2000.0, time_entry.reload.cost.to_f

      with_rate_lock_disabled { rate.soft_delete }

      assert_equal 0, TimeEntry.find(time_entry.id).cost.to_f
    end

    should 'should not soft-delete the Rate if it is locked' do
      rate = Rate.create!(rate_valid_attributes)
      rate.time_entries << TimeEntry.generate!

      assert_no_difference('Rate.count') do
        assert !rate.soft_delete
      end

      assert !rate.reload.deleted?
    end

    should 'should soft-delete a locked Rate when the lock is disabled in the settings' do
      rate = Rate.create!(rate_valid_attributes)
      rate.time_entries << TimeEntry.generate!

      with_rate_lock_disabled do
        assert rate.soft_delete
      end

      assert rate.reload.deleted?
    end

    should 'should be idempotent on an already-deleted Rate' do
      rate = Rate.create!(rate_valid_attributes)
      rate.soft_delete
      deleted_on = rate.reload.deleted_on

      assert rate.soft_delete
      assert_equal deleted_on, rate.reload.deleted_on
    end
  end

  context '.not_deleted / .deleted scopes' do
    should 'should partition live and deleted Rates' do
      live_rate = Rate.create!(rate_valid_attributes)
      deleted_rate = Rate.create!(rate_valid_attributes)
      deleted_rate.soft_delete

      assert_includes Rate.not_deleted, live_rate
      refute_includes Rate.not_deleted, deleted_rate
      assert_includes Rate.deleted, deleted_rate
      refute_includes Rate.deleted, live_rate
    end
  end

  context 'after save' do
    should 'recalculate all of the cached cost of all Time Entries for the user' do
      @user = User.generate!
      @project = Project.generate!
      @date = Time.zone.today.to_s
      @past_date = 1.month.ago.strftime('%Y-%m-%d')
      @rate = Rate.generate!(user: @user, project: @project, date_in_effect: @date, amount: 200.0)
      @time_entry1 = TimeEntry.generate!(user: @user,
                                         project: @project,
                                         spent_on: @date,
                                         hours: 10.0,
                                         activity: TimeEntryActivity.generate!)
      @time_entry2 = TimeEntry.generate!(user: @user,
                                         project: @project,
                                         spent_on: @past_date,
                                         hours: 20.0,
                                         activity: TimeEntryActivity.generate!)

      assert_equal 2000.00, @time_entry1.cost
      assert_equal 0, @time_entry2.cost

      @old_rate = Rate.generate!(user: @user, project: @project, date_in_effect: 2.months.ago.strftime('%Y-%m-%d'), amount: 10.0)

      assert_equal 2000.00, TimeEntry.find(@time_entry1.id).cost
      assert_equal 200.00, TimeEntry.find(@time_entry2.id).cost
    end
  end

  context 'after destroy' do
    should 'recalculate all of the cached cost of all Time Entries for the user' do
      @user = User.generate!
      @project = Project.generate!
      @date = Time.zone.today.to_s
      @past_date = 1.month.ago.strftime('%Y-%m-%d')
      @rate = Rate.generate!(user: @user, project: @project, date_in_effect: @date, amount: 200.0)
      @old_rate = Rate.generate!(user: @user, project: @project, date_in_effect: 2.months.ago.strftime('%Y-%m-%d'), amount: 10.0)

      @time_entry1 = TimeEntry.generate!(user: @user,
                                         project: @project,
                                         spent_on: @date,
                                         hours: 10.0,
                                         activity: TimeEntryActivity.generate!)
      @time_entry2 = TimeEntry.generate!(user: @user,
                                         project: @project,
                                         spent_on: @past_date,
                                         hours: 20.0,
                                         activity: TimeEntryActivity.generate!)
      assert_equal 2000.00, @time_entry1.cost
      assert_equal @rate.id, @time_entry1.rate_id
      assert_equal 2000.00, @time_entry1.read_attribute(:cost)
      assert_equal 200.0, @time_entry2.cost
      assert_equal @old_rate.id, @time_entry2.rate_id
      assert_equal 200.0, @time_entry2.read_attribute(:cost)

      @old_rate.destroy

      assert_equal 2000.0, TimeEntry.find(@time_entry1.id).cost.to_f
      assert_equal @rate.id, TimeEntry.find(@time_entry1.id).rate_id
      assert_equal 0, TimeEntry.find(@time_entry2.id).cost.to_f
      assert_nil TimeEntry.find(@time_entry2.id).rate_id
    end
  end

  context '#for' do
    setup do
      @user = User.generate!
      @project = Project.generate!
      @date = '2009-01-01'
      @date = Date.new(Time.zone.today.year, 1, 1).to_s
      @default_rate = Rate.generate!(amount: 100.10, date_in_effect: @date, project: nil, user: @user)
      @rate = Rate.generate!(amount: 50.50, date_in_effect: @date, project: @project, user: @user)
    end

    context 'parameters' do
      should 'should be passed user' do
        assert_raises ArgumentError do
          Rate.for
        end
      end

      should 'can be passed an optional project' do
        assert_nothing_raised do
          Rate.for(@user)
        end

        assert_nothing_raised do
          Rate.for(@user, @project)
        end
      end

      should 'can be passed an optional date string' do
        assert_nothing_raised do
          Rate.for(@user)
        end

        assert_nothing_raised do
          Rate.for(@user, nil, @date)
        end
      end
    end

    context 'returns' do
      should 'a Rate object when there is a rate' do
        assert_equal @rate, Rate.for(@user, @project, @date)
      end

      should 'a nil when there is no rate' do
        assert @rate.destroy
        assert @default_rate.destroy
        assert_nil Rate.for(@user, @project, @date)
      end
    end

    context 'with a user, project, and date' do
      should 'should find the rate for a user on the project before the date' do
        assert_equal @rate, Rate.for(@user, @project, @date)
      end

      should 'should return the most recent rate found' do
        assert_equal @rate, Rate.for(@user, @project, @date)
      end

      should 'should check for a default rate if no rate is found' do
        assert @rate.destroy

        assert_equal @default_rate, Rate.for(@user, @project, @date)
      end

      should 'should return nil if no set or default rate is found' do
        assert @rate.destroy
        assert @default_rate.destroy
        assert_nil Rate.for(@user, @project, @date)
      end
    end

    context 'with a user and project' do
      should 'should find the rate for a user on the project before today' do
        assert_equal @rate, Rate.for(@user, @project)
      end

      should 'should return the most recent rate found' do
        assert_equal @rate, Rate.for(@user, @project)
      end

      should 'should return nil if no set or default rate is found' do
        assert @rate.destroy
        assert @default_rate.destroy
        assert_nil Rate.for(@user, @project)
      end
    end

    context 'with a user' do
      should 'should find the rate without a project for a user on the project before today' do
        assert_equal @default_rate, Rate.for(@user)
      end

      should 'should return the most recent rate found' do
        assert_equal @default_rate, Rate.for(@user)
      end

      should 'should return nil if no set or default rate is found' do
        assert @rate.destroy
        assert @default_rate.destroy
        assert_nil Rate.for(@user)
      end
    end

    should 'with an invalid user should raise an InvalidParameterException' do
      object = Object.new
      assert_raises Rate::InvalidParameterException do
        Rate.for(object)
      end
    end

    should 'with an invalid project should raise an InvalidParameterException' do
      object = Object.new
      assert_raises Rate::InvalidParameterException do
        Rate.for(@user, object)
      end
    end

    should 'with an invalid object for date should raise an InvalidParameterException' do
      object = Object.new
      assert_raises Rate::InvalidParameterException do
        Rate.for(@user, @project, object)
      end
    end

    should 'with an invalid date string should raise an InvalidParameterException' do
      assert_raises Rate::InvalidParameterException do
        Rate.for(@user, @project, '2000-13-40')
      end
    end
  end

  context '#update_all_time_entries_with_missing_cost' do
    setup do
      @user = User.generate!
      @project = Project.generate!
      @date = Time.zone.today.to_s
      @rate = Rate.generate!(user: @user, project: @project, date_in_effect: @date, amount: 200.0)
      @time_entry1 = TimeEntry.generate!(user: @user,
                                         project: @project,
                                         spent_on: @date,
                                         hours: 10.0,
                                         activity: TimeEntryActivity.generate!)
      @time_entry2 = TimeEntry.generate!(user: @user,
                                         project: @project,
                                         spent_on: @date,
                                         hours: 20.0,
                                         activity: TimeEntryActivity.generate!)
    end

    should 'update the caches of all Time Entries' do
      TimeEntry.update_all cost: nil
      Rate.update_all_time_entries_with_missing_cost
      assert_empty TimeEntry.where cost: nil
    end

    should 'timestamp a successful run' do
      assert_nil RedmineRate.settings[:last_caching_run]

      Rate.update_all_time_entries_with_missing_cost

      assert RedmineRate.settings[:last_caching_run], 'Last run not timestamped'
      assert Time.zone.parse(RedmineRate.settings[:last_caching_run]), 'Last run timestamp not parseable'
    end
  end

  context '#update_all_time_entries_to_refresh_cache' do
    setup do
      @user = User.generate!
      @project = Project.generate!
      @date = Time.zone.today.to_s

      # Get rid of the fixtures we load in our test_helper since they have no cost
      TimeEntry.delete_all

      @time_entry1 = TimeEntry.generate!(user: @user,
                                         project: @project,
                                         spent_on: @date,
                                         billable: true,
                                         hours: 10.0,
                                         activity: TimeEntryActivity.generate!)
      @time_entry2 = TimeEntry.generate!(user: @user,
                                         project: @project,
                                         spent_on: @date,
                                         billable: true,
                                         hours: 20.0,
                                         activity: TimeEntryActivity.generate!)
      @rate = Rate.generate!(user: @user, project: @project, date_in_effect: @date, amount: 200.0)
    end

    should 'update the caches of all Time Entries' do
      assert_empty TimeEntry.where cost: nil
      Rate.update_all_time_entries_to_refresh_cache
      assert_empty TimeEntry.where cost: nil
    end

    should 'timestamp a successful run' do
      assert_nil RedmineRate.settings[:last_cache_clearing_run]

      Rate.update_all_time_entries_to_refresh_cache

      assert RedmineRate.settings[:last_cache_clearing_run], 'Last run not timestamped'
      assert Time.zone.parse(RedmineRate.settings[:last_cache_clearing_run]), 'Last run timestamp not parseable'
    end
  end
end
