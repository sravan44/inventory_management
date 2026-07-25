# frozen_string_literal: true

# Base controller for the JSON API. Inherits ActionController::API (the lean
# base) even though the app is NOT api_only — so our API endpoints stay light
# (no cookies/session/CSRF) while the full middleware stack remains available to
# the separate web/admin controllers we add later (e.g. Admin::BaseController <
# ActionController::Base for a RailsAdmin/Avo surface).
#
# Health/apex endpoints inherit this directly; tenant-scoped endpoints inherit
# TenantScopedController (which adds tenant resolution).
class ApplicationController < ActionController::API
end
