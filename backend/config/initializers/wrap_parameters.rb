# Disable ActionController parameter wrapping. By default Rails wraps JSON request
# bodies under a key named after the controller (e.g. an AuthController would get
# an extra `auth: {...}` copy of the params). With our strict
# `action_on_unpermitted_parameters = :raise`, that surprise key causes spurious
# errors. We control our own param shapes, so turn wrapping off.
ActiveSupport.on_load(:action_controller) do
  wrap_parameters format: []
end
