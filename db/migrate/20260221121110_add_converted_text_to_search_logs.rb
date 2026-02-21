# Adds converted text column to search logs.
class AddConvertedTextToSearchLogs < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:search_logs, :converted_text)

    add_column :search_logs, :converted_text, :text
  end
end
