class AddTimestampsToRates < ActiveRecord::Migration[4.2]
  def up
    add_column :rates, :created_on, :datetime
    add_column :rates, :updated_on, :datetime
    add_index :rates, :updated_on

    # Rates created before this migration have no record of when they were entered.
    # date_in_effect is the closest thing the plugin ever stored, so use it as the
    # backfill value rather than stamping every historic row with the migration time.
    # Plain SQL keeps this portable across the MySQL/PostgreSQL/SQLite adapters
    # Redmine supports (all three implicitly widen a DATE to a DATETIME).
    execute <<-SQL.squish
      UPDATE #{Rate.table_name}
         SET created_on = date_in_effect,
             updated_on = date_in_effect
       WHERE created_on IS NULL
    SQL
  end

  def down
    remove_index :rates, :updated_on
    remove_column :rates, :updated_on
    remove_column :rates, :created_on
  end
end
