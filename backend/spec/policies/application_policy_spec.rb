require "rails_helper"

RSpec.describe ApplicationPolicy do
  subject(:policy) { described_class.new(nil, nil) }

  it "denies every action by default (fail-closed)" do
    expect(policy.index?).to be(false)
    expect(policy.show?).to be(false)
    expect(policy.create?).to be(false)
    expect(policy.new?).to be(false)
    expect(policy.update?).to be(false)
    expect(policy.edit?).to be(false)
    expect(policy.destroy?).to be(false)
  end

  it "requires subclasses to define a scope resolve" do
    scope = ApplicationPolicy::Scope.new(nil, nil)
    expect { scope.resolve }.to raise_error(NoMethodError)
  end
end
