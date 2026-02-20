# Aligns search_logs with PhraseConverterService output payload.
class UpdateSearchLogsForPhraseConverter < ActiveRecord::Migration[7.2]
  def change
    change_table :search_logs, bulk: true do |t|
      t.remove_references :rephrase, foreign_key: true
      t.string :converted_text, null: false, default: ""
      t.integer :category_id, null: false, default: 0
      t.integer :hit_type, null: false, default: 2
      t.boolean :safety_mode_applied, null: false, default: false
      t.index :category_id
      t.index :hit_type
    end
  end
end
