require "rails_helper"

module Audit
  RSpec.describe LogSearch do
    it "keeps only allow-listed keys" do
      raw = {
        "action_contains" => "login",
        "actor_type" => "Identity::User",
        "date_from" => "2026-07-25",
        "date_to" => "2026-07-26",
        "evil" => { "$where" => "1==1" } # dropped
      }
      expect(described_class.sanitize(raw)).to eq(
        "action_contains" => "login",
        "actor_type" => "Identity::User",
        "date_from" => "2026-07-25",
        "date_to" => "2026-07-26"
      )
    end

    it "rejects a non-allow-listed actor_type" do
      expect(described_class.sanitize("actor_type" => "Product")).to eq({})
    end

    it "drops invalid dates" do
      expect(described_class.sanitize("date_from" => "not-a-date")).to eq({})
    end
  end
end
