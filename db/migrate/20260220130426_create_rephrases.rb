class CreateRephrases < ActiveRecord::Migration[7.2]
  def change
    create_table :rephrases do |t|
      t.text :content, null: false
      t.references :category, null: false, foreign_key: true

      t.timestamps
    end
  end
end
