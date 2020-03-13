class AddTrigger < ActiveRecord::Migration[6.0]
  def up
    create_table :event_stream_ids, id: false do |t|
      t.integer :id, null: false, default: 0
    end

    create_table :event_streams, id: false do |t|
      t.integer :id, null: false, index: { unique: true }
      t.uuid :event_id, null: false, index: { unique: true }
    end

    ActiveRecord::Base.connection.execute(<<~SQL)
      insert into event_stream_ids (id) values (0);

      CREATE FUNCTION update_events_stream() RETURNS TRIGGER
        LANGUAGE plpgsql
        AS $$
        BEGIN
          WITH blerg AS (
            UPDATE event_stream_ids SET id = id + 1
            RETURNING id - 1 AS original_id
          )
          INSERT INTO event_streams (id, event_id)
          select blerg.original_id, NEW.id from blerg;
          return null;
        END;
        $$;

      CREATE TRIGGER update_events_stream AFTER INSERT ON events FOR EACH ROW EXECUTE PROCEDURE update_events_stream();
    SQL
  end

  def down
    ActiveRecord::Base.connection.execute("drop trigger update_events_stream;")
    ActiveRecord::Base.connection.execute("drop function update_events_stream();")
    drop_table :event_streams
    drop_table :event_stream_ids
  end
end
