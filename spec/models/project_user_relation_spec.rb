# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProjectUserRelation, type: :model do
  it { is_expected.to validate_presence_of :project}
  it { is_expected.to validate_presence_of :user }
end
