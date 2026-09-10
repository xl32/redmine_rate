class AddDeletedOnToRates < ActiveRecord::Migration[4.2]
  def up
    # No index: every real lookup filters by user_id/project_id first (already
    # indexed by migration 001) with deleted_on IS NULL as a secondary
    # condition, and nothing sorts or filters on deleted_on alone.
    add_column :rates, :deleted_on, :datetime
  end

  def down
    remove_column :rates, :deleted_on
  end
end
