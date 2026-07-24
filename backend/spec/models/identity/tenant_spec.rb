require "rails_helper"

module Identity
  RSpec.describe Tenant, type: :model do
    describe "subdomain normalization" do
      it "downcases and strips surrounding whitespace before validation" do
        tenant = Tenant.new(name: "Acme", subdomain: "  Acme  ")
        tenant.valid?
        expect(tenant.subdomain).to eq("acme")
      end
    end

    describe "schema_name derivation" do
      it "derives schema_name from the subdomain on create" do
        tenant = Tenant.create!(name: "Acme", subdomain: "acme")
        expect(tenant.schema_name).to eq("tenant_acme")
      end

      it "does not overwrite an explicitly provided schema_name" do
        tenant = Tenant.create!(name: "Acme", subdomain: "acme", schema_name: "custom_acme")
        expect(tenant.schema_name).to eq("custom_acme")
      end
    end

    describe "validations" do
      it "rejects reserved subdomains" do
        tenant = Tenant.new(name: "X", subdomain: "www")
        expect(tenant).not_to be_valid
        expect(tenant.errors[:subdomain]).to include("is reserved")
      end

      it "rejects malformed subdomains" do
        tenant = Tenant.new(name: "X", subdomain: "Not Valid!")
        expect(tenant).not_to be_valid
      end

      it "rejects subdomains longer than 63 chars" do
        tenant = Tenant.new(name: "X", subdomain: "a" * 64)
        expect(tenant).not_to be_valid
      end

      it "enforces unique subdomain (case-insensitive via normalization)" do
        Tenant.create!(name: "A", subdomain: "acme")
        dup = Tenant.new(name: "B", subdomain: "ACME")
        expect(dup).not_to be_valid
        expect(dup.errors[:subdomain]).to include("has already been taken")
      end
    end

    describe "status" do
      it "defaults to pending_provisioning" do
        expect(Tenant.new.status).to eq("pending_provisioning")
      end
    end

    describe "soft delete" do
      it "marks deleted_at and excludes from .kept" do
        tenant = Tenant.create!(name: "A", subdomain: "acme")
        tenant.soft_delete!
        expect(tenant.deleted?).to be(true)
        expect(Tenant.kept).not_to include(tenant)
      end
    end
  end
end
