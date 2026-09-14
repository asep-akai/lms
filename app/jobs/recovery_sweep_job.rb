class RecoverySweepJob < ApplicationJob
  queue_as :background

  def perform
    RecoverySweep.call!
  end
end
