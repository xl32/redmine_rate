require_dependency 'time_entry'

module RedmineRate
  module Patches
    module TimeEntryPatch
      def self.included(base)
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)
        base.class_eval do
          belongs_to :rate
          after_initialize :initialize_billable
          before_save :set_billable
          before_save :recalculate_cost

          safe_attributes 'billable'
        end
      end

      module ClassMethods
        # Updated the cached cost of all TimeEntries for user and project
        def update_cost_cache(user, project = nil)
          c = { user_id: user }
          c[:project_id] = project unless project.nil?
          where(c).each(&:recalculate_cost!)
        end
      end

      module InstanceMethods
        # Returns the current cost of the TimeEntry based on it's
        # billable rate and hours.
        def cost
          cost = read_attribute(:cost)
          return cost if cost
          ci = costinfo
          write_attribute(:cost, ci[:cost])
        end

        def rate_id
          rate_id = read_attribute(:rate_id)
          return rate_id if rate_id
          ci = costinfo
          write_attribute(:rate_id, ci[:rate_id])
        end

        # Updates the cost attribute with the recalculated cost value.
        def recalculate_cost!
          ci = costinfo
          update_columns(cost: ci[:cost], rate_id: ci[:rate_id])
        end

        # Writes the cost attribute to the model instance with the
        # recalculated cost value.
        def recalculate_cost
          ci = costinfo
          # do not add rate_id here, it is updated automatically!
          write_attribute(:cost, ci[:cost])
        end

        private

        def initialize_billable
          return unless new_record?
          self.billable = RedmineRate.setting?(:billable_default)
        end

        def set_billable
          return true if User.current.allowed_to?(:activate_billable, project)
          self.billable = RedmineRate.setting?(:billable_default)
          true
        end

        # Returns the cost for this time entry depending on rates set
        # and whether this time entry is billable or not.
        def costinfo
          info = { rate_id: nil, cost: 0.0 }
          return info unless billable

          # A soft-deleted rate must be treated the same as no rate at all,
          # even though the belongs_to association still resolves it (the row
          # is still there) -- otherwise a deleted rate would keep pricing
          # every time entry that happened to already reference it.
          if rate.nil? || rate.deleted?
            r = Rate.for(user, project, spent_on.to_s)
            return info unless r
            rate_id = r.id
            amount = r.amount
          else
            rate_id = rate.id
            amount = rate.amount
          end

          return info if amount.blank?
          { rate_id: rate_id, cost: amount.to_f * hours.to_f }
        end
      end
    end
  end
end

unless TimeEntry.included_modules.include?(RedmineRate::Patches::TimeEntryPatch)
  TimeEntry.send(:include, RedmineRate::Patches::TimeEntryPatch)
end
