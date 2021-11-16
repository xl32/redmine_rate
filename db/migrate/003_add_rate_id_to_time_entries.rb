class AddRateIdToTimeEntries < ActiveRecord::Migration[4.2]
  def change
    add_reference :time_entries, :rate, index: true
  end
end
