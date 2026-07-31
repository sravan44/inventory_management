# frozen_string_literal: true

# Base policy (Pundit). DENY BY DEFAULT: every permission returns false unless a
# concrete policy overrides it. New resource policies (Milestone 4) subclass this
# and open up only what a role may do — you can never accidentally allow an action
# by forgetting to define it.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  # Scopes narrow a collection to what the user may see. Subclasses define
  # #resolve; the base intentionally raises so an unscoped query can't slip out.
  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end
end
