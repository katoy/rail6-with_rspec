# frozen_string_literal: true

# == Schema Information
#
# Table name: projects
#
#  id          :integer          not null, primary key
#  description :text
#  due_on      :date
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class Project < ApplicationRecord
  validates :name, presence: true, uniqueness: true
end
