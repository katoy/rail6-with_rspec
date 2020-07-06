# frozen_string_literal: true

FactoryBot.define do
  factory :project do
    sequence(:name) { |n| "Project #{n}" }
    sequence(:description) { |n| "A test project #{n}." }
  end
end
