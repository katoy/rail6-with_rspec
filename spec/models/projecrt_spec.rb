# frozen_string_literal: true

require 'rails_helper'
require 'database_cleaner'

RSpec.describe Project, type: :model do
  shared_context 'project time_travel' do
    before do
      travel_to the_time
      freeze_time
    end
    after do
      unfreeze_time
      travel_back
    end
  end

  shared_context 'project create projects' do
    let!(:projects) do
      2.times.map do |idx|
        create(
          :project,
          id: idx + 1,
          name: "Project #{idx + 1}",
          description: "Test project #{idx + 1}."
        )
      end
    end
    let(:expect_lines) do
      '"id","name","description"' + "\n" \
      '"1","Project 1","Test project 1."' + "\n" \
      '"2","Project 2","Test project 2."' + "\n"
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

  context '#csv_name' do
    subject { Project.csv_name }
    let(:the_time) { Time.zone.parse('2020-01-02 08:59:59') }
    include_context 'project time_travel'
    let(:expect_csv_name) do
      "#{Rails.root}/csvs/projects_2020-01-02_08_59_59_000JST.csv"
    end

    it { is_expected.to eq expect_csv_name }
  end

  context '#to_csv_by_sql' do
    subject { Project.to_csv_by_sql }
    include_context 'project create projects'

    let!(:the_time) { Time.zone.parse('2020-01-02 08:59:00') }
    include_context 'project time_travel'
    before do
      File.delete(Project.csv_name) if File.exist?(Project.csv_name)
    end

    it do
      subject
      expect(File.read(Project.csv_name)).to eq expect_lines
    end
  end

  context '#to_csv' do
    subject { Project.to_csv }
    include_context 'project create projects'
    let(:bomed_expect_lines) { "\uFEFF" + expect_lines }

    let!(:the_time) { Time.zone.parse('2020-01-02 08:59:01') }
    include_context 'project time_travel'

    context 'check contents with file' do
      before do
        File.delete(Project.csv_name) if File.exist?(Project.csv_name)
      end

      it 'contents of csv file' do
        subject
        expect(File.read(Project.csv_name)).to eq bomed_expect_lines
      end
    end

    context 'check contents without file' do
      let(:buffer) { StringIO.new }
      before do
        allow(File).to receive(:open)
          .with(Project.csv_name, 'w:UTF-8')
          .and_yield(buffer)
      end

      it 'contents of csv file' do
        subject
        expect(buffer.string).to eq bomed_expect_lines
      end
    end
  end
end
