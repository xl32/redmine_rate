require_relative '../test_helper.rb'

# Test cases for the main Rate#for API
class RateForTest < ActiveSupport::TestCase
  context 'calculated for' do
    setup do
      @user = User.generate!
    end

    context 'a user with no Rates' do
      should 'should return nil' do
        assert_nil Rate.for(@user)
      end
    end

    context 'a user with one default Rate' do
      should 'should return the Rate if the Rate is effective today' do
        rate = Rate.create!(user_id: @user.id, amount: 100.0, date_in_effect: Time.zone.today)
        assert_equal rate, Rate.for(@user)
      end

      should 'should return nil if the Rate is not effective yet' do
        assert_nil Rate.for(@user)
      end

      should 'should return the same default Rate on all projects' do
        project = Project.generate!
        rate = Rate.create!(user_id: @user.id, amount: 100.0, date_in_effect: Time.zone.today)
        assert_equal rate, Rate.for(@user, project)
      end
    end

    context 'a user with two default Rates' do
      should 'should return the newest Rate before the todays date' do
        rate = Rate.create!(user_id: @user.id, amount: 300.0, date_in_effect: Time.zone.today)
        assert_equal rate, Rate.for(@user)
      end
    end

    context 'a user with a default Rate and Rate on a project' do
      should 'should return the project Rate if its effective today' do
        project = Project.generate!
        rate = Rate.create!(user_id: @user.id, project: project, amount: 100.0, date_in_effect: Date.yesterday)
        assert_equal rate, Rate.for(@user, project)
      end

      should 'should return the default Rate if the project Rate isnt effective yet but the default Rate is' do
        project = Project.generate!
        rate = Rate.create!(user_id: @user.id, amount: 300.0, date_in_effect: Time.zone.today)
        assert_equal rate, Rate.for(@user, project)
      end

      should 'should return nil if neither Rate is effective yet' do
        project = Project.generate!
        assert_nil Rate.for(@user, project)
      end
    end

    context 'a user with two Rates on a project' do
      should 'should return the newest Rate before the todays date' do
        project = Project.generate!
        rate = Rate.create!(user_id: @user.id, project: project, amount: 300.0, date_in_effect: Time.zone.today)
        assert_equal rate, Rate.for(@user, project)
      end
    end

    context 'a user with a soft-deleted Rate' do
      should 'should fall through to the default Rate when the project Rate is deleted' do
        project = Project.generate!
        default_rate = Rate.create!(user_id: @user.id, amount: 100.0, date_in_effect: Time.zone.today)
        project_rate = Rate.create!(user_id: @user.id, project: project, amount: 300.0, date_in_effect: Time.zone.today)
        assert project_rate.soft_delete

        assert_equal default_rate, Rate.for(@user, project)
      end

      should 'should skip a deleted Rate and fall back to the next-most-recent one' do
        older_rate = Rate.create!(user_id: @user.id, amount: 100.0, date_in_effect: 1.month.ago)
        newer_rate = Rate.create!(user_id: @user.id, amount: 200.0, date_in_effect: Time.zone.today)
        assert newer_rate.soft_delete

        assert_equal older_rate, Rate.for(@user)
      end

      should 'should return nil when the only Rate is deleted' do
        rate = Rate.create!(user_id: @user.id, amount: 100.0, date_in_effect: Time.zone.today)
        assert rate.soft_delete

        assert_nil Rate.for(@user)
      end

      should 'should return nil from amount_for when the only Rate is deleted' do
        rate = Rate.create!(user_id: @user.id, amount: 100.0, date_in_effect: Time.zone.today)
        assert rate.soft_delete

        assert_nil Rate.amount_for(@user)
      end
    end
  end
end
