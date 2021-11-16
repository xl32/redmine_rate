class AddBillableToTimeEntries < ActiveRecord::Migration[4.2]
  def change
    add_column :time_entries, :billable, :boolean, default: true, null: false, index: true
  end
end
