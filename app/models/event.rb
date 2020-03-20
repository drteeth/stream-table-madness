class Event < ApplicationRecord
  # after_commit do |e|
  #   pp "Commited #{e.event_type}"
  # end
  #
  self.table_name = 'event_records'
end
