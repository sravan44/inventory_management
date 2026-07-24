# syntax=docker/dockerfile:1
# Development image for the Rails API.
# Pinned to the same Ruby as .ruby-version so the container and any local
# tooling agree on the interpreter version.
FROM ruby:3.3.5-slim

# System packages needed to BUILD native gems and talk to Postgres:
#   build-essential -> C compiler/toolchain (the `pg` gem compiles native code)
#   libpq-dev       -> Postgres client headers the `pg` gem links against
#   git, curl       -> commonly needed by gems / tooling
# We delete the apt cache in the same layer to keep the image small.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential libpq-dev git curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install gems FIRST, before copying the app code.
# Docker caches this layer and only re-runs `bundle install` when the Gemfile
# (or lock) changes — so editing app code doesn't reinstall every gem.
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy the rest of the source (overridden by a bind-mount in dev, see compose).
COPY . .

# Bind to 0.0.0.0 (not localhost) so the port is reachable from the host machine.
EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
