# frozen_string_literal: true

SimpleCov.start do
  enable_coverage :branch
  coverage_dir "reports/coverage"
  track_files "lib/**/*.rb"
  add_filter "/test/"
  minimum_coverage 90
end
