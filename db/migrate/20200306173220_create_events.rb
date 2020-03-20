class CreateEvents < ActiveRecord::Migration[6.0]
  def change
    create_table :event_records do |t|
      t.string :event_type, null: false
      t.jsonb :data, null: false, default: {}

      t.timestamps
    end

    create_table :stream_events, id: false do |t|
      t.uuid :event_id, null: false
      t.integer :stream_id, null: false
      t.integer :stream_version, null: false
    end
  end
end
