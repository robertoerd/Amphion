# frozen_string_literal: true

#
# Copyright (C) 2011 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require_relative "../../../spec_helper"

def gen_ssha_password(password)
  salt = SecureRandom.random_bytes(10)
  "{SSHA}" + Base64.encode64(Digest::SHA1.digest(password + salt).unpack1("H*") + salt).gsub(/\s/, "")
end

describe SIS::CSV::UserImporter do
  before { account_model }

  it "creates new users and update names" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user@example.com,active"
    )
    user = CommunicationChannel.by_path("user@example.com").first.user
    expect(user.account).to eql(@account)
    expect(user.name).to eql("User Uno")
    expect(user.short_name).to eql("User Uno")

    expect(user.pseudonyms.count).to be(1)
    pseudonym = user.pseudonyms.first
    expect(pseudonym.unique_id).to eql("user1")

    expect(user.communication_channels.count).to be(1)
    cc = user.communication_channels.first
    expect(cc.path).to eql("user@example.com")

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno 2,user@example.com,active"
    )
    user = CommunicationChannel.by_path("user@example.com").first.user
    expect(user.account).to eql(@account)
    expect(user.name).to eql("User Uno 2")
    expect(user.short_name).to eql("User Uno 2")

    expect(user.pseudonyms.count).to be(1)
    pseudonym = user.pseudonyms.first
    expect(pseudonym.unique_id).to eql("user1")

    expect(user.communication_channels.count).to be(1)

    user.name = "My Awesome Name"
    user.save

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno 2,user@example.com,active"
    )
    user = CommunicationChannel.by_path("user@example.com").first.user
    expect(user.account).to eql(@account)
    expect(user.name).to eql("My Awesome Name")
    expect(user.short_name).to eql("My Awesome Name")
  end

  it "creates new users with display name" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,short_name,email,status",
      "user_1,user1,User,Uno,The Uno,user@example.com,active"
    )
    user = CommunicationChannel.by_path("user@example.com").first.user
    expect(user.account).to eql(@account)
    expect(user.name).to eql("User Uno")
    expect(user.short_name).to eql("The Uno")

    expect(user.pseudonyms.count).to be(1)
    pseudonym = user.pseudonyms.first
    expect(pseudonym.unique_id).to eql("user1")

    expect(user.communication_channels.count).to be(1)
    cc = user.communication_channels.first
    expect(cc.path).to eql("user@example.com")

    # Field order shouldn't matter
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status,short_name",
      "user_2,user2,User,Dos,user2@example.com,active,The Dos"
    )
    user = CommunicationChannel.by_path("user2@example.com").first.user
    expect(user.account).to eql(@account)
    expect(user.name).to eql("User Dos")
    expect(user.short_name).to eql("The Dos")

    expect(user.pseudonyms.count).to be(1)
    pseudonym = user.pseudonyms.first
    expect(pseudonym.unique_id).to eql("user2")

    expect(user.communication_channels.count).to be(1)
    cc = user.communication_channels.first
    expect(cc.path).to eql("user2@example.com")
  end

  it "creates new users with full name" do
    process_csv_data_cleanly(
      "user_id,login_id,full_name,email,status",
      "user_1,user1,User Uno,user@example.com,active"
    )
    user = CommunicationChannel.by_path("user@example.com").first.user
    expect(user.account).to eql(@account)
    expect(user.name).to eql("User Uno")

    expect(user.pseudonyms.count).to be(1)
    pseudonym = user.pseudonyms.first
    expect(pseudonym.unique_id).to eql("user1")

    expect(user.communication_channels.count).to be(1)
    cc = user.communication_channels.first
    expect(cc.path).to eql("user@example.com")

    # Field order shouldn't matter
    process_csv_data_cleanly(
      "user_id,login_id,email,status,full_name",
      "user_2,user2,user2@example.com,active,User Dos"
    )
    user = CommunicationChannel.by_path("user2@example.com").first.user
    expect(user.account).to eql(@account)
    expect(user.name).to eql("User Dos")

    expect(user.pseudonyms.count).to be(1)
    pseudonym = user.pseudonyms.first
    expect(pseudonym.unique_id).to eql("user2")

    expect(user.communication_channels.count).to be(1)
    cc = user.communication_channels.first
    expect(cc.path).to eql("user2@example.com")
  end

  it "creates new users with sortable name" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,sortable_name,email,status",
      "user_1,user1,User,Uno,\"One, User\",user@example.com,active"
    )
    user = CommunicationChannel.by_path("user@example.com").first.user
    expect(user.account).to eql(@account)
    expect(user.name).to eql("User Uno")
    expect(user.sortable_name).to eql("One, User")

    expect(user.pseudonyms.count).to be(1)
    pseudonym = user.pseudonyms.first
    expect(pseudonym.unique_id).to eql("user1")

    expect(user.communication_channels.count).to be(1)
    cc = user.communication_channels.first
    expect(cc.path).to eql("user@example.com")

    # Field order shouldn't matter
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status,sortable_name",
      "user_2,user2,User,Dos,user2@example.com,active,\"Two, User\""
    )
    user = CommunicationChannel.by_path("user2@example.com").first.user
    expect(user.account).to eql(@account)
    expect(user.name).to eql("User Dos")
    expect(user.sortable_name).to eql("Two, User")

    expect(user.pseudonyms.count).to be(1)
    pseudonym = user.pseudonyms.first
    expect(pseudonym.unique_id).to eql("user2")

    expect(user.communication_channels.count).to be(1)
    cc = user.communication_channels.first
    expect(cc.path).to eql("user2@example.com")
  end

  it "preserves sortable name if provided when changing regular name" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,sortable_name,email,status",
      "user_1,user1,User,One,\"One, User\",user@example.com,active"
    )
    user = CommunicationChannel.by_path("user@example.com").first.user
    expect(user.name).to eq("User One")
    expect(user.sortable_name).to eql("One, User")
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,sortable_name,email,status",
      "user_1,user1,User,Uno,\"One, User\",user@example.com,active"
    )
    expect(user.reload.name).to eq("User Uno")
    expect(user.sortable_name).to eql("One, User")
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,status",
      "user_1,user1,Usero,Uno,active"
    )
    expect(user.reload.name).to eq("Usero Uno")
    expect(user.sortable_name).to eql("Uno, Usero")
  end

  it "preserves first name/last name split" do
    process_csv_data_cleanly(
      "user_id,login_id,password,first_name,last_name,email,status,ssha_password",
      "user_1,user1,badpassword,John,St. Clair,user@example.com,active,"
    )
    user = Pseudonym.by_unique_id("user1").first.user
    expect(user.name).to eq "John St. Clair"
    expect(user.sortable_name).to eq "St. Clair, John"
    expect(user.first_name).to eq "John"
    expect(user.last_name).to eq "St. Clair"
  end

  describe "pronouns" do
    before(:once) do
      @account = account_model
      @account.settings[:can_add_pronouns] = true
      @account.save!
    end

    it "adds pronouns to users" do
      process_csv_data_cleanly(
        "user_id,login_id,full_name,status,pronouns",
        "user_1,user1,tom riddle,active,He/Him"
      )
      user = Pseudonym.by_unique_id("user1").first.user
      expect(user.pronouns).to eq "He/Him"
    end

    it "adds custom pronouns to users" do
      @account.pronouns = ["mr/man"]
      @account.save!
      process_csv_data_cleanly(
        "user_id,login_id,full_name,status,pronouns",
        "user_1,user1,tom riddle,active,mr/man"
      )
      user = Pseudonym.by_unique_id("user1").first.user
      expect(user.pronouns).to eq "mr/man"
    end

    it "adds pronouns when not in account list" do
      process_csv_data_cleanly(
        "user_id,login_id,full_name,status,pronouns",
        "user_1,user1,tom riddle,active,mr/man"
      )
      user = Pseudonym.by_unique_id("user1").first.user
      expect(user.pronouns).to eq "mr/man"
    end

    it "respects users set pronouns cause it's sticky" do
      @account.pronouns = ["mr/man", "he/him"]
      @account.save!

      process_csv_data_cleanly(
        "user_id,login_id,full_name,status,pronouns",
        "user_1,user1,tom riddle,active,mr/man"
      )
      user = Pseudonym.by_unique_id("user1").first.user

      user.pronouns = "he/him"
      user.save!
      process_csv_data_cleanly(
        "user_id,login_id,full_name,status,pronouns",
        "user_1,user1,tom riddle,active,mr/man"
      )
      expect(user.pronouns).to eq "he/him"
    end

    it "deletes users set pronouns" do
      process_csv_data_cleanly(
        "user_id,login_id,full_name,status,pronouns",
        "user_1,user1,tom riddle,active,mr/man"
      )
      user = Pseudonym.by_unique_id("user1").first.user
      expect(user.pronouns).to eq "mr/man"
      process_csv_data_cleanly(
        "user_id,login_id,full_name,status,pronouns",
        "user_1,user1,tom riddle,active,<delete>"
      )
      expect(user.reload.pronouns).to be_nil
    end

    it "does not deletes users set pronouns when sticky" do
      @account.pronouns = ["mr/man", "he/him"]
      @account.save!

      process_csv_data_cleanly(
        "user_id,login_id,full_name,status,pronouns",
        "user_1,user1,tom riddle,active,mr/man"
      )
      user = Pseudonym.by_unique_id("user1").first.user

      user.pronouns = "he/him"
      user.save!

      process_csv_data_cleanly(
        "user_id,login_id,full_name,status,pronouns",
        "user_1,user1,tom riddle,active,<delete>"
      )
      expect(user.reload.pronouns).to eq "he/him"
    end

    it "does not add pronouns when the option is turned off" do
      @account.settings[:can_add_pronouns] = false
      @account.save!

      process_csv_data_cleanly(
        "user_id,login_id,full_name,status,pronouns",
        "user_1,user1,tom riddle,active,He/Him"
      )
      user = Pseudonym.by_unique_id("user1").first.user
      expect(user.pronouns).to be_nil
    end
  end

  describe "declared_user_type" do
    it "adds declared_user_type to users" do
      process_csv_data_cleanly(
        "user_id,login_id,full_name,status,declared_user_type",
        "user_1,user1,tom riddle,active,teacher"
      )
      user = Pseudonym.by_unique_id("user1").first.user
      expect(user.pseudonym.declared_user_type).to eq "teacher"
    end

    it "deletes users set declared_user_type when requested" do
      process_csv_data_cleanly(
        "user_id,login_id,full_name,status,declared_user_type",
        "user_1,user1,tom riddle,active,teacher"
      )
      user = Pseudonym.by_unique_id("user1").first.user
      expect(user.pseudonym.declared_user_type).to eq "teacher"
      process_csv_data_cleanly(
        "user_id,login_id,full_name,status,declared_user_type",
        "user_1,user1,tom riddle,active,<delete>"
      )
      expect(user.reload.pseudonym.declared_user_type).to be_nil
    end

    it "does not delete users set declared_user_type when not set" do
      process_csv_data_cleanly(
        "user_id,login_id,full_name,status,declared_user_type",
        "user_1,user1,tom riddle,active,teacher"
      )
      user = Pseudonym.by_unique_id("user1").first.user
      expect(user.pseudonym.declared_user_type).to eq "teacher"
      process_csv_data_cleanly(
        "user_id,login_id,full_name,status",
        "user_1,user1,tom riddle,active"
      )
      expect(user.reload.pseudonym.declared_user_type).to eq "teacher"
    end
  end

  it "uses sortable_name if none of first_name/last_name/full_name is given" do
    process_csv_data_cleanly(
      "user_id,login_id,sortable_name,short_name,email,status",
      "user_1,user1,blah,bleh,user@example.com,active"
    )
    user = Pseudonym.by_unique_id("user1").first.user
    expect(user.name).to eq "blah"
  end

  it "uses short_name is none of first_name/last_name/full_name/sortable_name is given" do
    process_csv_data_cleanly(
      "user_id,login_id,short_name,email,status",
      "user_1,user1,bleh,user@example.com,active"
    )
    user = Pseudonym.by_unique_id("user1").first.user
    expect(user.name).to eq "bleh"
  end

  it "uses login_id as a name if no form of name is given" do
    process_csv_data_cleanly(
      "user_id,login_id,status",
      "user_1,user1,active"
    )
    user = Pseudonym.by_unique_id("user1").first.user
    expect(user.name).to eq "user1"
  end

  it "leaves the name alone if no name is supplied for an existing user" do
    user = User.create!(name: "Greeble")
    user.pseudonyms.create!(account: @account, sis_user_id: "greeble", unique_id: "greeble@example.com")
    process_csv_data_cleanly(
      "user_id,login_id,status",
      "greeble,greeble@example.com,active"
    )
    expect(user.reload.name).to eq "Greeble"
  end

  it "ignores first and last names if full name is provided" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,full_name,email,status",
      "user_1,user1,,,User One,user@example.com,active"
    )
    user = CommunicationChannel.by_path("user@example.com").first.user
    expect(user.name).to eql("User One")
    expect(user.sortable_name).to eql("One, User")

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,full_name,email,status",
      "user_2,user2,User,Dos,User Two,user2@example.com,active"
    )
    user = CommunicationChannel.by_path("user2@example.com").first.user
    expect(user.name).to eql("User Two")
    expect(user.sortable_name).to eql("Two, User")
  end

  it "does not override the sortable name if full name is provided" do
    process_csv_data_cleanly(
      "user_id,login_id,full_name,sortable_name,status",
      "user_1,user1,User One Two,\"One Two, User\",active"
    )
    user = Pseudonym.where(sis_user_id: "user_1").first.user
    expect(user.name).to eql("User One Two")
    expect(user.sortable_name).to eql("One Two, User")
  end

  it "sets passwords and not overwrite current passwords" do
    process_csv_data_cleanly(
      "user_id,login_id,password,first_name,last_name,email,status,ssha_password",
      "user_1,user1,badpassword,User,Uno 2,user@example.com,active,",
      "user_2,user2,,User,Uno 2,user2@example.com,active,#{gen_ssha_password("password")}"
    )
    user1 = CommunicationChannel.by_path("user@example.com").first.user
    p = user1.pseudonyms.first
    expect(p.valid_arbitrary_credentials?("badpassword")).to be_truthy

    p.password = "lessbadpassword"
    p.password_confirmation = "lessbadpassword"
    p.save

    user2 = CommunicationChannel.by_path("user2@example.com").first.user
    p = user2.pseudonyms.first
    expect(p.valid_arbitrary_credentials?("password")).to be_truthy

    p.password = "newpassword"
    p.password_confirmation = "newpassword"
    p.save

    expect(p.valid_arbitrary_credentials?("password")).to be_falsey
    expect(p.valid_arbitrary_credentials?("newpassword")).to be_truthy

    process_csv_data_cleanly(
      "user_id,login_id,password,first_name,last_name,email,status,ssha_password",
      "user_1,user1,badpassword2,User,Uno 2,user@example.com,active",
      "user_2,user2,,User,Uno 2,user2@example.com,active,#{gen_ssha_password("changedpassword")}"
    )

    user1.reload
    p = user1.pseudonyms.first
    expect(p.valid_arbitrary_credentials?("badpassword")).to be_falsey
    expect(p.valid_arbitrary_credentials?("badpassword2")).to be_falsey
    expect(p.valid_arbitrary_credentials?("lessbadpassword")).to be_truthy

    user2.reload
    p = user2.pseudonyms.first
    expect(p.valid_arbitrary_credentials?("password")).to be_falsey
    expect(p.valid_arbitrary_credentials?("changedpassword")).to be_falsey
    expect(p.valid_arbitrary_credentials?("newpassword")).to be_truthy
    expect(p.valid_ssha?("changedpassword")).to be_truthy
  end

  it "recognizes integration_id and work" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status,ssha_password,integration_id",
      "user_2,user2,User,Dos,user@example.com,active,#{gen_ssha_password("password")}, 9000"
    )
    user2 = Pseudonym.by_unique_id("user2").first.user
    expect(user2.pseudonym.integration_id).to eq "9000"
  end

  it "recognizes there's no integration_id and still work" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status,ssha_password",
      "user_2,user2,User,Dos,user@example.com,active,#{gen_ssha_password("password")}"
    )
    user2 = Pseudonym.by_unique_id("user2").first.user
    expect(user2.pseudonym.integration_id).to be_nil
  end

  it "recognizes a blank integration_id and still work" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status,ssha_password,integration_id",
      "user_2,user2,User,Dos,user@example.com,active,#{gen_ssha_password("password")},\"\""
    )
    user2 = Pseudonym.by_unique_id("user2").first.user
    expect(user2.pseudonym.integration_id).to be_nil
  end

  it "does not set integration_id to nil when it is not passed" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status,integration_id",
      "user_2,user2,User,Dos,user@example.com,active,9000"
    )
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_2,user2,User,Dos,user@example.com,active"
    )
    user2 = Pseudonym.by_unique_id("user2").first.user
    expect(user2.pseudonym.integration_id).to eq "9000"
  end

  it "allows setting and resetting of passwords" do
    expect(CommunicationChannel.by_path("user1@example.com").first).to be_nil
    expect(CommunicationChannel.by_path("user2@example.com").first).to be_nil

    process_csv_data_cleanly(
      "user_id,login_id,password,first_name,last_name,email,status,ssha_password",
      "user_1,user1,password1,User,Uno,user1@example.com,active,",
      "user_2,user2,,User,Dos,user2@example.com,active,#{gen_ssha_password("encpass1")}"
    )

    user1_persistence_token = nil
    user2_persistence_token = nil
    CommunicationChannel.by_path("user1@example.com").first.user.pseudonyms.first.tap do |p|
      user1_persistence_token = p.persistence_token
      expect(p.valid_arbitrary_credentials?("password1")).to be_truthy
      expect(p.valid_arbitrary_credentials?("password2")).to be_falsey
      expect(p.valid_arbitrary_credentials?("password3")).to be_falsey
      expect(p.valid_arbitrary_credentials?("password4")).to be_falsey
    end

    user2_sis_ssha = nil
    CommunicationChannel.by_path("user2@example.com").first.user.pseudonyms.first.tap do |p|
      user2_persistence_token = p.persistence_token
      user2_sis_ssha = p.sis_ssha
      expect(p.valid_arbitrary_credentials?("encpass1")).to be_truthy
      expect(p.valid_arbitrary_credentials?("encpass2")).to be_falsey
      expect(p.valid_arbitrary_credentials?("encpass3")).to be_falsey
      expect(p.valid_arbitrary_credentials?("password4")).to be_falsey
    end

    # passwords haven't changed, neither should persistence tokens
    process_csv_data_cleanly(
      "user_id,login_id,password,first_name,last_name,email,status,ssha_password",
      "user_1,user1,password1,User,Uno,user1@example.com,active,",
      "user_2,user2,,User,Dos,user2@example.com,active,#{user2_sis_ssha}"
    )

    CommunicationChannel.by_path("user1@example.com").first.user.pseudonyms.first.tap do |p|
      expect(user1_persistence_token).to eq p.persistence_token
      expect(p.valid_arbitrary_credentials?("password1")).to be_truthy
      expect(p.valid_arbitrary_credentials?("password2")).to be_falsey
      expect(p.valid_arbitrary_credentials?("password3")).to be_falsey
      expect(p.valid_arbitrary_credentials?("password4")).to be_falsey
    end

    CommunicationChannel.by_path("user2@example.com").first.user.pseudonyms.first.tap do |p|
      expect(user2_persistence_token).to eq p.persistence_token
      expect(p.valid_arbitrary_credentials?("encpass1")).to be_truthy
      expect(p.valid_arbitrary_credentials?("encpass2")).to be_falsey
      expect(p.valid_arbitrary_credentials?("encpass3")).to be_falsey
      expect(p.valid_arbitrary_credentials?("password4")).to be_falsey
    end

    # passwords change, persistence token should change
    process_csv_data_cleanly(
      "user_id,login_id,password,first_name,last_name,email,status,ssha_password",
      "user_1,user1,password2,User,Uno,user1@example.com,active,",
      "user_2,user2,,User,Dos,user2@example.com,active,#{gen_ssha_password("encpass2")}"
    )

    CommunicationChannel.by_path("user1@example.com").first.user.pseudonyms.first.tap do |p|
      expect(user1_persistence_token).not_to eq p.persistence_token
      expect(p.valid_arbitrary_credentials?("password1")).to be_falsey
      expect(p.valid_arbitrary_credentials?("password2")).to be_truthy
      expect(p.valid_arbitrary_credentials?("password3")).to be_falsey
      expect(p.valid_arbitrary_credentials?("password4")).to be_falsey

      p.password_confirmation = p.password = "password4"
      p.save
      user1_persistence_token = p.persistence_token
    end

    CommunicationChannel.by_path("user2@example.com").first.user.pseudonyms.first.tap do |p|
      expect(user2_persistence_token).not_to eq p.persistence_token
      expect(p.valid_arbitrary_credentials?("encpass1")).to be_falsey
      expect(p.valid_arbitrary_credentials?("encpass2")).to be_truthy
      expect(p.valid_arbitrary_credentials?("encpass3")).to be_falsey
      expect(p.valid_arbitrary_credentials?("password4")).to be_falsey

      p.password_confirmation = p.password = "password4"
      p.save
      user2_persistence_token = p.persistence_token
    end

    # user set password, persistence token should not change
    process_csv_data_cleanly(
      "user_id,login_id,password,first_name,last_name,email,status,ssha_password",
      "user_1,user1,password3,User,Uno,user1@example.com,active,",
      "user_2,user2,,User,Dos,user2@example.com,active,#{gen_ssha_password("encpass3")}"
    )

    CommunicationChannel.by_path("user1@example.com").first.user.pseudonyms.first.tap do |p|
      expect(user1_persistence_token).to eq p.persistence_token
      expect(p.valid_arbitrary_credentials?("password1")).to be_falsey
      expect(p.valid_arbitrary_credentials?("password2")).to be_falsey
      expect(p.valid_arbitrary_credentials?("password3")).to be_falsey
      expect(p.valid_arbitrary_credentials?("password4")).to be_truthy
    end

    CommunicationChannel.by_path("user2@example.com").first.user.pseudonyms.first.tap do |p|
      expect(user2_persistence_token).to eq p.persistence_token
      expect(p.valid_arbitrary_credentials?("encpass1")).to be_falsey
      expect(p.valid_arbitrary_credentials?("encpass2")).to be_falsey
      expect(p.valid_arbitrary_credentials?("encpass3")).to be_falsey
      expect(p.valid_arbitrary_credentials?("password4")).to be_truthy
    end
  end

  it "catches active-record-level errors, like invalid unique_id" do
    sis_user = user_model
    before_user_count = User.count
    before_pseudo_count = Pseudonym.count
    importer = process_csv_data(
      "user_id,login_id,first_name,last_name,email,status",
      "U1,u\x01ser,User,Uno,user@example.com,active",
      user: sis_user
    )
    expect(CommunicationChannel.by_path("user@example.com").first).to be_nil

    expect(importer.errors.map(&:last).first).to include("Invalid login_id")
    expect([User.count, Pseudonym.count]).to eq [before_user_count, before_pseudo_count]
  end

  it "does not allow a secondary user account with the same login id." do
    p_count = Pseudonym.count
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user@example.com,active"
    )
    user = CommunicationChannel.by_path("user@example.com").first.user
    expect(user.pseudonyms.count).to eq 1
    expect(user.pseudonyms.by_unique_id("user1").first.sis_user_id).to eq "user_1"

    importer = process_csv_data(
      "user_id,login_id,first_name,last_name,email,status",
      "user_2,user1,User,Uno,user@example.com,active"
    )
    expect(importer.errors.map(&:last)).to eq ["An existing Canvas user with the SIS ID user_1 has already claimed user_2's user_id requested login information, skipping"]
    user = CommunicationChannel.by_path("user@example.com").first.user
    expect(user.pseudonyms.count).to eq 1
    expect(user.pseudonyms.by_unique_id("user1").first.sis_user_id).to eq "user_1"
    expect(Pseudonym.count).to eq(p_count + 1)
  end

  it "does not allow a secondary user account to change its login id to some other registered login id" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,active",
      "user_2,user2,User,Dos,user2@example.com,active"
    )

    importer = process_csv_data(
      "user_id,login_id,first_name,last_name,email,status",
      "user_2,user1,User,Dos,user2@example.com,active",
      "user_1,user3,User,Uno,user1@example.com,active"
    )
    expect(importer.errors.map(&:last)).to eq ["An existing Canvas user with the SIS ID user_1 has already claimed user_2's user_id requested login information, skipping"]
    expect(Pseudonym.where(account_id: @account, sis_user_id: "user_1").first.unique_id).to eq "user3"
    expect(Pseudonym.where(account_id: @account, sis_user_id: "user_2").first.unique_id).to eq "user2"
  end

  it "overwrites the old non-matching SIS ID with the new SIS ID in the upload when update_sis_id_if_login_claimed flag is set" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,active"
    )

    batch1 = @account.sis_batches.create! do |sb|
      sb.options = {
        update_sis_id_if_login_claimed: true,
      }
    end

    importer = process_csv_data(
      "user_id,login_id,first_name,last_name,email,status",
      "user_3,user1,User,Uno,user1@example.com,active",
      batch: batch1
    )

    expect(importer.errors.length).to eq 0
    expect(Pseudonym.where(account_id: @account, unique_id: "user1").first.sis_user_id).to eq "user_3"
  end

  it "does not show error when an integration_id is taken" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status,integration_id",
      "user_1,user1,User,Uno,user1@example.com,active,int_1"
    )

    importer = process_csv_data(
      "user_id,login_id,first_name,last_name,email,status,integration_id",
      "user_2,user2,User,Uno,user2@example.com,active,int_1"
    )
    expect(importer.errors.map(&:last)).to eq ["An existing Canvas user with the SIS ID user_1 has already claimed user_2's requested integration_id, skipping"]
  end

  it "processes user row when integration_id is not set" do
    importer1 = process_csv_data(
      "user_id,login_id,first_name,last_name,email,status,integration_id",
      "user_1,user1,User,Uno,user1@example.com,active,int_1",
      "user_2,user2,User,dos,user2@example.com,active,"
    )
    importer2 = process_csv_data(
      "user_id,login_id,first_name,last_name,email,status,integration_id",
      "user_1,user1,User,Uno,user1@example.com,active,int_1",
      "user_2,user2,User,dos,user2@example.com,active,"
    )
    expect(importer1.errors).to eq []
    expect(importer2.errors).to eq []
  end

  it "allows a secondary user account to change its login id to some other registered login id if the other changes it first" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,active",
      "user_2,user2,User,Dos,user2@example.com,active"
    )

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user3,User,Uno,user1@example.com,active",
      "user_2,user1,User,Dos,user2@example.com,active"
    )
    expect(Pseudonym.where(account_id: @account, sis_user_id: "user_1").first.unique_id).to eq "user3"
    expect(Pseudonym.where(account_id: @account, sis_user_id: "user_2").first.unique_id).to eq "user1"
  end

  it "allows a user to update information" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,active"
    )

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user2,User,Uno-Dos,user1@example.com,active"
    )

    expect(Pseudonym.where(account_id: @account, sis_user_id: "user_1").first.user.last_name).to eq "Uno-Dos"
  end

  it "has the correct count when the pseudonym doesn't change" do
    importer = process_csv_data(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,active"
    )
    expect(importer.batch.reload.data[:counts][:users]).to eq 1

    importer = process_csv_data(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno-Dos,user1@example.com,active"
    )
    expect(importer.batch.reload.data[:counts][:users]).to eq 1
  end

  it "allows a user to update display name specifically" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,short_name,email,status",
      "user_1,user1,User,Uno,The Uno,user1@example.com,active"
    )

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,short_name,email,status",
      "user_1,user1,User,Uno,The Uno-Dos,user1@example.com,active"
    )

    expect(Pseudonym.where(account_id: @account, sis_user_id: "user_1").first.user.short_name).to eq "The Uno-Dos"
  end

  it "allows a user to update full name name specifically" do
    process_csv_data_cleanly(
      "user_id,login_id,full_name,email,status",
      "user_1,user1,User Uno,user1@example.com,active"
    )

    process_csv_data_cleanly(
      "user_id,login_id,full_name,email,status",
      "user_1,user1,User Dos,user1@example.com,active"
    )

    expect(Pseudonym.where(account_id: @account, sis_user_id: "user_1").first.user.name).to eq "User Dos"
  end

  it "allows a user to update sortable name specifically" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,sortable_name,email,status",
      "user_1,user1,User,Uno,\"One, User\",user1@example.com,active"
    )

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,sortable_name,email,status",
      "user_1,user1,User,Uno,\"Two, User\",user1@example.com,active"
    )

    expect(Pseudonym.where(account_id: @account, sis_user_id: "user_1").first.user.sortable_name).to eq "Two, User"
  end

  it "allows a user to update emails and bounce count specifically" do
    enable_cache do
      Timecop.travel(1.minute.ago) do
        process_csv_data_cleanly(
          "user_id,login_id,first_name,last_name,email,status",
          "user_1,user1,User,Uno,user1@example.com,active"
        )
        @cc = Pseudonym.find_by(account_id: @account, sis_user_id: "user_1").communication_channels.take
        @cc.bounce_count = 3
        @cc.save!
        expect(Pseudonym.where(account_id: @account, sis_user_id: "user_1").first.user.email).to eq "user1@example.com"
      end

      process_csv_data_cleanly(
        "user_id,login_id,first_name,last_name,email,status",
        "user_1,user1,User,Uno,user2@example.com,active"
      )
      expect(@cc.reload.bounce_count).to eq 0
      expect(Pseudonym.where(account_id: @account, sis_user_id: "user_1").first.user.email).to eq "user2@example.com"
    end
  end

  it "clears the email cache when email is changed and full_name is supplied" do
    enable_cache do
      Timecop.travel(1.minute.ago) do
        process_csv_data_cleanly(
          "user_id,login_id,full_name,email,status",
          "sharky,sharky,Sharkwig von Sharkface,sharky@example.com,active"
        )
        expect(Pseudonym.where(account_id: @account, sis_user_id: "sharky").first.user.email).to eq "sharky@example.com"
      end

      process_csv_data_cleanly(
        "user_id,login_id,full_name,email,status",
        "sharky,sharky,Sharkwig von Sharkface,sharkface@example.com,active"
      )
      expect(Pseudonym.where(account_id: @account, sis_user_id: "sharky").first.user.email).to eq "sharkface@example.com"
    end
  end

  it "updates sortable name properly when full name is updated" do
    process_csv_data_cleanly(
      "user_id,login_id,full_name,email,status",
      "user_1,user1,User Uno,user1@example.com,active"
    )

    expect(Pseudonym.where(account_id: @account, sis_user_id: "user_1").first.user.sortable_name).to eq "Uno, User"

    process_csv_data_cleanly(
      "user_id,login_id,full_name,email,status",
      "user_1,user1,User Dos,user1@example.com,active"
    )

    expect(Pseudonym.where(account_id: @account, sis_user_id: "user_1").first.user.sortable_name).to eq "Dos, User"
  end

  it "adds two users with different user_ids, login_ids, but the same email" do
    notification = Notification.create(name: "Merge Email Communication Channel", category: "Registration")
    user1 = User.create!(name: "User Uno")
    user1.pseudonyms.create!(unique_id: "user1", account: @account)
    communication_channel(user1, { username: "user@example.com", active_cc: true })

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_2,user2,User,Dos,user@example.com,active"
    )
    user2 = Pseudonym.by_unique_id("user2").first.user
    expect(user1).not_to eq user2
    expect(user2.last_name).to eq "Dos"
    expect(user2.pseudonyms.count).to eq 1
    expect(user2.pseudonyms.first.communication_channel_id).not_to be_nil

    expect(Message.where(communication_channel_id: user2.email_channel, notification_id: notification).first).not_to be_nil
  end

  it "sends a registration notification email when canvas_password_notification is provided" do
    expect_any_instance_of(Pseudonym).to receive(:send_registration_notification!).once

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status,canvas_password_notification,authentication_provider_id",
      "user_1,user1,User,Uno,user1@example.com,active,true,canvas"
    )

    expect(Pseudonym.by_unique_id("user1").first.user.workflow_state).to eq "pre_registered"
  end

  it "does not send a registration notification email when canvas_password_notification is not provided" do
    expect_any_instance_of(Pseudonym).not_to receive(:send_registration_notification!)

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user1,user1,User,Uno,user@example.com,active"
    )
  end

  it "does not send a merge notification email when self service merge is disabled" do
    @account.disable_feature!(:self_service_user_merge)
    user1 = User.create!(name: "User Uno")
    user1.pseudonyms.create!(unique_id: "user1", account: @account)
    communication_channel(user1, { username: "user@example.com", active_cc: true })

    expect_any_instance_of(CommunicationChannel).not_to receive(:send_merge_notification!)

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_2,user2,User,Dos,user@example.com,active"
    )
    user2 = Pseudonym.by_unique_id("user2").first.user
    expect(user1).not_to eq user2
    expect(user2.last_name).to eq "Dos"
    expect(user2.pseudonyms.count).to eq 1
    expect(user2.pseudonyms.first.communication_channel_id).not_to be_nil
  end

  it "does not notify about a merge opportunity to an SIS user in the same account" do
    notification = Notification.create(name: "Merge Email Communication Channel", category: "Registration")
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user@example.com,active",
      "user_2,user2,User,Dos,user@example.com,active"
    )
    user1 = Pseudonym.by_unique_id("user1").first.user
    user2 = Pseudonym.by_unique_id("user2").first.user
    expect(user1).not_to eq user2
    expect(user1.last_name).to eq "Uno"
    expect(user2.last_name).to eq "Dos"
    expect(user1.pseudonyms.count).to eq 1
    expect(user2.pseudonyms.count).to eq 1
    expect(user1.pseudonyms.first.communication_channel_id).not_to be_nil
    expect(user2.pseudonyms.first.communication_channel_id).not_to be_nil

    expect(Message.where(communication_channel_id: user2.email_channel, notification_id: notification).first).to be_nil
  end

  it "does not notify about merge opportunities for users that have no means of logging in" do
    notification = Notification.create(name: "Merge Email Communication Channel", category: "Registration")
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user@example.com,deleted",
      "user_2,user2,User,Dos,user@example.com,active"
    )
    user1 = Pseudonym.by_unique_id("user1").first.user
    user2 = Pseudonym.by_unique_id("user2").first.user
    expect(user1).not_to eq user2
    expect(user1.last_name).to eq "Uno"
    expect(user2.last_name).to eq "Dos"
    expect(user1.pseudonyms.count).to eq 1
    expect(user2.pseudonyms.count).to eq 1
    expect(user1.pseudonyms.first.communication_channel_id).not_to be_nil
    expect(user2.pseudonyms.first.communication_channel_id).not_to be_nil

    expect(Message.where(communication_channel_id: user2.email_channel, notification_id: notification).first).to be_nil
  end

  it "does not have problems updating a user to a conflicting email" do
    notification = Notification.create(name: "Merge Email Communication Channel", category: "Registration")
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,active",
      "user_2,user2,User,Dos,user2@example.com,active"
    )
    user1 = Pseudonym.by_unique_id("user1").first.user
    user2 = Pseudonym.by_unique_id("user2").first.user
    expect(user1).not_to eq user2
    expect(user1.last_name).to eq "Uno"
    expect(user2.last_name).to eq "Dos"
    expect(user1.pseudonyms.count).to eq 1
    expect(user2.pseudonyms.count).to eq 1
    expect(user1.pseudonyms.first.communication_channel_id).not_to be_nil
    expect(user2.pseudonyms.first.communication_channel_id).not_to be_nil

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_2,user2,User,Dos,user1@example.com,active"
    )
    user2.reload
    expect(user2.communication_channels.length).to eq 1
    expect(user2.email_channel).to be_active
    expect(user2.email).to eq "user1@example.com"

    expect(Message.where(communication_channel_id: user2.email_channel, notification_id: notification).first).to be_nil
  end

  it "does not have a problem adding an existing e-mail that differs in case" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,active"
    )
    user1 = Pseudonym.by_unique_id("user1").first.user
    communication_channel(user1, { username: "JT@instructure.com" })

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,jt@instructure.com,active"
    )
    user1.reload
    expect(user1.communication_channels.count).to eq 2
    expect(user1.communication_channels.active.count).to eq 1
    expect(user1.email_channel).to be_active
    expect(user1.email).to eq "jt@instructure.com"
  end

  it "re-activates retired e-mails" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,active"
    )
    user1 = Pseudonym.by_unique_id("user1").first.user
    user1.email_channel.destroy
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,active"
    )
    user1.reload
    expect(user1.email_channel).to be_active
    expect(user1.communication_channels.length).to eq 1
  end

  it "sends merge opportunity notifications when reactivating an email" do
    notification = Notification.create(name: "Merge Email Communication Channel", category: "Registration")
    user1 = User.create!(name: "User Uno")
    user1.pseudonyms.create!(unique_id: "user1", account: @account)
    communication_channel(user1, { username: "user1@example.com", active_cc: true })

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_2,user2,User,Dos,user1@example.com,deleted"
    )
    user2 = Pseudonym.by_unique_id("user2").first.user
    expect(user1).not_to eq user2
    expect(user1.last_name).to eq "Uno"
    expect(user2.last_name).to eq "Dos"
    expect(user1.pseudonyms.count).to eq 1
    expect(user2.pseudonyms.count).to eq 1
    expect(user2.pseudonyms.first.communication_channel_id).not_to be_nil
    expect(user1.email_channel).not_to eq user2.email_channel
    expect(Message.count).to eq 0

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_2,user2,User,Dos,user1@example.com,active"
    )
    user2.reload

    expect(Message.where(communication_channel_id: user2.email_channel, notification_id: notification).first).not_to be_nil
  end

  it "does not send merge opportunity notifications on reactivation when suppress_notifications = true" do
    @account.settings[:suppress_notifications] = true
    @account.save!
    Notification.create(name: "Merge Email Communication Channel", category: "Registration")
    user1 = User.create!(name: "User Uno")
    user1.pseudonyms.create!(unique_id: "user1", account: @account)
    communication_channel(user1, { username: "user1@example.com", active_cc: true })

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_2,user2,User,Dos,user1@example.com,deleted"
    )
    user2 = Pseudonym.by_unique_id("user2").first.user
    expect(user1).not_to eq user2
    expect(user1.last_name).to eq "Uno"
    expect(user2.last_name).to eq "Dos"
    expect(user1.pseudonyms.count).to eq 1
    expect(user2.pseudonyms.count).to eq 1
    expect(user2.pseudonyms.first.communication_channel_id).not_to be_nil
    expect(user1.email_channel).not_to eq user2.email_channel
    expect(Message.count).to eq 0

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_2,user2,User,Dos,user1@example.com,active"
    )
    user2.reload
    expect(Message.count).to eq 0
  end

  it "does not send merge opportunity notifications if the conflicting cc is retired or unconfirmed" do
    notification = Notification.create(name: "Merge Email Communication Channel", category: "Registration")
    u1 = User.create! { |u| u.workflow_state = "registered" }
    cc1 = communication_channel(u1, { username: "user1@example.com", cc_state: "retired" })
    u2 = User.create! { |u| u.workflow_state = "registered" }
    cc2 = communication_channel(u2, { username: "user1@example.com" })
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,active"
    )
    user1 = Pseudonym.by_unique_id("user1").first.user
    expect([u1, u2]).not_to include(user1)
    expect(user1.communication_channels.length).to eq 1
    expect(user1.email).to eq "user1@example.com"
    expect([cc1, cc2]).not_to include(user1.email_channel)
    expect(Message.where(communication_channel_id: user1.email_channel, notification_id: notification).first).to be_nil
  end

  it "creates everything in the deleted state when deleted initially" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,deleted"
    )
    p = Pseudonym.by_unique_id("user1").first
    expect(p).to be_deleted
    u = p.user
    expect(u.communication_channels.length).to eq 1
    expect(u.communication_channels.first).to be_retired
  end

  it "does not add a user with the same login id as another user" do
    importer = process_csv_data(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,active",
      "user_2,user1,User,Dos,user2@example.com,active"
    )
    expect(importer.errors.pluck(1)).to eq ["An existing Canvas user with the SIS ID user_1 has already claimed user_2's user_id requested login information, skipping"]
    expect(Pseudonym.by_unique_id("user1").first).not_to be_nil
    expect(Pseudonym.by_unique_id("user2").first).to be_nil
  end

  it "does not throw an error to sentry for all errors" do
    importer = process_csv_data(
      "user_id,login_id,full_name,email,status",
      "u,'long_string_for_user_login_should_throw_an_error_and_be_caught_and_be_returned_to_import_and_not_sent_to_sentry',U U,u@example.com,active"
    )
    expect(Canvas::Errors).not_to receive(:capture_exception)
    expect(importer.errors.pluck(1)).to eq ["Could not save the user with user_id: 'u'. Unknown reason: Unique ID is too long (maximum is 100 characters)"]
  end

  it "does not confirm an email communication channel that has an invalid email" do
    importer = process_csv_data(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,None,active"
    )
    expect(importer.errors.length).to eq 1
    expect(importer.errors[0][1]).to eq "The email address associated with user 'user_1' is invalid (email: 'None')"
  end

  it "has the row on the error object" do
    importer = process_csv_data(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,None,active"
    )
    expect(importer.errors.length).to eq 1
    expect(importer.batch.sis_batch_errors.first.row_info).to eq "user_1,user1,User,Uno,None,active,2\n"
  end

  it "does not present an error for the same login_id with different case for same user" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,active",
      "user_1,USer1,User,Uno,user1@example.com,active"
    )
    expect(Pseudonym.where(sis_user_id: "user_1").first.unique_id).to eq "USer1"
  end

  it "uses an existing pseudonym if it wasn't imported from sis and has the same login id" do
    u = User.create!
    u.register!
    p_count = Pseudonym.count
    p = u.pseudonyms.create!(unique_id: "user2", password: "validpassword", password_confirmation: "validpassword", account: @account)
    expect(Pseudonym.by_unique_id("user1").first).to be_nil
    expect(Pseudonym.by_unique_id("user2").first).not_to be_nil
    expect(p.sis_user_id).to be_nil
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,active",
      "user_2,user2,User,Dos,user2@example.com,active"
    )
    p.reload
    expect(Pseudonym.by_unique_id("user1").first).not_to be_nil
    expect(Pseudonym.by_unique_id("user2").first).not_to be_nil
    expect(Pseudonym.count).to eq(p_count + 2)
    expect(p.sis_user_id).to eq "user_2"
  end

  it "strips white space on fields" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,short_name,sortable_name,email,status",
      "user_1  ,user1   ,User   ,Uno   ,The Uno   ,\"Uno, User   \",user@example.com   ,active  ",
      "   user_2,   user2,   User,   Dos,   The Dos,\"   Dos, User\",   user2@example.com,  active"
    )
    user = CommunicationChannel.by_path("user@example.com").first.user
    expect(user).not_to be_nil
    expect(user.name).to eq "User Uno"
    expect(user.sortable_name).to eq "Uno, User"
    expect(user.short_name).to eq "The Uno"
    p = user.pseudonyms.first
    expect(p.unique_id).to eq "user1"
    user = CommunicationChannel.by_path("user2@example.com").first.user
    expect(user).not_to be_nil
    expect(user.name).to eq "User Dos"
    expect(user.sortable_name).to eq "Dos, User"
    expect(user.short_name).to eq "The Dos"
    p = user.pseudonyms.first
    expect(p.unique_id).to eq "user2"
  end

  it "uses an existing communication channel" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,active"
    )
    p = Pseudonym.by_unique_id("user1").first
    user1 = p.user
    expect(user1.last_name).to eq "Uno"
    expect(user1.pseudonyms.count).to eq 1
    expect(p.communication_channel_id).not_to be_nil
    expect(user1.communication_channels.count).to eq 1
    expect(user1.communication_channels.first.path).to eq "user1@example.com"
    expect(p.sis_communication_channel_id).to eq p.communication_channel_id
    communication_channel(user1, { username: "user2@example.com", active_cc: true })

    # change to user2@example.com; because user1@example.com was sis created, it should disappear
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user2@example.com,active"
    )
    p.reload
    user1.reload
    expect(user1.pseudonyms.count).to eq 1
    expect(user1.communication_channels.count).to eq 2
    expect(user1.communication_channels.unretired.count).to eq 1
    expect(p.communication_channel_id).not_to be_nil
    expect(user1.communication_channels.unretired.first.path).to eq "user2@example.com"
    expect(p.sis_communication_channel_id).to eq p.communication_channel_id
    expect(p.communication_channel_id).to eq user1.communication_channels.unretired.first.id
  end

  it "works when a communication channel already exists, but there's no sis_communication_channel" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,,active"
    )
    p = Pseudonym.by_unique_id("user1").first
    user1 = p.user
    expect(user1.last_name).to eq "Uno"
    expect(user1.pseudonyms.count).to eq 1
    expect(p.communication_channel_id).to be_nil
    expect(user1.communication_channels.count).to eq 0
    expect(p.sis_communication_channel_id).to be_nil
    communication_channel(user1, { username: "user2@example.com", active_cc: true })

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user2@example.com,active"
    )
    p.reload
    user1.reload
    expect(user1.pseudonyms.count).to eq 1
    expect(user1.communication_channels.count).to eq 1
    expect(user1.communication_channels.unretired.count).to eq 1
    expect(p.communication_channel_id).not_to be_nil
    expect(user1.communication_channels.unretired.first.path).to eq "user2@example.com"
    expect(p.sis_communication_channel_id).to eq p.communication_channel_id
    expect(p.communication_channel_id).to eq user1.communication_channels.unretired.first.id
  end

  it "handles stickiness" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,,active"
    )
    p = Pseudonym.by_unique_id("user1").first
    p.unique_id = "user5"
    p.save!
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user3,User,Uno,,active"
    )
    p.reload
    expect(p.unique_id).to eq "user5"
    expect(Pseudonym.by_unique_id("user1").first).to be_nil
    expect(Pseudonym.by_unique_id("user3").first).to be_nil
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user3,User,Uno,,active",
      { override_sis_stickiness: true }
    )
    p.reload
    expect(p.unique_id).to eq "user3"
    expect(Pseudonym.by_unique_id("user1").first).to be_nil
    expect(Pseudonym.by_unique_id("user5").first).to be_nil
  end

  it "handles display name stickiness" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,short_name,email,status",
      "user_1,user1,User,Uno,The Uno,,active"
    )
    user = Pseudonym.by_unique_id("user1").first.user
    user.short_name = "The Amazing Uno"
    user.save!
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,short_name,email,status",
      "user_1,user1,User,Uno,The Uno-Dos,,active"
    )
    user.reload
    expect(user.short_name).to eq "The Amazing Uno"
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,short_name,email,status",
      "user_1,user1,User,Uno,The Uno-Dos,,active",
      { override_sis_stickiness: true }
    )
    user.reload
    expect(user.short_name).to eq "The Uno-Dos"
  end

  it "handles full name stickiness" do
    process_csv_data_cleanly(
      "user_id,login_id,full_name,email,status",
      "user_1,user1,User Uno,,active"
    )
    user = Pseudonym.by_unique_id("user1").first.user
    user.name = "The Amazing Uno"
    user.save!
    process_csv_data_cleanly(
      "user_id,login_id,full_name,email,status",
      "user_1,user1,User Uno,,active"
    )
    user.reload
    expect(user.name).to eq "The Amazing Uno"
    process_csv_data_cleanly(
      "user_id,login_id,full_name,email,status",
      "user_1,user1,User Uno,,active",
      { override_sis_stickiness: true }
    )
    user.reload
    expect(user.name).to eq "User Uno"
  end

  it "handles sortable name stickiness" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,sortable_name,email,status",
      "user_1,user1,User,Uno,\"One, User\",,active"
    )
    user = Pseudonym.by_unique_id("user1").first.user
    user.sortable_name = "Uno, The Amazing"
    user.save!
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,sortable_name,email,status",
      "user_1,user1,User,Uno,\"Two, User\",,active"
    )
    user.reload
    expect(user.sortable_name).to eq "Uno, The Amazing"
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,sortable_name,email,status",
      "user_1,user1,User,Uno,\"Two, User\",,active",
      { override_sis_stickiness: true }
    )
    user.reload
    expect(user.sortable_name).to eq "Two, User"
  end

  it "leaves users around always" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,active",
      "user_2,user2,User,Dos,user2@example.com,deleted"
    )
    user1 = @account.pseudonyms.where(sis_user_id: "user_1").first
    user2 = @account.pseudonyms.where(sis_user_id: "user_2").first
    expect(user1.workflow_state).to eq "active"
    expect(user2.workflow_state).to eq "deleted"
    expect(user1.user.workflow_state).to eq "registered"
    expect(user2.user.workflow_state).to eq "registered"
  end

  it "leaves users enrollments when there is another pseudonym" do
    process_csv_data_cleanly(
      "course_id,short_name,long_name,account_id,term_id,status",
      "test_1,TC 101,Test Course 101,,,active"
    )
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,active"
    )
    u = @account.pseudonyms.find_by(sis_user_id: "user_1").user
    pseudonym2 = u.pseudonyms.create!(account: @account, unique_id: "other_login@example.com")
    process_csv_data_cleanly(
      "course_id,user_id,role,section_id,status,associated_user_id,start_date,end_date",
      "test_1,user_1,teacher,,active,,,"
    )
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,deleted"
    )
    pseudonym1 = @account.pseudonyms.where(sis_user_id: "user_1").first
    expect(u.workflow_state).to eq "registered"
    expect(pseudonym1.workflow_state).to eq "deleted"
    expect(pseudonym2.workflow_state).to eq "active"
    expect(u.enrollments.take.workflow_state).to eq "active"
  end

  it "removes enrollments when a user is deleted" do
    process_csv_data_cleanly(
      "course_id,short_name,long_name,account_id,term_id,status",
      "test_1,TC 101,Test Course 101,,,active",
      "test_2,TC 102,Test Course 102,,,active"
    )
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user@example.com,active"
    )
    process_csv_data_cleanly(
      "section_id,course_id,name,status,start_date,end_date",
      "S001,test_1,Sec1,active,,",
      "S002,test_2,Sec1,active,,"
    )
    # the enrollments
    process_csv_data_cleanly(
      "course_id,user_id,role,section_id,status,associated_user_id,start_date,end_date",
      "test_1,user_1,teacher,,active,,,",
      ",user_1,student,S002,active,,,"
    )
    expect(@account.courses.where(sis_source_id: "test_1").first.teachers.map(&:name).include?("User Uno")).to be_truthy
    expect(@account.courses.where(sis_source_id: "test_2").first.students.map(&:name).include?("User Uno")).to be_truthy
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user@example.com,active"
    )
    expect(@account.courses.where(sis_source_id: "test_1").first.teachers.map(&:name).include?("User Uno")).to be_truthy
    expect(@account.courses.where(sis_source_id: "test_2").first.students.map(&:name).include?("User Uno")).to be_truthy
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user@example.com,deleted"
    )
    expect(@account.courses.where(sis_source_id: "test_1").first.teachers.map(&:name).include?("User Uno")).to be_falsey
    expect(@account.courses.where(sis_source_id: "test_2").first.students.map(&:name).include?("User Uno")).to be_falsey
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user@example.com,active"
    )
    expect(@account.courses.where(sis_source_id: "test_1").first.teachers.map(&:name).include?("User Uno")).to be_falsey
    expect(@account.courses.where(sis_source_id: "test_2").first.students.map(&:name).include?("User Uno")).to be_falsey
    process_csv_data_cleanly(
      "course_id,user_id,role,section_id,status,associated_user_id,start_date,end_date",
      "test_1,user_1,teacher,,active,,,",
      ",user_1,student,S002,active,,,"
    )
    expect(@account.courses.where(sis_source_id: "test_1").first.teachers.map(&:name).include?("User Uno")).to be_truthy
    expect(@account.courses.where(sis_source_id: "test_2").first.students.map(&:name).include?("User Uno")).to be_truthy
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user@example.com,active"
    )
    expect(@account.courses.where(sis_source_id: "test_1").first.teachers.map(&:name).include?("User Uno")).to be_truthy
    expect(@account.courses.where(sis_source_id: "test_2").first.students.map(&:name).include?("User Uno")).to be_truthy
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user@example.com,deleted"
    )
    expect(@account.courses.where(sis_source_id: "test_1").first.teachers.map(&:name).include?("User Uno")).to be_falsey
    expect(@account.courses.where(sis_source_id: "test_2").first.students.map(&:name).include?("User Uno")).to be_falsey
  end

  it "removes linked observer enrollments when a user is deleted" do
    process_csv_data_cleanly(
      "course_id,short_name,long_name,account_id,term_id,status",
      "test_1,TC 101,Test Course 101,,,active"
    )
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user@example.com,active",
      "user_2,user2,User,Dos,user2@example.com,active"
    )
    process_csv_data_cleanly(
      "student_id,observer_id,status",
      "user_1,user_2,active"
    )
    process_csv_data_cleanly(
      "course_id,user_id,role,section_id,status,associated_user_id,start_date,end_date",
      "test_1,user_1,student,,active,,,"
    )
    course = @account.courses.where(sis_source_id: "test_1").first
    observer_enrollment = course.observer_enrollments.first
    expect(observer_enrollment).to be_active
    expect(observer_enrollment.user.pseudonym.sis_user_id).to eq "user_2"

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user@example.com,deleted"
    )
    expect(observer_enrollment.reload).to be_deleted
  end

  it "removes group_memberships when a user is deleted" do
    process_csv_data_cleanly(
      "course_id,short_name,long_name,account_id,term_id,status",
      "test_1,TC 101,Test Course 101,,,active"
    )
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user@example.com,active"
    )
    process_csv_data_cleanly(
      "course_id,user_id,role,section_id,status,associated_user_id,start_date,end_date",
      "test_1,user_1,student,,active,,,"
    )
    c = @account.courses.where(sis_source_id: "test_1").first
    g = c.groups.create(name: "group1")
    u = Pseudonym.where(sis_user_id: "user_1").first.user
    gm = g.group_memberships.create(user: u, workflow_state: "accepted")
    g.update!(leader_id: u.id)
    expect(gm.workflow_state).to eq "accepted"

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user@example.com,deleted"
    )
    expect(gm.reload.workflow_state).to eq "deleted"
    expect(g.reload.leader_id).to be_nil
  end

  it "creates rollback data" do
    batch1 = @account.sis_batches.create! { |sb| sb.data = {} }
    process_csv_data_cleanly(
      "course_id,short_name,long_name,account_id,term_id,status",
      "test_1,TC 101,Test Course 101,,,active"
    )
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user@example.com,active"
    )
    process_csv_data_cleanly(
      "course_id,user_id,role,section_id,status,associated_user_id,start_date,end_date",
      "test_1,user_1,student,,active,,,"
    )
    c = @account.courses.where(sis_source_id: "test_1").first
    g = c.groups.create(name: "group1")
    p = @account.pseudonyms.find_by(sis_user_id: "user_1")
    u = p.user
    gm = g.group_memberships.create(user: u, workflow_state: "accepted")
    expect(gm.workflow_state).to eq "accepted"

    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user@example.com,deleted",
      batch: batch1
    )
    expect(batch1.roll_back_data.count).to eq 4
    expect(batch1.roll_back_data.pluck(:context_type).sort).to eq %w[CommunicationChannel Enrollment GroupMembership Pseudonym]
    batch1.restore_states_for_batch
    expect(p.reload.workflow_state).to eq "active"
    expect(u.communication_channels.active.count).to eq 1
    expect(gm.reload.workflow_state).to eq "accepted"
  end

  it "removes account memberships when a user is deleted" do
    sis_user = user_model
    @badmin = user_with_managed_pseudonym(name: "bad admin", account: @account, sis_user_id: "badmin")
    tie_user_to_account(@badmin, account: @account)
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "badmin,badmin,Bad,Admin,badmin@example.com,deleted",
      user: sis_user
    )
    @badmin.reload
    expect(@badmin.account_users.active.pluck(:id)).to_not include(@badmin.id)
  end

  it "removes subaccount memberships when a user is deleted" do
    sis_user = user_model
    @subaccount = @account.sub_accounts.create! name: "subbie"
    @badmin = user_with_managed_pseudonym(name: "bad admin", account: @subaccount, sis_user_id: "badmin")
    tie_user_to_account(@badmin, account: @subaccount)
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "badmin,badmin,Bad,Admin,badmin@example.com,deleted",
      user: sis_user
    )
    @badmin.reload
    expect(@badmin.account_users.active.pluck(:id)).to_not include(@badmin.id)
  end

  context "account associations" do
    before do
      process_csv_data_cleanly(
        "account_id,parent_account_id,name,status",
        "A001,,Humanities,active",
        "A002,A001,English,active",
        "A003,A002,English Literature,active",
        "A004,,Awesomeness,active"
      )
    end

    it "works with users created as both active and deleted" do
      process_csv_data_cleanly(
        "user_id,login_id,first_name,last_name,email,status",
        "user_1,user1,User,Uno,user1@example.com,active",
        "user_2,user2,User,Dos,user2@example.com,deleted"
      )
      user1 = @account.pseudonyms.where(sis_user_id: "user_1").first
      user2 = @account.pseudonyms.where(sis_user_id: "user_2").first
      expect(user1.user.user_account_associations.map { |uaa| [uaa.account_id, uaa.depth] }).to eq [[@account.id, 0]]
      expect(user2.user.user_account_associations).to be_empty

      process_csv_data_cleanly(
        "user_id,login_id,first_name,last_name,email,status",
        "user_1,user1,User,Uno,user1@example.com,deleted"
      )
      user1.reload
      expect(user1.user.user_account_associations).to be_empty
    end

    it "works when a user gets undeleted" do
      process_csv_data_cleanly(
        "user_id,login_id,first_name,last_name,email,status",
        "user_1,user1,User,Uno,user1@example.com,active"
      )
      user = @account.pseudonyms.where(sis_user_id: "user_1").first
      expect(user.user.user_account_associations.map { |uaa| [uaa.account_id, uaa.depth] }).to eq [[@account.id, 0]]

      process_csv_data_cleanly(
        "user_id,login_id,first_name,last_name,email,status",
        "user_1,user1,User,Uno,user1@example.com,deleted"
      )
      user = @account.pseudonyms.where(sis_user_id: "user_1").first
      expect(user.user.user_account_associations).to be_empty

      process_csv_data_cleanly(
        "user_id,login_id,first_name,last_name,email,status",
        "user_1,user1,User,Uno,user1@example.com,active"
      )
      user = @account.pseudonyms.where(sis_user_id: "user_1").first
      expect(user.user.user_account_associations.map { |uaa| [uaa.account_id, uaa.depth] }).to eq [[@account.id, 0]]
    end

    it "deletes user enrollments for the current account when deleted, and update appropriate account associations" do
      @account1 = @account
      @account2 = account_model
      @account = @account1
      sis_user = user_model
      process_csv_data_cleanly(
        "user_id,login_id,first_name,last_name,email,status",
        "user_1,user1,User,Uno,user1@example.com,active",
        user: sis_user
      )
      process_csv_data_cleanly(
        "account_id,parent_account_id,name,status",
        "A001,,TestAccount1,active",
        "A002,A001,TestAccount1A,active",
        user: sis_user
      )
      process_csv_data_cleanly(
        "course_id,short_name,long_name,account_id,term_id,status,start_date,end_date",
        "C001,TC 101,Test Course 1,A002,,active,,",
        user: sis_user
      )
      process_csv_data_cleanly(
        "section_id,course_id,name,status,start_date,end_date",
        "S001,C001,Test Course 1,active,,",
        user: sis_user
      )
      expect(@account.pseudonyms.where(sis_user_id: "user_1").first.user.user_account_associations.map(&:account_id)).to eq [@account.id]
      process_csv_data_cleanly(
        "course_id,user_id,role,section_id,status,associated_user_id,start_date,end_date",
        "C001,user_1,teacher,,active,,,",
        user: sis_user
      )
      @pseudo1 = @account.pseudonyms.where(sis_user_id: "user_1").first
      expect(@pseudo1.user.user_account_associations.map(&:account_id).sort).to eq [@account.id, Account.where(sis_source_id: "A002").first.id, Account.where(sis_source_id: "A001").first.id].sort

      @account = @account2
      process_csv_data_cleanly(
        "user_id,login_id,first_name,last_name,email,status",
        "user_1,user1,User,Uno,user1@example.com,active",
        user: sis_user
      )
      process_csv_data_cleanly(
        "account_id,parent_account_id,name,status",
        "A101,,TestAccount1,active",
        "A102,A101,TestAccount1A,active",
        user: sis_user
      )
      process_csv_data_cleanly(
        "course_id,short_name,long_name,account_id,term_id,status,start_date,end_date",
        "C001,TC 101,Test Course 1,A102,,active,,",
        user: sis_user
      )
      process_csv_data_cleanly(
        "section_id,course_id,name,status,start_date,end_date",
        "S001,C001,Test Course 1,active,,",
        user: sis_user
      )
      expect(@account.pseudonyms.where(sis_user_id: "user_1").first.user.user_account_associations.map(&:account_id)).to eq [@account.id]
      process_csv_data_cleanly(
        "course_id,user_id,role,section_id,status,associated_user_id,start_date,end_date",
        "C001,user_1,teacher,,active,,,",
        user: sis_user
      )
      @pseudo2 = @account.pseudonyms.where(sis_user_id: "user_1").first
      expect(@pseudo2.user.user_account_associations.map(&:account_id).sort).to eq [@account.id, Account.where(sis_source_id: "A102").first.id, Account.where(sis_source_id: "A101").first.id].sort

      UserMerge.from(@pseudo1.user).into(@pseudo2.user)
      @user = @account1.pseudonyms.where(sis_user_id: "user_1").first.user
      expect(@account2.pseudonyms.where(sis_user_id: "user_1").first.user).to eq @user

      expect(@user.user_account_associations.map(&:account_id).sort).to eq [@account1.id, @account2.id, Account.where(sis_source_id: "A002").first.id, Account.where(sis_source_id: "A001").first.id, Account.where(sis_source_id: "A102").first.id, Account.where(sis_source_id: "A101").first.id].sort

      @account = @account1
      process_csv_data_cleanly(
        "user_id,login_id,first_name,last_name,email,status",
        "user_1,user1,User,Uno,user1@example.com,deleted",
        user: sis_user
      )
      @account1.pseudonyms.where(sis_user_id: "user_1").first.tap do |pseudo|
        expect(pseudo.user.user_account_associations.map(&:account_id).sort).to eq [@account2.id, Account.where(sis_source_id: "A102").first.id, Account.where(sis_source_id: "A101").first.id].sort
        expect(pseudo.workflow_state).to eq "deleted"
        expect(pseudo.user.workflow_state).to eq "registered"
      end
      @account2.pseudonyms.where(sis_user_id: "user_1").first.tap do |pseudo|
        expect(pseudo.user.user_account_associations.map(&:account_id).sort).to eq [@account2.id, Account.where(sis_source_id: "A102").first.id, Account.where(sis_source_id: "A101").first.id].sort
        expect(pseudo.workflow_state).to eq "active"
        expect(pseudo.user.workflow_state).to eq "registered"
      end
      process_csv_data_cleanly(
        "user_id,login_id,first_name,last_name,email,status",
        "user_1,user1,User,Uno,user1@example.com,active",
        user: sis_user
      )
      @account1.pseudonyms.where(sis_user_id: "user_1").first.tap do |pseudo|
        expect(pseudo.user.user_account_associations.map(&:account_id).sort).to eq [@account2.id, Account.where(sis_source_id: "A102").first.id, Account.where(sis_source_id: "A101").first.id, @account1.id].sort
        expect(pseudo.workflow_state).to eq "active"
        expect(pseudo.user.workflow_state).to eq "registered"
      end
      @account2.pseudonyms.where(sis_user_id: "user_1").first.tap do |pseudo|
        expect(pseudo.user.user_account_associations.map(&:account_id).sort).to eq [@account2.id, Account.where(sis_source_id: "A102").first.id, Account.where(sis_source_id: "A101").first.id, @account1.id].sort
        expect(pseudo.workflow_state).to eq "active"
        expect(pseudo.user.workflow_state).to eq "registered"
      end
    end
  end

  it "does not steal the communication channel of the previous user" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,active"
    )
    user_1 = Pseudonym.by_unique_id("user1").first.user
    expect(user_1.email).to eq "user1@example.com"
    expect(user_1.pseudonym.sis_communication_channel).to eq user_1.email_channel
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,active",
      "user_2,user2,User,Dos,user2@example.com,active"
    )
    user_1 = Pseudonym.by_unique_id("user1").first.user
    user_2 = Pseudonym.by_unique_id("user2").first.user
    expect(user_1.email).to eq "user1@example.com"
    expect(user_2.email).to eq "user2@example.com"
    expect(user_1.pseudonym.sis_communication_channel).to eq user_1.email_channel
    expect(user_2.pseudonym.sis_communication_channel).to eq user_2.email_channel
  end

  it "clears deleted_at when restoring a pseudonym" do
    user = user_with_pseudonym(active_all: 1, sis_user_id: "user_1", account: @account)
    user.destroy
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,#{@pseudonym.unique_id},User,Uno,#{@pseudonym.unique_id},active",
      { override_sis_stickiness: true }
    )
    ps = user.reload.pseudonyms.take
    expect(ps.workflow_state).to eq "active"
    expect(ps.deleted_at).to be_nil
  end

  it "does not resurrect a non SIS user" do
    @non_sis_user = user_with_pseudonym(active_all: 1)
    @non_sis_user.remove_from_root_account(Account.default)
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,#{@pseudonym.unique_id},User,Uno,#{@pseudonym.unique_id},active"
    )
    user_1 = Pseudonym.where(sis_user_id: "user_1").first.user
    expect(user_1).not_to eq @non_sis_user
    expect(user_1.pseudonym).not_to eq @pseudonym
  end

  it "does not resurrect a non SIS pseudonym" do
    @non_sis_user = user_with_pseudonym(active_all: 1)
    @pseudonym = @user.pseudonyms.create!(unique_id: "user1", account: Account.default)
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,active"
    )
    user_1 = Pseudonym.where(sis_user_id: "user_1").first.user
    expect(user_1).not_to eq @non_sis_user
    expect(user_1.pseudonym).not_to eq @pseudonym
  end

  it "errors nicely when resurrecting an SIS user that conflicts with an active user" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,deleted"
    )
    @non_sis_user = user_with_pseudonym(active_all: 1)
    @pseudonym = @non_sis_user.pseudonyms.create!(unique_id: "user1", account: @account)
    importer = process_csv_data(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1,user1,User,Uno,user1@example.com,active"
    )
    expect(importer.errors.length).to eq 1
    expect(importer.errors.last.last).to eq "An existing Canvas user with the Canvas ID #{@non_sis_user.id} has already claimed user_1's user_id requested login information, skipping"
  end

  it "sets authentication providers" do
    ap = @account.authentication_providers.create!(auth_type: "google")
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status,authentication_provider_id",
      "user_1,user1,User,Uno,user1@example.com,active,google"
    )
    p = @account.pseudonyms.active.where(sis_user_id: "user_1").first
    expect(p.authentication_provider).to eq ap
  end

  it "warns on invalid authentication providers" do
    importer = process_csv_data(
      "user_id,login_id,first_name,last_name,email,status,authentication_provider_id",
      "user_1,user1,User,Uno,user1@example.com,active,google"
    )
    expect(importer.errors.length).to eq 1
    expect(importer.errors.last.last).to eq "unrecognized authentication provider google for user_1, skipping"
    expect(@account.pseudonyms.active.where(sis_user_id: "user_1").first).to be_nil
  end

  it "allows UTF-8 in usernames" do
    process_csv_data_cleanly(
      "user_id,login_id,first_name,last_name,email,status",
      "user_1ö,user1ö,User,Unö,user@example.com,active"
    )
    user = CommunicationChannel.by_path("user@example.com").first.user
    expect(user.account).to eql(@account)
    expect(user.name).to eql("User Unö")
    expect(user.short_name).to eql("User Unö")

    expect(user.pseudonyms.count).to be(1)
    pseudonym = user.pseudonyms.first
    expect(pseudonym.unique_id).to eql("user1ö")
    expect(pseudonym.sis_user_id).to eql("user_1ö")
  end

  it "forbids NULL character in imported fields" do
    importer = process_csv_data(
      "user_id,login_id,first_name,last_name,email,status",
      "user_\u00001,user1,User,Uno,user1@example.com,active"
    )

    expect(importer.errors.length).to eq 1
    expect(CommunicationChannel.by_path("user1@example.com").first).to be_nil

    expect(importer.errors.map(&:last).first).to eql("Some of the fields contain NULL character")
  end

  it "validates ccs on create" do
    importer = process_csv_data(
      "user_id,login_id,first_name,last_name,email,status",
      "user_2,user2,User,Dos,invalid_at_example.com,active"
    )
    expect(importer.errors.length).to eq 1
  end

  it "can suspend a user" do
    process_csv_data(
      "user_id,login_id,first_name,last_name,email,status",
      "user_2,user2,User,Dos,user@example.com,active"
    )
    process_csv_data(
      "user_id,login_id,first_name,last_name,email,status",
      "user_2,user2,User,Dos,user@example.com,suspended"
    )
    expect(Pseudonym.find_by(sis_user_id: "user_2")).to be_suspended
  end

  it "can create a user suspended" do
    process_csv_data(
      "user_id,login_id,first_name,last_name,email,status",
      "user_2,user2,User,Dos,user@example.com,suspended"
    )
    p = Pseudonym.find_by(sis_user_id: "user_2")
    expect(p).to be_suspended
    expect(p.user).to be_registered
  end

  it "undeletes a user to suspended" do
    process_csv_data(
      "user_id,login_id,first_name,last_name,email,status",
      "user_2,user2,User,Dos,user@example.com,deleted"
    )
    process_csv_data(
      "user_id,login_id,first_name,last_name,email,status",
      "user_2,user2,User,Dos,user@example.com,suspended"
    )
    p = Pseudonym.find_by(sis_user_id: "user_2")
    expect(p).to be_suspended
    expect(p.user).to be_registered
  end

  context "sharding" do
    specs_require_sharding

    it "updates cc from users shard" do
      @shard1.activate do
        @shard1_cc = communication_channel_model(path: "taken@example.com")
      end

      @cc = communication_channel_model(path: "taken@example.com")

      # make login on local shard to find cross shard user during import.
      @account.pseudonyms.create!(user: @shard1_cc.user, unique_id: "user2", sis_user_id: "user_2")

      process_csv_data_cleanly(
        "user_id,login_id,first_name,last_name,email,status,integration_id",
        "user_2,user2,User,Dos,taken@example.com,active,9000"
      )
      expect(@shard1_cc.reload.workflow_state).to eq "active"
      expect(@cc.reload.workflow_state).to eq "unconfirmed"
    end

    it "creates ccs on users shard" do
      @shard1.activate { @shard1_user = User.create!(name: "shard1 user") }
      # make login on local shard to find cross shard user during import.
      @account.pseudonyms.create!(user: @shard1_user, unique_id: "user2", sis_user_id: "user_2")

      process_csv_data_cleanly(
        "user_id,login_id,first_name,last_name,email,status,integration_id",
        "user_2,user2,User,Dos,shard1@example.com,active,9000"
      )
      expect(@shard1_user.email).to eq "shard1@example.com"
    end
  end
end
