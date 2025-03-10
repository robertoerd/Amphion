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

require_relative "../feature_flag_helper"

describe BrandConfigsController do
  include FeatureFlagHelper

  before :once do
    @account = Account.default
    @bc = BrandConfig.create(variables: { "ic-brand-primary" => "#321" })
  end

  describe "#index" do
    it "allows authorized admin to view" do
      admin = account_admin_user(account: @account)
      user_session(admin)
      get "index", params: { account_id: @account.id }
      assert_status(200)
    end

    it "does not allow non admin access" do
      user = user_with_pseudonym(active_all: true)
      user_session(user)
      get "index", params: { account_id: @account.id }
      assert_status(401)
    end

    it "requires branding enabled on the account" do
      subaccount = @account.sub_accounts.create!(name: "sub")
      admin = account_admin_user(account: @account)
      user_session(admin)
      get "index", params: { account_id: subaccount.id }
      assert_status(302)
      expect(flash[:error]).to match(/cannot edit themes/)
    end
  end

  describe "#new" do
    it "allows authorized admin to see create" do
      admin = account_admin_user(account: @account)
      user_session(admin)
      get "new", params: { brand_config: @bc, account_id: @account.id }
      assert_status(200)
    end

    it "does not allow non admin access" do
      user = user_with_pseudonym(active_all: true)
      user_session(user)
      get "new", params: { brand_config: @bc, account_id: @account.id }
      assert_status(401)
    end

    it "creates variableSchema based on parent configs" do
      @account.brand_config_md5 = @bc.md5
      @account.settings = { global_includes: true, sub_account_includes: true }
      @account.save!

      @subaccount = Account.create!(parent_account: @account)
      @sub_bc = BrandConfig.create(variables: { "ic-brand-global-nav-bgd" => "#123" }, parent_md5: @bc.md5)
      @subaccount.brand_config_md5 = @sub_bc.md5
      @subaccount.save!

      admin = account_admin_user(account: @subaccount)
      user_session(admin)

      get "new", params: { brand_config: @sub_bc, account_id: @subaccount.id }

      variable_schema = assigns[:js_env][:variableSchema]
      variable_schema.each do |s|
        expect(s["group_name"]).to be_present
      end

      vars = variable_schema.pluck("variables").flatten
      vars.each do |v|
        expect(v["human_name"]).to be_present
      end

      expect(vars.detect { |v| v["variable_name"] == "ic-brand-header-image" }["helper_text"]).to be_present

      primary = vars.detect { |v| v["variable_name"] == "ic-brand-primary" }
      expect(primary["default"]).to eq "#321"
    end

    context "when the login_registration_ui_identity feature flag is enabled/disabled" do
      let_once(:admin) { account_admin_user(account: @account) }

      before do
        user_session(admin)
      end

      it "applies the login brand config filter when the feature flag is enabled" do
        mock_feature_flag(:login_registration_ui_identity, true, [@account])
        expect(Login::LoginBrandConfigFilter).to receive(:filter).with(instance_of(Array)).and_call_original
        get "new", params: { brand_config: @bc, account_id: @account.id }
        assert_status(200)
      end

      it "does not apply the login brand config filter when the feature flag is disabled" do
        mock_feature_flag(:login_registration_ui_identity, false, [@account])
        expect(Login::LoginBrandConfigFilter).not_to receive(:filter)
        get "new", params: { brand_config: @bc, account_id: @account.id }
        assert_status(200)
      end
    end
  end

  describe "#create" do
    let_once(:admin) { account_admin_user(account: @account) }
    let(:bcin) { { variables: { "ic-brand-primary" => "#000000" } } }

    it "allows authorized admin to create" do
      user_session(admin)
      post "create", params: { account_id: @account.id, brand_config: bcin }
      assert_status(200)
      json = response.parsed_body
      expect(json["brand_config"]["variables"]["ic-brand-primary"]).to eq "#000000"
    end

    it "does not fail when a brand_config is not passed" do
      user_session(admin)
      post "create", params: { account_id: @account.id }
      assert_status(200)
    end

    it "does not allow non admin access" do
      user = user_with_pseudonym(active_all: true)
      user_session(user)
      post "create", params: { account_id: @account.id, brand_config: bcin }
      assert_status(401)
    end

    it "returns an existing brand config" do
      user_session(admin)
      post "create", params: { account_id: @account.id,
                               brand_config: {
                                 variables: {
                                   "ic-brand-primary" => "#321"
                                 }
                               } }
      assert_status(200)
      json = response.parsed_body
      expect(json["brand_config"]["md5"]).to eq @bc.md5
    end

    it "uploads a js file successfully" do
      user_session(admin)
      tf = Tempfile.new("test.js")
      tf.write("test")
      uf = ActionDispatch::Http::UploadedFile.new(tempfile: tf, filename: "test.js")
      request.headers["CONTENT_TYPE"] = "multipart/form-data"
      expect_any_instance_of(Attachment).to receive(:save_to_storage).and_return(true)

      post "create", params: { account_id: @account.id, brand_config: bcin, js_overrides: uf }
      assert_status(200)

      json = response.parsed_body
      expect(json["brand_config"]["js_overrides"]).to be_present
    end
  end

  describe "#destroy" do
    it "allows authorized admin to create" do
      admin = account_admin_user(account: @account)
      user_session(admin)
      session[:brand_config] = { md5: @bc.md5, type: :base }
      delete "destroy", params: { account_id: @account.id }
      assert_status(302)
      expect(session[:brand_config]).to be_nil
      expect { @bc.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "does not allow non admin access" do
      user = user_with_pseudonym(active_all: true)
      user_session(user)
      delete "destroy", params: { account_id: @account.id }
      assert_status(401)
    end
  end

  describe "#save_to_account" do
    it "allows authorized admin to create" do
      admin = account_admin_user(account: @account)
      user_session(admin)
      post "save_to_account", params: { account_id: @account.id }
      assert_status(200)
    end

    it "regenerates sub accounts" do
      subbc = BrandConfig.create(variables: { "ic-brand-primary" => "#111" })
      @account.sub_accounts.create!(name: "Sub", brand_config_md5: subbc.md5)

      admin = account_admin_user(account: @account)
      user_session(admin)
      session[:brand_config] = { md5: @bc.md5, type: :base }
      post "save_to_account", params: { account_id: @account.id }
      assert_status(200)
      json = response.parsed_body
      expect(json["subAccountProgresses"]).to be_present
    end

    it "does not allow non admin access" do
      user = user_with_pseudonym(active_all: true)
      user_session(user)
      post "save_to_account", params: { account_id: @account.id }
      assert_status(401)
    end
  end

  describe "#save_to_user_session" do
    it "allows authorized admin to create" do
      admin = account_admin_user(account: @account)
      user_session(admin)
      post "save_to_user_session", params: { account_id: @account.id, brand_config_md5: @bc.md5 }
      assert_status(302)
      expect(session[:brand_config]).to eq({ md5: @bc.md5, type: :base })
    end

    it "allows authorized admin to remove" do
      admin = account_admin_user(account: @account)
      user_session(admin)
      session[:brand_config] = { md5: @bc.md5, type: :base }
      post "save_to_user_session", params: { account_id: @account.id, brand_config_md5: "" }
      assert_status(302)
      expect(session[:brand_config]).to eq({ md5: nil, type: :default })
      expect { @bc.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "does not allow non admin access" do
      user = user_with_pseudonym(active_all: true)
      user_session(user)
      post "save_to_user_session", params: { account_id: @account.id, brand_config_md5: @bc.md5 }
      assert_status(401)
      expect(session[:brand_config]).to be_nil
    end
  end
end
