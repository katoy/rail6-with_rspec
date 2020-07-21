# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  shared_context 'user time_travel' do
    before do
      travel_to the_time
      freeze_time
    end
    after do
      unfreeze_time
      travel_back
    end
  end

  shared_context 'user create users' do
    let!(:users) do
      ret = 4.times.map do |idx|
        create(
          :user,
          id: idx + 1,
          name: "User #{idx + 1}",
          email: "user_#{idx + 1}@example.com"
        )
      end
      ret[1].update!(last_login_at: Time.zone.parse("2020-01-01 08:00:00"))
      ret[2].update!(last_login_at: Time.zone.parse("2020-01-01 09:00:00"))
      ret[3].update!(last_login_at: Time.zone.parse("2020-01-01 23:59:59"))
      ret
    end

    let!(:projects) do
      [
        create(:project, name: "Project 1", description: "Test 1"),
        create(:project, name: "Project 2", description: "Test 2"),
        create(:project, name: "Project 3", description: "Test 3")
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
      [
        '"id","name","last_login_at","project_name"' + "\n",
        '"1","User 1","","Project 1"' + "\n",
        '"1","User 1","","Project 2"' + "\n",
        '"1","User 1","","Project 3"' + "\n",
        '"2","User 2","2020-01-01 08:00:00","Project 1"' + "\n",
        '"2","User 2","2020-01-01 08:00:00","Project 3"' + "\n",
        '"3","User 3","2020-01-01 09:00:00","Project 1"' + "\n",
        '"4","User 4","2020-01-01 23:59:59",""' + "\n"
      ]
    end
  end

  it "has a valid factory" do
    expect(build(:user)).to be_valid
  end

  it { is_expected.to validate_presence_of :name }
  it { is_expected.to validate_presence_of :email }
  it { is_expected.to validate_uniqueness_of(:name) }
  it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  it { is_expected.to have_many(:projects).through(:project_user_relations) }

  it 'is valid with name' do
    user = User.new(name: 'Akira', email: "akira@example.com")
    expect(user).to be_valid
  end

  it 'is invalid without name' do
    user = build(:user, name: nil)
    user.valid?
    expect(user.errors[:name]).to include("can't be blank")
  end

  it 'is invalid without email' do
    user = build(:user, email: nil)
    user.valid?
    expect(user.errors[:email]).to include("can't be blank")
  end

  context '#csv_name' do
    subject { User.csv_name }
    let(:the_time) { Time.zone.parse('2020-01-02 08:59:59') }
    include_context 'user time_travel'
    let(:expect_csv_name) do
      "#{Rails.root}/csvs/users_2020-01-02_08_59_59_000JST.csv"
    end

    it { is_expected.to eq expect_csv_name }
  end

  context '#to_csv_by_sql' do
    subject { User.to_csv_by_sql(opts) }
    include_context 'user create users'

    let!(:the_time) { Time.zone.parse('2020-01-02 08:59:01') }
    include_context 'user time_travel'
    before do
      File.delete(User.csv_name) if File.exist?(User.csv_name)
      subject
    end

    context "with no-opts" do
      let(:opts) { {} }
      let(:expect_contents) { expect_lines.join }

      it { expect(File.read(User.csv_name)).to eq expect_contents }
    end

    context "with opts {offset: 1, limit: 2}" do
      let(:opts) { { offset: 1, limit: 2 } }
      let(:expect_contents) do
        expect_lines[0] +
          expect_lines[4] + expect_lines[5] + expect_lines[6]
      end

      it { expect(File.read(User.csv_name)).to eq expect_contents }
    end
  end

  context '#to_csv' do
    subject { User.to_csv(opts) }
    include_context 'user create users'

    let!(:the_time) { Time.zone.parse('2020-01-02 08:59:01') }
    include_context 'user time_travel'
    before do
      File.delete(User.csv_name) if File.exist?(User.csv_name)
      subject
    end

    context "with no-opts" do
      let(:opts) { {} }
      let(:bomed_expect_contents) do
        "\uFEFF" + expect_lines.join
      end

      it { expect(File.read(User.csv_name)).to eq bomed_expect_contents }
    end

    context "with opts {offset: 1, limit: 2}" do
      let(:opts) { { offset: 1, limit: 2 } }
      let(:bomed_expect_contents) do
        "\uFEFF" + expect_lines[0] +
          expect_lines[4] + expect_lines[5] + expect_lines[6]
      end

      it { expect(File.read(User.csv_name)).to eq bomed_expect_contents }
    end
  end

  context '#csv_name' do
    subject { User.csv_name }
    let(:the_time) { Time.zone.parse('2020-01-02 08:59:59') }
    include_context 'user time_travel'
    let(:expect_csv_name) do
      "#{Rails.root}/csvs/users_2020-01-02_08_59_59_000JST.csv"
    end

    it { is_expected.to eq expect_csv_name }
  end

  context '#to_csv' do
    subject { User.to_csv(opts) }
    include_context 'user create users'

    let!(:the_time) { Time.zone.parse('2020-01-02 08:59:01') }
    include_context 'user time_travel'
    before do
      File.delete(User.csv_name) if File.exist?(User.csv_name)
      subject
    end

    context "with no-opts" do
      let(:opts) { {} }
      let(:bomed_expect_contents) do
        "\uFEFF" + expect_lines.join('')
      end

      it { expect(File.read(User.csv_name)).to eq bomed_expect_contents }
    end

    context "with opts {offset: 1, limit: 2}" do
      let(:opts) { { offset: 1, limit: 2 } }
      let(:bomed_expect_contents) do
        "\uFEFF" + expect_lines[0] +
          expect_lines[4] + expect_lines[5] + expect_lines[6]
      end

      it { expect(File.read(User.csv_name)).to eq bomed_expect_contents }
    end
  end

  context '#to_csv_x' do
    subject { User.to_csv_x(opts) }
    include_context 'user create users'

    let!(:the_time) { Time.zone.parse('2020-01-02 08:59:01') }
    include_context 'user time_travel'
    before do
      File.delete(User.csv_name) if File.exist?(User.csv_name)
      subject
    end

    context "with no-opts" do
      let(:opts) { {} }
      let(:bomed_expect_contents) do
        "\uFEFF" + expect_lines.join
      end

      it { expect(File.read(User.csv_name)).to eq bomed_expect_contents }
    end

    context "with opts {offset: 1, limit: 2}" do
      let(:opts) { { offset: 1, limit: 2 } }
      let(:bomed_expect_contents) do
        "\uFEFF" + expect_lines[0] +
          expect_lines[4] + expect_lines[5] + expect_lines[6]
      end

      it { expect(File.read(User.csv_name)).to eq bomed_expect_contents }
    end
  end

  context "#export" do
    subject { User.export(file_path, users) }

    let!(:the_time) { Time.zone.parse('2020-01-02 08:59:00') }
    include_context 'user time_travel'
    include_context 'user create users'
    let(:expect_lines) do
      time_stamps = '"2020-01-02 08:59:00.000000","2020-01-02 08:59:00.000000"'
      [
        '"id","name","email","created_at","updated_at","last_login_at"' + "\n",
        '"1","User 1","user_1@example.com",' + time_stamps + ',""' + "\n",
        '"2","User 2","user_2@example.com",' + time_stamps +
          ',"2020-01-01 08:00:00"' + "\n",
        '"3","User 3","user_3@example.com",' + time_stamps +
          ',"2020-01-01 09:00:00"' + "\n",
        '"4","User 4","user_4@example.com",' + time_stamps +
          ',"2020-01-01 23:59:59"' + "\n"
      ]
    end
    before do
      File.delete(file_path) if File.exist?(file_path)
      subject
    end

    context "no opts" do
      let(:file_path) { "#{Rails.root}/csvs/export_users.csv" }
      let(:recoreds) { nil }
      let(:expect_contents) { expect_lines.join("") }

      it { expect(File.read(file_path)).to eq expect_contents }
    end
  end

  context "#import" do
    subject { User.import(file_path) }
    let(:file_path) { "filename" }

    context "with real file" do
      let(:file_path) { "spec/fixtures/export_users.csv" }
      let(:expect_attrs) do
        time_stamp = Time.zone.parse("2020-01-02 08:59:00")
        [
          {
            id: 1,
            name: 'User 1',
            email: 'user_1@example.com',
            created_at: time_stamp,
            updated_at: time_stamp,
            last_login_at: nil
          },
          {
            id: 2,
            name: 'User 2',
            email: 'user_2@example.com',
            created_at: time_stamp,
            updated_at: time_stamp,
            last_login_at: Time.zone.parse('2020-01-01 08:00:00')
          },
          {
            id: 3,
            name: 'User 3',
            email: 'user_3@example.com',
            created_at: time_stamp,
            updated_at: time_stamp,
            last_login_at: Time.zone.parse('2020-01-01 09:00:00')
          },
          {
            id: 4,
            name: 'User 4',
            email: 'user_4@example.com',
            created_at: time_stamp,
            updated_at: time_stamp,
            last_login_at: Time.zone.parse('2020-01-01 23:59:59')
          }
        ]
      end
      before do
        User.destroy_all
        subject
      end

      it do
        expect(User.order(:id).map { |x| x.attributes.symbolize_keys })
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
        let(:rows) { [%w[id name email created_at updated_at last_login_at]] }

        it { expect(Project.count).to eq 0 }
      end

      context "has 3 data rows" do
        let(:rows) do
          time_stamp = "2020-01-02 08:59:00"
          [
            %w[id name email created_at updated_at last_login_at],
            [1, 'User 1', 'user_1@example.com', time_stamp, time_stamp, ""],
            [2, 'User 2', 'user_2@example.com', time_stamp, time_stamp, nil],
            [
              3, 'User 3', 'user_3@example.com', time_stamp, time_stamp,
              '2020-01-03 08:59:00'
            ]
          ]
        end
        let(:expect_attrs) do
          time_stamp = Time.zone.parse('2020-01-02 08:59:00')
          [
            {
              id: 1,
              name: 'User 1',
              email: 'user_1@example.com',
              created_at: time_stamp,
              updated_at: time_stamp,
              last_login_at: nil
            },
            {
              id: 2,
              name: 'User 2',
              email: 'user_2@example.com',
              created_at: time_stamp,
              updated_at: time_stamp,
              last_login_at: nil
            },
            {
              id: 3,
              name: 'User 3',
              email: 'user_3@example.com',
              created_at: time_stamp,
              updated_at: time_stamp,
              last_login_at: time_stamp + 1.day
            }
          ]
        end

        it do
          expect(User.count).to eq 3
          expect(User.order(:id).map { |x| x.attributes.symbolize_keys })
            .to eq expect_attrs
        end
      end
    end
  end
end
