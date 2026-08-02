require "rails_helper"

module Audit
  RSpec.describe EmitActivityLogJob do
    include ActiveJob::TestHelper

    it "publishes the entry to the stream when performed" do
      attrs = ActivityLog.new(action: "product.created", occurred_at: "t").to_h.stringify_keys

      expect { perform_enqueued_jobs { described_class.perform_later(attrs) } }
        .to change { ActivityStream.redis.xlen(ActivityStream::STREAM_KEY) }.by(1)
    end
  end
end
