class CreateRates < ActiveRecord::Migration[4.2]
  def change
    create_table :rates do |t|
      t.decimal :amount, precision: 15, scale: 2
      t.references :user, null: false, index: true
      t.references :project, index: true
      t.date :date_in_effect, index: true
    end
  end
end
