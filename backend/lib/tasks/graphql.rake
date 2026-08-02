# frozen_string_literal: true

namespace :graphql do
  namespace :schema do
    desc "Dump the GraphQL schema (SDL) to app/graphql/schema.graphql"
    task dump: :environment do
      path = Rails.root.join("app/graphql/schema.graphql")
      File.write(path, InventoryManagementSchema.to_definition)
      puts "Wrote #{path}"
    end
  end
end
