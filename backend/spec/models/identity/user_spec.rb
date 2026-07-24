require "rails_helper"

module Identity
  RSpec.describe User, type: :model do
    subject(:user) { User.new(email: "a@b.com", password: "secret123") }

    describe "password" do
      it "authenticates with the correct password and rejects a wrong one" do
        user.save!
        expect(user.authenticate("secret123")).to be_truthy
        expect(user.authenticate("wrong")).to be(false)
      end

      it "stores a bcrypt digest, never the raw password" do
        user.save!
        expect(user.password_digest).to be_present
        expect(user.password_digest).not_to include("secret123")
      end

      it "requires a password on create" do
        expect(User.new(email: "x@y.com")).not_to be_valid
      end
    end

    describe "email" do
      it "normalizes to stripped lowercase before validation" do
        u = User.new(email: "  A@B.COM ", password: "secret123")
        u.valid?
        expect(u.email).to eq("a@b.com")
      end

      it "rejects an invalid format" do
        user.email = "not-an-email"
        expect(user).not_to be_valid
      end

      it "enforces case-insensitive uniqueness" do
        User.create!(email: "a@b.com", password: "secret123")
        dup = User.new(email: "A@B.COM", password: "secret123")
        expect(dup).not_to be_valid
        expect(dup.errors[:email]).to include("has already been taken")
      end
    end

    describe "status" do
      it "defaults to active" do
        expect(User.new.status).to eq("active")
      end
    end

    describe "soft delete" do
      it "marks deleted_at and drops out of .kept" do
        user.save!
        user.soft_delete!
        expect(user.deleted?).to be(true)
        expect(User.kept).not_to include(user)
      end
    end
  end
end
