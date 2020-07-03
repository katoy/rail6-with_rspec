# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Project, type: :model do
  it 'is valid with name' do
    project = Project.new(name: 'Aaron')
    expect(project).to be_valid
  end

  it 'is invalid without name' do
    project = build(:project, name: nil)
    project.valid?
    expect(project.errors[:name]).to include("can't be blank")
  end

  context ':to_csv_by_sql' do
    let!(:projects) { create_list(:project, 2) }
    it do
      Project.to_csv_by_sql
    end
  end

  context ':to_csv' do
    let!(:projects) { create_list(:project, 2) }
    it do
      Project.to_csv
    end
  end
end
