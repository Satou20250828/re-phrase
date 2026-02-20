# Aligns search_logs with PhraseConverterService output payload.
class UpdateSearchLogsForPhraseConverter < ActiveRecord::Migration[7.2]
  def change
    remove_reference :search_logs, :rephrase, foreign_key: true

    add_column :search_logs, :converted_text, :string, null: false
    add_column :search_logs, :category_id, :integer, null: false
    add_column :search_logs, :hit_type, :integer, null: false, default: 2
    add_column :search_logs, :safety_mode_applied, :boolean, null: false, default: false

    add_index :search_logs, :category_id
    add_index :search_logs, :hit_type
  end
end
