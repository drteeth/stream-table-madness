require "ap"

# Solutions
# -------------
# A) stream_events table with predicate locks <-- Modify Sequent
# B) add a write lock on the events table <--- Modify Sequent
# C) something else
#    * after_commit => pseudo stream table <--- reliability--
#    * trigger => streams table    <---------- THIS ONE MOTHERTRUCKERS <-- latency++
#
#    * WAL following/logical replication => fill out a stream table <-- complexity+++++++++ <---
#    * => guaranteed to run.
#    * =>
#
#    * Redis Streams => fill out a streams table
#    * PG Listen/Publish => fill out a streams table
#
#   # Single/Multiple readers that copy events out of the event queue table
#    * event_queue ID into event_queue (with xmin timestamps) <--
#    * workers that move things from out of the event queue

class Meow
  include Concurrent::Async

  attr_reader :promises

  def initialize(all_stream, publisher)
    @all_stream = all_stream
    @publisher = publisher
    @promises = []
  end

  def link(stream, event)
    sql = <<-SQL
          WITH
            stream AS (
              UPDATE streams SET version = version + 1
              WHERE streams.id = #{stream.id}
              RETURNING version - 1 as initial_stream_version
            ),
            event_records (index, event_id) AS (VALUES (1, '#{event.id}'::uuid))
          INSERT INTO stream_events
            (
              event_id,
              stream_id,
              stream_version
            )
          SELECT
            event_records.event_id,
            #{stream.id},
            stream.initial_stream_version + event_records.index
          FROM event_records, stream;
    SQL

    ActiveRecord::Base.connection.execute(sql)
  end

  def append(stream, label, delay)
    event = Event.transaction do
      print '.'
      event = Event.create!(event_type: label)

      # link(stream, event)
      # link(@all_stream, event)
      sleep(delay)

      puts "Created #{label}"
      event
    end
    @promises = @publisher.async.publish(event)
  end
end

class EventPublisher
  include Concurrent::Async

  attr_reader :order

  def initialize
    @order = []
    @last_seen = 0
  end

  def publish(event)
    # THIS IS ASYNC OK SO DONT BE TOO FUCKY WITH THE IVARS
    connection = ActiveRecord::Base.connection
    begin
      connection.query_value('select pg_advisory_lock(4191514917)');

      event_record_ids = queued_events(connection)
      while event_record_ids.any?
        count = event_record_ids.count

        params = event_record_ids.each_with_index.map { |eid, i|
          "(#{eid}, #{i + 1})"
        }.join(', ')

        connection.transaction do
          connection.execute <<-SQL
            WITH stream AS (
              UPDATE event_stream_ids SET id = id + #{count}
              RETURNING id - #{count} AS original_id
            ),
            events (event_record_id, index) AS (
              VALUES #{params}
            )
            INSERT INTO event_streams (id, event_record_id)
              SELECT
                stream.original_id + events.index,
                events.event_record_id
              FROM events, stream;
          SQL

          connection.execute <<-SQL
            DELETE FROM events_queue
              WHERE (event_record_id) IN (#{event_record_ids.join(',')});
          SQL

          sleep(1.1)
        end

        event_record_ids = queued_events(connection)
      end
    ensure
      connection.query_value('select pg_advisory_unlock(4191514917)');
    end

    query = <<~SQL
      select event_streams.id, event_type
      from event_streams
      inner join event_records on event_records.id = event_streams.event_record_id
      where event_streams.id > #{@last_seen}
      order by event_streams.id
    SQL
    events = connection.exec_query(query).to_a

    events.each do |row|
      @order << row["event_type"]
      @last_seen = row["id"]
      pp order: order
    end
  rescue => e
    pp e
  end

  def queued_events(connection)
    connection.query_values <<~SQL
      SELECT event_record_id FROM events_queue ORDER BY event_record_id ASC LIMIT 1000
    SQL
  end
end

def read_stream(stream)
  sql = <<~SQL
    select event_type, event_streams.id, pg_xact_commit_timestamp(event_records.xmin) as tx
    from event_streams
    inner join event_records on event_records.id = event_streams.event_record_id
    order by event_streams.id
    ;
  SQL
  ActiveRecord::Base.connection.exec_query(sql).to_a.map(&:values).map { |a,b,c| "#{b} => #{a} => #{c}"}
end

desc 'taco'
task taco: :environment do
  Stream.transaction do
    ActiveRecord::Base.connection.execute('delete from stream_events;')
    Stream.delete_all
    Event.delete_all
  end

  streams = 3.times.map { Stream.create! }
  global = Stream.create!

  10.times do
    promises = 10.times.map do |i|
      stream = streams.sample
      Meow.new(global).async.append(stream, i, 1)
    end

    promises.map(&:wait!)
  end

  pp read_stream(gobal)
end

desc 'shit'
task shit: :environment do
  Stream.transaction do
    ActiveRecord::Base.connection.execute('delete from stream_events;')
    Stream.delete_all
    Event.delete_all
  end

  stream_a = Stream.create!
  stream_b = Stream.create!
  stream_c = Stream.create!
  global = Stream.create!
  publisher = EventPublisher.new

  # promises = 70.times.map { |i| Meow.new(global, publisher).async.append(stream_a, i.to_s, Random.rand(10)) }
  promises = []
  promises << Meow.new(global, publisher).async.append(stream_a, 'A1', 6)
  promises << Meow.new(global, publisher).async.append(stream_b, 'B1', 5)
  promises << Meow.new(global, publisher).async.append(stream_a, 'A2', 4)
  promises << Meow.new(global, publisher).async.append(stream_b, 'B2', 3)
  promises << Meow.new(global, publisher).async.append(stream_a, 'A3', 2)
  promises << Meow.new(global, publisher).async.append(stream_b, 'B3', 1)
  promises << Meow.new(global, publisher).async.append(stream_a, 'A4', 1)

  # promises << Meow.new(global).async.append(stream_a, 'A1', 1)
  # promises << Meow.new(global).async.append(stream_a, 'A2', 1)
  # promises << Meow.new(global).async.append(stream_a, 'A3', 1)
  # promises << Meow.new(global).async.append(stream_b, 'B1', 1)
  # promises << Meow.new(global).async.append(stream_b, 'B2', 1)
  # promises << Meow.new(global).async.append(stream_b, 'B3', 1)
  # promises << Meow.new(global).async.append(stream_c, 'C1', 1)
  # promises << Meow.new(global).async.append(stream_c, 'C2', 1)
  # promises << Meow.new(global).async.append(stream_c, 'C3', 1)

  promises.each do |p|
    p.add_observer do |_time, _result, error|
      pp error if error
    end
  end

  promises.each(&:wait)

  sleep(2)

  pp "done"
  pp publisher.order

  # state = nil
  # loop do
  #   global_order = read_stream(global)
  #
  #   if global_order != state
  #     state = global_order
  #     ap state
  #   end
  # end
end
