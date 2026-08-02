# frozen_string_literal: true

module Api
  module V1
    # Day-wise audit-log browsing for a tenant's admins (ADR-0007). Reads the
    # durable Mongo store, scoped to the current tenant.
    class ActivityLogsController < TenantBaseController
      # GET /api/v1/activity_logs?date=YYYY-MM-DD  (a day's logs, default today)
      # GET /api/v1/activity_logs?nl=...           (natural-language search)
      # GET /api/v1/activity_logs?q=...            (keyword search)
      def index
        authorize :activity_log, :index?

        text = params[:nl].presence || params[:q].presence
        if text
          result = Audit::LogViewer.search(
            text: text,
            tenant_id: Current.tenant.id,
            include_files: Current.user&.super_admin? || false # file logs: platform admins only
          )
          render json: {
            query: text,
            interpreted_filter: result.filter, # shows how the NL query was understood
            count: result.entries.size,
            entries: result.entries.map { |entry| present_entry(entry) }
          }
        else
          date = params[:date].presence || Date.current.iso8601
          logs = Audit::ActivityLogStore.current.for_day(date, tenant_id: Current.tenant.id)
          render json: { date: date, count: logs.size, logs: logs.map { |log| present(log) } }
        end
      end

      # GET /api/v1/activity_logs/summary  — count of logs per day
      def summary
        authorize :activity_log, :summary?
        render json: { days: Audit::ActivityLogStore.current.day_counts(tenant_id: Current.tenant.id) }
      end

      private

      def present(log)
        {
          action: log["action"],
          actor_type: log["actor_type"],
          actor_id: log["actor_id"],
          resource_type: log["resource_type"],
          resource_id: log["resource_id"],
          metadata: log["metadata"],
          occurred_at: log["occurred_at"]
        }
      end

      # Normalized viewer entry (may come from Mongo or a file source).
      def present_entry(entry)
        {
          source: entry["source"],
          action: entry["action"],
          message: entry["message"],
          actor_type: entry["actor_type"],
          actor_id: entry["actor_id"],
          resource_type: entry["resource_type"],
          resource_id: entry["resource_id"],
          metadata: entry["metadata"],
          occurred_at: entry["occurred_at"]
        }
      end
    end
  end
end
