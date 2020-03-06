class CreateStreams < ActiveRecord::Migration[6.0]
  def change
    create_table :streams do |t|
      t.uuid :uuid, null: false
      t.integer :version, null: false, default: 0

      t.timestamps
    end
  end
end
