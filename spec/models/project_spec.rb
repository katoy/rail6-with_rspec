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
          description: "Test project #{idx + 1}.",
          created_at: the_time,
          updated_at: the_time
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

  it "has a valid factory" do
    expect(build(:project)).to be_valid
  end

  it { is_expected.to validate_presence_of :name }
  it { is_expected.to validate_uniqueness_of(:name) }
  it { is_expected.to have_many(:users).through(:project_user_relations) }

  it 'is valid with name' do
    project = Project.new(name: 'Aaron')
    expect(project).to be_valid
  end

  it 'is invalid without name' do
    project = build(:project, name: nil)
    project.valid?
    expect(project.errors[:name]).to include("can't be blank")
  end

  it { is_expected.to validate_uniqueness_of(:name) }

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

  context "#export" do
    subject { Project.export(file_path) }
    include_context 'project create projects'

    let!(:the_time) { Time.zone.parse('2020-01-02 08:59:00') }
    include_context 'project time_travel'
    let(:expect_lines) do
      time_stamps = '"2020-01-02 08:59:00.000000","2020-01-02 08:59:00.000000"'
      [
        '"id","name","description","due_on","created_at","updated_at"' + "\n",
        '"1","Project 1","Test project 1.","",' + time_stamps + "\n",
        '"2","Project 2","Test project 2.","",' + time_stamps + "\n",
        '"3","Project 3","Test project 3.","",' + time_stamps + "\n"
      ]
    end
    before do
      File.delete(file_path) if File.exist?(file_path)
      subject
    end

    context "no opts" do
      let(:file_path) { "#{Rails.root}/csvs/export_projects.csv" }
      let(:recoreds) { nil }
      let(:expect_contents) { expect_lines.join("") }

      it { expect(File.read(file_path)).to eq expect_contents }
    end
  end

  context "#import_by_sql" do
    subject { Project.import_by_sql(file_path) }

    context "with real file" do
      let(:file_path) { "spec/fixtures/export_projects.csv" }
      let(:expect_attrs) do
        # csv の値 + 9:00 が DB に設定される (CSV は JST, DB は UTCの為)
        time_stamp = Time.zone.parse("2020-01-02 17:59:00")
        [
          { id: 1, name: "Project 1", due_on: nil,
            description: "テスト 1",
            created_at: time_stamp, updated_at: time_stamp },
          { id: 2, name: "Project 2", due_on: nil,
            description: 'テスト 2 “暫定”',
            created_at: time_stamp, updated_at: time_stamp },
          { id: 3, name: "Project 3", due_on: nil,
            description: "テスト 3\n(暫定)",
            created_at: time_stamp, updated_at: time_stamp }
        ]
      end
      before do
        Project.destroy_all
        subject
      end

      it do
        expect(Project.order(:id).map { |x| x.attributes.symbolize_keys })
          .to eq expect_attrs
      end
    end
  end

  context "#import" do
    subject { Project.import(file_path) }
    let(:file_path) { "filename" }

    context "with real file" do
      let(:file_path) { "spec/fixtures/export_projects.csv" }
      let(:expect_attrs) do
        time_stamp = Time.zone.parse("2020-01-02 08:59:00")
        [
          { id: 1, name: "Project 1", due_on: nil,
            description: "テスト 1",
            created_at: time_stamp, updated_at: time_stamp },
          { id: 2, name: "Project 2", due_on: nil,
            description: 'テスト 2 “暫定”',
            created_at: time_stamp, updated_at: time_stamp },
          { id: 3, name: "Project 3", due_on: nil,
            description: "テスト 3\n(暫定)",
            created_at: time_stamp, updated_at: time_stamp }
        ]
      end
      before do
        Project.destroy_all
        subject
      end

      it do
        expect(Project.order(:id).map { |x| x.attributes.symbolize_keys })
          .to eq expect_attrs
      end
    end

    context "without real file" do
      let(:file) do
        CSV.generate do |csv|
          rows.each { |row| csv << row }
        end
      end
      before do
        expect(File).to receive(:open)
          .with('filename', 'r', { headers: true, universal_newline: false })
          .and_return(file)
        subject
      end

      context "has no data rows" do
        let(:rows) { [%w[id name description]] }

        it { expect(Project.count).to eq 0 }
      end

      context "has 2 data rows" do
        let(:rows) do
          [
            %w[id name description due_on created_at updated_at],
            [1, 'Project_1', 'Test_1'],
            [2, 'Project_2', 'Test_2']
          ]
        end

        it do
          expect(Project.count).to eq 2
          expect(
            Project.order(:id).pluck(:id, :name, :description)
          ).to eq [rows[1], rows[2]]
        end
      end
    end
  end

  context "#import_x" do
    subject { Project.import_x(file_path) }
    let(:file_path) { "filename" }

    context "with real file" do
      let(:file_path) { "spec/fixtures/export_projects.csv" }
      let(:expect_attrs) do
        time_stamp = Time.zone.parse("2020-01-02 08:59:00")
        [
          { id: 1, name: "Project 1", due_on: nil,
            description: "テスト 1",
            created_at: time_stamp, updated_at: time_stamp },
          { id: 2, name: "Project 2", due_on: nil,
            description: 'テスト 2 “暫定”',
            created_at: time_stamp, updated_at: time_stamp },
          { id: 3, name: "Project 3", due_on: nil,
            description: "テスト 3\n(暫定)",
            created_at: time_stamp, updated_at: time_stamp }
        ]
      end
      before do
        Project.destroy_all
        subject
      end

      it do
        expect(Project.order(:id).map { |x| x.attributes.symbolize_keys })
          .to eq expect_attrs
      end
    end

    context "without real file" do
      let(:file) do
        CSV.generate do |csv|
          rows.each { |row| csv << row }
        end
      end
      before do
        expect(File).to receive(:open)
          .with('filename', 'r', { headers: true, universal_newline: false })
          .and_return(file)
        subject
      end

      context "has no data rows" do
        let(:rows) { [%w[id name description]] }

        it { expect(Project.count).to eq 0 }
      end

      context "has 2 data rows" do
        let(:rows) do
          [
            %w[id name description due_on created_at updated_at],
            [1, 'Project_1', 'Test_1'],
            [2, 'Project_2', 'Test_2']
          ]
        end

        it do
          expect(Project.count).to eq 2
          expect(
            Project.order(:id).pluck(:id, :name, :description)
          ).to eq [rows[1], rows[2]]
        end
      end
    end
  end
end
