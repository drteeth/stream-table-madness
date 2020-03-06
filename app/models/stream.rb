class Stream < ApplicationRecord
  before_create do
    self.uuid = SecureRandom.uuid
  end
end
