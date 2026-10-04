class LandingPublication < ApplicationRecord
  belongs_to :landing_page
  has_many_attached :assets
end
