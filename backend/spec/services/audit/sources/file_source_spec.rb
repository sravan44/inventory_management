require "rails_helper"
require "tempfile"

module Audit
  module Sources
    RSpec.describe FileSource do
      around do |example|
        file = Tempfile.new("applog")
        file.write(<<~LOG)
          2026-07-25T10:00:00 INFO started
          2026-07-25T10:01:00 ERROR something failed
          2026-07-26T09:00:00 INFO ok
        LOG
        file.flush
        ENV["AUDIT_LOG_FILE"] = file.path
        example.run
      ensure
        ENV.delete("AUDIT_LOG_FILE")
        file.close!
      end

      it "greps matching lines and tags them as file entries" do
        entries = described_class.new.search(filter: { "action_contains" => "error" })
        expect(entries.size).to eq(1)
        expect(entries.first["source"]).to eq("file")
        expect(entries.first["message"]).to include("something failed")
      end

      it "filters by parsed date range" do
        entries = described_class.new.search(filter: { "date_from" => "2026-07-26" })
        expect(entries.map { |e| e["message"] }).to eq([ "2026-07-26T09:00:00 INFO ok" ])
      end

      it "is disabled when no file is configured" do
        ENV.delete("AUDIT_LOG_FILE")
        expect(described_class.enabled?).to be(false)
        expect(described_class.new.search(filter: {})).to eq([])
      end
    end
  end
end
