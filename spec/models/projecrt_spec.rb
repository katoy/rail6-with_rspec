# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Project, type: :model do
  shared_context "project clear and reset pk" do
    Project.destroy_all
    Project.reset_pk_sequence
  end

  shared_context "project time_travel" do
    before do
      travel_to the_time
      freeze_time
    end
    after do
      unfreeze_time
      travel_back
    end
  end

  it 'is valid with name' do
    project = Project.new(name: 'Aaron')
    expect(project).to be_valid
  end

  it 'is invalid without name' do
    project = build(:project, name: nil)
    project.valid?
    expect(project.errors[:name]).to include("can't be blank")
  end

  context ":csv_name" do
    subject{Project.csv_name}
    let(:the_time){Time.zone.parse('2020-01-02 08:59:59')}
    include_context "project time_travel"
    let(:expect_csv_name) do
      "#{Rails.root}/csvs/projects_2020-01-02_08_59_59_000JST.csv"
    end

    it{ is_expected.to eq expect_csv_name }
  end

  context ':to_csv_by_sql' do
    include_context "project clear and reset pk"
    let!(:projects){ create_list(:project, 2) }
    let!(:the_time){Time.zone.parse('2020-01-02 08:59:00')}
    include_context "project time_travel"
    before do
      File.delete(Project.csv_name) if File.exist?(Project.csv_name)
      Project.to_csv_by_sql
    end

    it do
      expect(File.exist?(Project.csv_name)).to eq true
      # TODO: ファイル内容を確認すること
    end
  end

  context ':to_csv' do
    include_context "project clear and reset pk"
    let!(:projects){ create_list(:project, 2) }
    let!(:the_time){Time.zone.parse('2020-01-02 08:59:01')}
    include_context "project time_travel"
    before do
      File.delete(Project.csv_name) if File.exist?(Project.csv_name)
      Project.to_csv
    end
    let(:expect_lines) do
      [
        "\uFEFF" + "id,name,description\n",
        "1,Project 3,A test project 4.\n",
        "2,Project 4,A test project 5.\n"
      ]
    end

    it "contents of csv file" do
      expect(File.open(Project.csv_name) { |f| p f.readlines })
        .to eq expect_lines
    end
  end
end
