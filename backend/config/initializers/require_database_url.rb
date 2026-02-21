# frozen_string_literal: true

if Rails.env.production? && ENV["DATABASE_URL"].to_s.empty?
  raise "DATABASE_URL is required in production"
end