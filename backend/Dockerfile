# syntax=docker/dockerfile:1
# Development image for the Rails API.
# Pinned to the same Ruby as .ruby-version so the container and any local
# tooling agree on the interpreter version.
FROM ruby:3.3.5-slim

# System packages needed to BUILD native gems and talk to Postgres:
#   build-essential      -> C compiler/toolchain (the `pg` gem compiles native code)
#   libpq-dev            -> Postgres client headers the `pg` gem links against
#   postgresql-client-16 -> pg_dump/psql binaries. Required at RUNTIME (not just
#                           build): schema_format = :sql shells out to pg_dump
#                           for db:schema:dump, and ros-apartment's use_sql
#                           adapter shells out to pg_dump to clone the public
#                           schema into each new tenant schema.
#                           MUST match the server's major version (postgres:16
#                           in docker-compose.yml) — pg_dump refuses to dump
#                           from a newer server than itself. Debian bookworm's
#                           default `postgresql-client` package is v15, so we
#                           pull v16 from the official PGDG apt repo instead.
#   git, curl            -> commonly needed by gems / tooling; curl also needed
#                           here to fetch the PGDG signing key
# We delete the apt cache in the same layer to keep the image small.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential libpq-dev git curl gnupg lsb-release && \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
      -o /usr/share/keyrings/postgresql.asc && \
    echo "deb [signed-by=/usr/share/keyrings/postgresql.asc] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y postgresql-client-16 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Speed up `bundle install`: install gems in parallel and retry transient network
# failures. (Docker still only re-runs the layer below when the Gemfile changes.)
ENV BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

# Install gems FIRST, before copying the app code.
# Docker caches this layer and only re-runs `bundle install` when the Gemfile
# (or lock) changes — so editing app code doesn't reinstall every gem.
# `Gemfile.lock*` (glob) makes the lock OPTIONAL, so the very first build works
# before any lock exists — `bundle install` then generates it inside the image.
COPY Gemfile Gemfile.lock* ./
RUN bundle install

# Copy the rest of the source (overridden by a bind-mount in dev, see compose).
COPY . .

# Bind to 0.0.0.0 (not localhost) so the port is reachable from the host machine.
EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
