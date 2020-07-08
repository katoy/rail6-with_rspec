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
      3.times.map do |idx|
        create(
          :project,
          id: idx + 1,
          name: "Project #{idx + 1}",
          description: "Test project #{idx + 1}."
        )
      end
    end
    let(:expect_lines) do
      [
        '"id","name","description"' + "\n",
        '"1","Project 1","Test project 1."' + "\n",
        '"2","Project 2","Test project 2."' + "\n",
        '"3","Project 3","Test project 3."' + "\n"
      ]
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
    subject { Project.to_csv_by_sql(opts) }
    include_context 'project create projects'

    let!(:the_time) { Time.zone.parse('2020-01-02 08:59:00') }
    include_context 'project time_travel'
    before do
      File.delete(Project.csv_name) if File.exist?(Project.csv_name)
      subject
    end

    context "no opts" do
      let(:opts) { {} }
      let(:expect_contents) { expect_lines.join("") }

      it { expect(File.read(Project.csv_name)).to eq expect_contents }
    end

    context "with opts {offset: 1, limit: 2}" do
      let(:opts) { { offset: 1, limit: 2 } }
      let(:expect_contents) do
        expect_lines[0] + expect_lines[2] + expect_lines[3]
      end

      it { expect(File.read(Project.csv_name)).to eq expect_contents }
    end
  end

  context '#to_csv' do
    subject { Project.to_csv(opts) }
    include_context 'project create projects'

    let!(:the_time) { Time.zone.parse('2020-01-02 08:59:01') }
    include_context 'project time_travel'

    context "with opts {offset: 1, limit: 2}" do
      let(:opts) { { offset: 1, limit: 2 } }
      let(:bomed_expect_contents) do
        "\uFEFF" + expect_lines[0] + expect_lines[2] + expect_lines[3]
      end

      context 'check contents with file' do
        before do
          File.delete(Project.csv_name) if File.exist?(Project.csv_name)
          subject
        end

        it do
          expect(File.read(Project.csv_name)).to eq bomed_expect_contents
        end
      end

      context 'check contents without file' do
        let(:buffer) { StringIO.new }
        before do
          allow(File).to receive(:open)
            .with(Project.csv_name, 'w:UTF-8')
            .and_yield(buffer)
          subject
        end

        it do
          expect(buffer.string).to eq bomed_expect_contents
        end
      end
    end

    context "with opts {projects: Project.where(..)}" do
      let(:opts) do
        {
          projects: Project.where.not(id: 2).order(:id)
        }
      end
      let(:bomed_expect_contents) do
        "\uFEFF" + expect_lines[0] + expect_lines[1] + expect_lines[3]
      end
      before do
        File.delete(Project.csv_name) if File.exist?(Project.csv_name)
        subject
      end

      it do
        expect(File.read(Project.csv_name)).to eq bomed_expect_contents
      end
    end
  end
end
