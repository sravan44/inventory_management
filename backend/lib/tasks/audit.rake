# frozen_string_literal: true

namespace :audit do
  desc "Drain the Redis activity stream into MongoDB (long-running worker)"
  task drain: :environment do
    puts "[audit:drain] starting drainer #{Audit::StreamDrainer::CONSUMER}…"
    loop do
      count = Audit::StreamDrainer.drain_batch
      puts "[audit:drain] wrote #{count}" if count.positive?
    rescue StandardError => e
      warn "[audit:drain] #{e.class}: #{e.message}"
      sleep 1
    end
  end
end
