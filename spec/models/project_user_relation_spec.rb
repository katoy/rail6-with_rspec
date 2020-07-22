# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProjectUserRelation, type: :model do
  shared_context 'project_user_relation time_travel' do
    before do
      travel_to the_time
      freeze_time
    end
    after do
      unfreeze_time
      travel_back
    end
  end

  shared_context 'project_user_relation create project_user_relations' do
    let!(:users) do
      4.times.map do |idx|
        create(
          :user,
          id: idx + 1,
          name: "User #{idx + 1}",
          email: "user_#{idx + 1}@example.com"
        )
      end
    end

    let!(:projects) do
      [
        create(:project, id: 1, name: "Project 1", description: "Test 1"),
        create(:project, id: 2, name: "Project 2", description: "Test 2"),
        create(:project, id: 3, name: "Project 3", description: "Test 3")
      ]
    end

    let!(:project_user_relations) do
      users[0].projects = [projects[0], projects[1], projects[2]]
      users[1].projects = [projects[0], projects[2]]
      users[2].projects = [projects[0]]
      users[3].projects = []
      users.each(&:save!)
      users.each(&:reload)
    end

    let(:expect_lines) do
      timestamps = '"2020-01-01 23:59:00.000000","2020-01-01 23:59:00.000000"'
      [
        '"id","project_id","user_id","created_at","updated_at"' + "\n",
        '"1","1","1",' + timestamps + "\n",
        '"2","1","2",' + timestamps + "\n",
        '"3","1","3",' + timestamps + "\n",
        '"4", 2","1",' + timestamps + "\n",
        '"5", 2","3",' + timestamps + "\n",
        '"6", 3","1",' + timestamps + "\n"
      ]
    end
  end

  it { is_expected.to validate_presence_of :project }
  it { is_expected.to validate_presence_of :user }

  context "#export" do
    subject { ProjectUserRelation.export(file_path) }

    let!(:the_time) { Time.zone.parse('2020-01-02 08:59:00') }
    include_context 'project_user_relation time_travel'
    include_context 'project_user_relation create project_user_relations'
    let(:expect_lines) do
      time_stamps = '"2020-01-02 08:59:00.000000","2020-01-02 08:59:00.000000"'
      [
        '"id","project_id","user_id","created_at","updated_at"' + "\n",
        '"1","1","1",' + time_stamps + "\n",
        '"2","2","1",' + time_stamps + "\n",
        '"3","3","1",' + time_stamps + "\n",
        '"4","1","2",' + time_stamps + "\n",
        '"5","3","2",' + time_stamps + "\n",
        '"6","1","3",' + time_stamps + "\n"
      ]
    end
    before do
      File.delete(file_path) if File.exist?(file_path)
      subject
    end

    context "no opts" do
      let(:file_path) { "#{Rails.root}/csvs/export_project_user_relations.csv" }
      let(:recoreds) { nil }
      let(:expect_contents) { expect_lines.join("") }

      it { expect(File.read(file_path)).to eq expect_contents }
    end
  end

  context "#import_by_sql" do
    subject { ProjectUserRelation.import_by_sql(file_path) }
    include_context 'project_user_relation create project_user_relations'
    before { ProjectUserRelation.delete_all }

    context "with real file" do
      let(:file_path) { "spec/fixtures/export_project_user_relations.csv" }
      let(:expect_attrs) do
        # csv の値 + 9:00 が DB に設定される (CSV は JST, DB は UTCの為)
        time_stamp = Time.zone.parse("2020-01-02 17:59:00")
        [
          {
            id: 1, project_id: 1, user_id: 1,
            created_at: time_stamp, updated_at: time_stamp
          },
          {
            id: 2, project_id: 2, user_id: 1,
            created_at: time_stamp, updated_at: time_stamp
          },
          {
            id: 3, project_id: 3, user_id: 1,
            created_at: time_stamp, updated_at: time_stamp
          },
          {
            id: 4, project_id: 1, user_id: 2,
            created_at: time_stamp, updated_at: time_stamp
          },
          {
            id: 5, project_id: 3, user_id: 2,
            created_at: time_stamp, updated_at: time_stamp
          },
          {
            id: 6, project_id: 1, user_id: 3,
            created_at: time_stamp, updated_at: time_stamp
          }
        ]
      end
      before do
        ProjectUserRelation.destroy_all
        subject
      end

      it do
        expect(
          ProjectUserRelation.order(:id)
            .map { |x| x.attributes.symbolize_keys }
        ).to eq expect_attrs
      end
    end
  end

  context "#import" do
    subject do
      ProjectUserRelation.delete_all
      ProjectUserRelation.import(file_path)
    end
    let(:file_path) { "filename" }
    include_context 'project_user_relation create project_user_relations'

    context "with real file" do
      let(:file_path) { "spec/fixtures/export_project_user_relations.csv" }
      let(:expect_attrs) do
        time_stamp = Time.zone.parse("2020-01-02 08:59:00")
        [
          {
            id: 1, project_id: 1, user_id: 1,
            created_at: time_stamp, updated_at: time_stamp
          },
          {
            id: 2, project_id: 2, user_id: 1,
            created_at: time_stamp, updated_at: time_stamp
          },
          {
            id: 3, project_id: 3, user_id: 1,
            created_at: time_stamp, updated_at: time_stamp
          },
          {
            id: 4, project_id: 1, user_id: 2,
            created_at: time_stamp, updated_at: time_stamp
          },
          {
            id: 5, project_id: 3, user_id: 2,
            created_at: time_stamp, updated_at: time_stamp
          },
          {
            id: 6, project_id: 1, user_id: 3,
            created_at: time_stamp, updated_at: time_stamp
          }
        ]
      end
      before { subject }

      it do
        expect(
          ProjectUserRelation.order(:id)
            .map { |x| x.attributes.symbolize_keys }
        ).to eq expect_attrs
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
        let(:rows) { [%w[id project_id user_id created_at updated_at]] }

        it { expect(ProjectUserRelation.count).to eq 0 }
      end

      context "has 2 data rows" do
        let(:rows) do
          time_stamp = '2020-01-02 08:59:00'
          [
            %w[id project_id user_id created_at updated_at],
            [1, 1, 1, time_stamp, time_stamp],
            [2, 2, 1, time_stamp, time_stamp],
            [3, 3, 1, time_stamp, time_stamp],
            [4, 1, 2, time_stamp, time_stamp],
            [5, 3, 2, time_stamp, time_stamp],
            [6, 1, 3, time_stamp, time_stamp]
          ]
        end
        let(:expected_attrs) do
          time_stamp = Time.zone.parse('2020-01-02 08:59:00')
          [
            { id: 1, project_id: 1, user_id: 1,
              created_at: time_stamp, updated_at: time_stamp },
            { id: 2, project_id: 2, user_id: 1,
              created_at: time_stamp, updated_at: time_stamp },
            { id: 3, project_id: 3, user_id: 1,
              created_at: time_stamp, updated_at: time_stamp },
            { id: 4, project_id: 1, user_id: 2,
              created_at: time_stamp, updated_at: time_stamp },
            { id: 5, project_id: 3, user_id: 2,
              created_at: time_stamp, updated_at: time_stamp },
            { id: 6, project_id: 1, user_id: 3,
              created_at: time_stamp, updated_at: time_stamp }
          ]
        end

        it do
          expect(ProjectUserRelation.count).to eq 6
          expect(
            ProjectUserRelation.order(:id).map do |x|
              x.attributes.symbolize_keys
            end
          ).to eq expected_attrs
        end
      end
    end
  end

  context "#import_x" do
    subject do
      ProjectUserRelation.destroy_all
      ProjectUserRelation.import_x(file_path)
    end
    let(:file_path) { "filename" }
    include_context 'project_user_relation create project_user_relations'
    before { ProjectUserRelation.delete_all }

    context "with real file" do
      let(:file_path) { "spec/fixtures/export_project_user_relations.csv" }
      let(:expect_attrs) do
        time_stamp = Time.zone.parse('2020-01-02 08:59:00')
        [
          { id: 1, project_id: 1, user_id: 1,
            created_at: time_stamp, updated_at: time_stamp },
          { id: 2, project_id: 2, user_id: 1,
            created_at: time_stamp, updated_at: time_stamp },
          { id: 3, project_id: 3, user_id: 1,
            created_at: time_stamp, updated_at: time_stamp },
          { id: 4, project_id: 1, user_id: 2,
            created_at: time_stamp, updated_at: time_stamp },
          { id: 5, project_id: 3, user_id: 2,
            created_at: time_stamp, updated_at: time_stamp },
          { id: 6, project_id: 1, user_id: 3,
            created_at: time_stamp, updated_at: time_stamp }
        ]
      end
      before { subject }

      it do
        expect(
          ProjectUserRelation.order(:id).map do |x|
            x.attributes.symbolize_keys
          end
        ).to eq expect_attrs
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
        let(:rows) { [%w[id project_id user_id created_at updated_at]] }

        it { expect(ProjectUserRelation.count).to eq 0 }
      end

      context "has 2 data rows" do
        time_stamp = '2020-01-02 08:59:00'
        let(:rows) do
          [
            %w[id project_id user_id created_at updated_at],
            [1, 1, 1, time_stamp, time_stamp],
            [2, 2, 1, time_stamp, time_stamp],
            [3, 3, 1, time_stamp, time_stamp],
            [4, 1, 2, time_stamp, time_stamp],
            [5, 3, 2, time_stamp, time_stamp],
            [6, 1, 3, time_stamp, time_stamp]
          ]
        end
        let(:expect_attrs) do
          time_stamp = Time.zone.parse('2020-01-02 08:59:00')
          [
            { id: 1, project_id: 1, user_id: 1,
              created_at: time_stamp, updated_at: time_stamp },
            { id: 2, project_id: 2, user_id: 1,
              created_at: time_stamp, updated_at: time_stamp },
            { id: 3, project_id: 3, user_id: 1,
              created_at: time_stamp, updated_at: time_stamp },
            { id: 4, project_id: 1, user_id: 2,
              created_at: time_stamp, updated_at: time_stamp },
            { id: 5, project_id: 3, user_id: 2,
              created_at: time_stamp, updated_at: time_stamp },
            { id: 6, project_id: 1, user_id: 3,
              created_at: time_stamp, updated_at: time_stamp }
          ]
        end

        it do
          expect(
            ProjectUserRelation.order(:id)
              .map { |x| x.attributes.symbolize_keys }
          ).to eq expect_attrs
        end
      end
    end
  end
end
