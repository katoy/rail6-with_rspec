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

  shared_context "project create projects" do
    let!(:projects) do
      ret = create_list(:project, 2)
      2.times do |idx|
        ret[idx].update!(
          name: "Project #{idx + 1}",
          description: "Test project #{idx + 1}."
        )
      end
      ret
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

  context "#csv_name" do
    subject{ Project.csv_name }
    let(:the_time){Time.zone.parse('2020-01-02 08:59:59')}
    include_context "project time_travel"
    let(:expect_csv_name) do
      "#{Rails.root}/csvs/projects_2020-01-02_08_59_59_000JST.csv"
    end

    it{ is_expected.to eq expect_csv_name }
  end

  context '#to_csv_by_sql' do
    include_context "project clear and reset pk"
    include_context "project create projects"
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

  context '#to_csv' do
    subject{Project.to_csv}
    include_context "project clear and reset pk"
    include_context "project create projects"

    let!(:the_time){Time.zone.parse('2020-01-02 08:59:01')}
    include_context "project time_travel"
    before do
      File.delete(Project.csv_name) if File.exist?(Project.csv_name)
    end

    let(:expect_lines) do
      "\uFEFF" + "id,name,description\n" \
      "1,Project 1,Test project 1.\n" \
      "2,Project 2,Test project 2.\n"
    end

    context "check contens with file" do
      it "contents of csv file" do
        subject
        expect(File.read(Project.csv_name)).to eq expect_lines
      end
    end

    context "check contents without file" do
      let(:buffer) { StringIO.new }
      before do
        allow(File).to receive(:open).with(Project.csv_name, 'w:UTF-8')
                   .and_yield(buffer)
      end

      it "contents of csv file" do
        subject
        expect(buffer.string).to eq expect_lines
      end
    end
  end
end
