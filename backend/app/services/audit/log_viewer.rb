# frozen_string_literal: true

module Audit
  # The pluggable log viewer (ADR-0016). Takes a natural-language (or keyword)
  # query, translates it to a sanitized filter, and runs it across the enabled
  # sources — the Mongo audit store (tenant-scoped) and, for platform admins, a
  # configured log FILE — then merges results newest-first.
  #
  # Any app can "plug and view": set AUDIT_LOG_FILE for the file source and/or
  # MONGO_URL for the Mongo source.
  class LogViewer
    Result = Struct.new(:filter, :entries, keyword_init: true)
    LIMIT = 200

    def self.search(text:, tenant_id:, include_files: false)
      raw = Audit::Llm.translate(text) || { "action_contains" => text.to_s }
      filter = Audit::LogSearch.sanitize(raw)

      entries = Sources::MongoSource.new.search(tenant_id: tenant_id, filter: filter)
      entries += Sources::FileSource.new.search(filter: filter) if include_files && Sources::FileSource.enabled?

      entries = entries.sort_by { |e| e["occurred_at"].to_s }.reverse.first(LIMIT)
      Result.new(filter: filter, entries: entries)
    end
  end
end
