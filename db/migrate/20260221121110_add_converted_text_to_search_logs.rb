class AddConvertedTextToSearchLogs < ActiveRecord::Migration[7.2]
  def change
    add_column :search_logs, :converted_text, :text
  end
end
