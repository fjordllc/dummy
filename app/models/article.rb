class Article < ApplicationRecord
  paginates_per 10

  validates :title, presence: true
  validates :body, presence: true
end
