# Cross-Origin Resource Sharing (CORS) for the React SPA.
#
# Configured fully in Milestone 3 (commit 3.5) with an allow-list of tenant
# subdomain origins. Left as a template here. To enable: uncomment `rack-cors`
# in the Gemfile, then this block.
#
# Rails.application.config.middleware.insert_before 0, Rack::Cors do
#   allow do
#     origins ENV.fetch("FRONTEND_ORIGINS", "http://localhost:5173").split(",")
#     resource "*",
#       headers: :any,
#       methods: %i[get post put patch delete options head],
#       expose: %w[Authorization],
#       credentials: false
#   end
# end
