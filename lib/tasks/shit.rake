require "ap"

class Meow
  include Concurrent::Async

  def initialize(all_stream)
    @all_stream = all_stream
  end

  def link(stream, event)
    sql = <<-SQL
          WITH
            stream AS (
              UPDATE streams SET version = version + 1
              WHERE streams.id = #{stream.id}
              RETURNING version - 1 as initial_stream_version
            ),
            events (index, event_id) AS (VALUES (1, '#{event.id}'::uuid))
          INSERT INTO stream_events
            (
              event_id,
              stream_id,
              stream_version
            )
          SELECT
            events.event_id,
            #{stream.id},
            stream.initial_stream_version + events.index
          FROM events, stream;
    SQL

    ActiveRecord::Base.connection.execute(sql)
  end

  def append(stream, label, delay)
    Event.transaction do
      print '.'
      event = Event.create!(event_type: label)

      link(stream, event)
      link(@all_stream, event)
      # sleep(delay)

      puts "Created #{label}"
    end
  end
end


def read_stream(stream)
  sql = <<~SQL
    select event_type, stream_version
    from stream_events
    inner join events on events.id = stream_events.event_id
    where stream_id = #{stream.id}
    order by stream_version
    ;
  SQL
  ActiveRecord::Base.connection.exec_query(sql).to_a.map(&:values).map(&:first)
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

  promises = []
  # promises << Meow.new.async.append(stream_a, 'A1', 6)
  # promises << Meow.new.async.append(stream_b, 'B1', 5)
  # promises << Meow.new.async.append(stream_a, 'A2', 4)
  # promises << Meow.new.async.append(stream_b, 'B2', 3)
  # promises << Meow.new.async.append(stream_a, 'A3', 2)
  # promises << Meow.new.async.append(stream_b, 'B3', 1)

  promises << Meow.new(global).async.append(stream_a, 'A1', 1)
  promises << Meow.new(global).async.append(stream_a, 'A2', 1)
  promises << Meow.new(global).async.append(stream_a, 'A3', 1)
  promises << Meow.new(global).async.append(stream_b, 'B1', 1)
  promises << Meow.new(global).async.append(stream_b, 'B2', 1)
  promises << Meow.new(global).async.append(stream_b, 'B3', 1)
  promises << Meow.new(global).async.append(stream_c, 'C1', 1)
  promises << Meow.new(global).async.append(stream_c, 'C2', 1)
  promises << Meow.new(global).async.append(stream_c, 'C3', 1)

  promises.each do |p|
    p.add_observer do |_time, _result, error|
      pp error if error
    end
  end

  promises.each(&:wait)

  # state = nil
  # loop do
  #   # event_order = ActiveRecord::Base.connection.exec_query('select event_type from events order_by_created_at').to_a.map(&:values)
  #   stream_a_order = read_stream(stream_a)
  #   stream_b_order = read_stream(stream_b)
  #   global_order = read_stream(global)
  #
  #   new_state = {
  #     A: stream_a_order,
  #     B: stream_b_order,
  #     G: global_order
  #   }
  #
  #   if new_state != state
  #     state = new_state
  #     ap state
  #   end
  # end
end
