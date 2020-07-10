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
      4.times.map do |idx|
        create(
          :user,
          id: idx + 1,
          name: "User #{idx + 1}",
          email: "user_#{idx + 1}@examle.com"
        )
      end
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
        '"id","name","project_name"' + "\n",
        '"1","User 1","Project 1"' + "\n",
        '"1","User 1","Project 2"' + "\n",
        '"1","User 1","Project 3"' + "\n",
        '"2","User 2","Project 1"' + "\n",
        '"2","User 2","Project 3"' + "\n",
        '"3","User 3","Project 1"' + "\n",
        '"4","User 4",""' + "\n"
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
      let(:expect_contents) { expect_lines.join() }

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
        "\uFEFF" + expect_lines.join()
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
        "\uFEFF" + expect_lines.join()
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
end
