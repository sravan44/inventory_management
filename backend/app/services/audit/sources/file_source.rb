# frozen_string_literal: true

module Audit
  module Sources
    # "Plug-and-view" for any app's log FILE (ADR-0016). Point AUDIT_LOG_FILE at a
    # log path; this greps matching lines and best-effort-parses a leading
    # timestamp for date filtering. Global (not tenant-scoped), so it's only
    # surfaced to platform super-admins.
    class FileSource
      TIMESTAMP = /\A\[?(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2}:\d{2})/
      MAX_LINES = 200

      def self.path
        ENV["AUDIT_LOG_FILE"].presence
      end

      def self.enabled?
        path.present? && ::File.exist?(path)
      end

      def search(filter:)
        return [] unless self.class.enabled?

        needle = filter["action_contains"].to_s.downcase
        from = filter["date_from"]
        to = filter["date_to"]

        matches = ::File.foreach(self.class.path).filter_map do |line|
          next unless needle.blank? || line.downcase.include?(needle)

          occurred_at, day = parse_timestamp(line)
          next if from && day && day < from
          next if to && day && day > to

          entry(line, occurred_at)
        end

        matches.last(MAX_LINES)
      end

      private

      def parse_timestamp(line)
        match = line.match(TIMESTAMP)
        return [ nil, nil ] unless match

        [ "#{match[1]}T#{match[2]}", match[1] ]
      end

      def entry(line, occurred_at)
        {
          "source" => "file",
          "action" => nil,
          "message" => line.strip,
          "actor_type" => nil,
          "actor_id" => nil,
          "resource_type" => nil,
          "resource_id" => nil,
          "metadata" => {},
          "occurred_at" => occurred_at
        }
      end
    end
  end
end
