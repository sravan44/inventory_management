# frozen_string_literal: true

# Abstract base for all models. `primary_abstract_class` tells Rails this is the
# parent that holds the database connection, so subclasses (including namespaced
# ones like Identity::User) inherit it.
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
