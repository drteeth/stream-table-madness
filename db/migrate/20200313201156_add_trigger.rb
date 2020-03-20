class AddTrigger < ActiveRecord::Migration[6.0]
  def up
    create_table :event_stream_ids, id: false do |t|
      t.bigint :id, null: false
    end

    execute <<~SQL
      ALTER TABLE event_stream_ids ADD CONSTRAINT event_stream_ids_pkey PRIMARY KEY (id);
    SQL

    create_table :events_queue, id: false do |t|
      t.bigint :event_record_id, null: false, index: { unique: true }
    end

    create_table :event_streams, id: false do |t|
      t.bigint :id, null: false, index: { unique: true }
      t.bigint :event_record_id, null: false, index: { unique: true }
    end

    execute <<~SQL
      ALTER TABLE event_streams ADD CONSTRAINT event_streams_pkey PRIMARY KEY (id);
    SQL

    ActiveRecord::Base.connection.execute(<<~SQL)
      INSERT INTO event_stream_ids (id) VALUES (0);

      CREATE FUNCTION queue_event_for_stream() RETURNS TRIGGER
        LANGUAGE plpgsql
        AS $$
        BEGIN
          INSERT INTO events_queue (event_record_id)
            VALUES (NEW.id);
          return null;
        END;
        $$;
      CREATE TRIGGER queue_event_for_stream AFTER INSERT ON event_records FOR EACH ROW EXECUTE PROCEDURE queue_event_for_stream();
    SQL
  end

  def down
    ActiveRecord::Base.connection.execute("drop trigger queue_event_for_stream on event_records;")
    ActiveRecord::Base.connection.execute("drop function queue_event_for_stream();")
    drop_table :event_streams
    drop_table :events_queue
    drop_table :event_stream_ids
  end
end
