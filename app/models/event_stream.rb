class EventStream < ApplicationRecord
  belongs_to :event_record, class_name: 'Event'
end
