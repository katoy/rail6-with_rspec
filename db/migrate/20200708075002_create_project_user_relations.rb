class CreateProjectUserRelations < ActiveRecord::Migration[6.0]
  def change
    create_table :project_user_relations do |t|
      t.references :project, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true

      t.timestamps
    end

    add_index :project_user_relations, [:project_id, :user_id]
  end
end
