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

describe TokensController do
  describe "developer keys" do
    context "not logged in" do
      it "requires being logged in to create an access token" do
        post "create", params: { access_token: { purpose: "test" } }
        expect(response).to be_redirect
        expect(assigns[:token]).to be_nil
      end

      it "requires being logged in to delete an access token" do
        delete "destroy", params: { user_id: "self", id: 5 }
        expect(response).to be_redirect
      end

      it "requires being logged in to retrieve an access token" do
        get "show", params: { id: 5 }
        expect(response).to be_redirect
      end
    end

    context "logged in" do
      before :once do
        user_factory(active_user: true)
      end

      before do
        user_session(@user)
      end

      it "allows creating an access token" do
        post "create", params: { access_token: { purpose: "test", permanent_expires_at: "jun 1 2011" } }
        expect(response).to be_successful
        expect(assigns[:token]).not_to be_nil
        expect(assigns[:token].developer_key).to eq DeveloperKey.default
        expect(assigns[:token].purpose).to eq "test"
        expect(assigns[:token].permanent_expires_at.to_date).to eq Time.zone.parse("jun 1 2011").to_date
      end

      it "does not allow creating an access token while masquerading" do
        Account.site_admin.account_users.create!(user: @user)
        session[:become_user_id] = user_with_pseudonym.id

        post "create", params: { access_token: { purpose: "test", permanent_expires_at: "jun 1 2011" } }
        assert_status(401)
      end

      it "does not allow explicitly setting the token value" do
        post "create", params: { access_token: { purpose: "test", permanent_expires_at: "jun 1 2011", token: "mytoken" } }
        expect(response).to be_successful
        expect(response.body).not_to match(/mytoken/)
        expect(assigns[:token]).not_to be_nil
        expect(assigns[:token].full_token).not_to match(/mytoken/)
        expect(response.body).to match(/#{assigns[:token].full_token}/)
        expect(assigns[:token].developer_key).to eq DeveloperKey.default
        expect(assigns[:token].purpose).to eq "test"
        expect(assigns[:token].permanent_expires_at.to_date).to eq Time.zone.parse("jun 1 2011").to_date
      end

      it "allows deleting an access token" do
        token = @user.access_tokens.create!
        expect(token.user_id).to eq @user.id
        delete "destroy", params: { user_id: "self", id: token.id }
        expect(response).to be_successful
        expect(token.reload).to be_deleted
      end

      it "does not allow deleting an access token while masquerading" do
        token = @user.access_tokens.create!
        expect(token.user_id).to eq @user.id
        Account.site_admin.account_users.create!(user: @user)
        session[:become_user_id] = user_with_pseudonym.id

        delete "destroy", params: { user_id: "self", id: token.id }
        assert_status(401)
      end

      it "does not allow deleting someone else's access token" do
        user2 = User.create!
        token = user2.access_tokens.create!
        expect(token.user_id).to eq user2.id
        delete "destroy", params: { user_id: "self", id: token.id }
        assert_status(404)
      end

      it "allows retrieving an access token, but not give the full token string" do
        token = @user.access_tokens.new
        token.developer_key = DeveloperKey.default
        token.save!
        expect(token.user_id).to eq @user.id
        expect(token.manually_created?).to be true
        get "show", params: { id: token.id }
        expect(response).to be_successful
        expect(assigns[:token]).to eq token
        expect(response.body).to match(/#{assigns[:token].token_hint}/)
      end

      it "does not include token for non-manually-generated tokens" do
        key = DeveloperKey.create!
        token = @user.access_tokens.create!(developer_key: key)
        expect(token.user_id).to eq @user.id
        expect(token.manually_created?).to be false
        get "show", params: { id: token.id }
        expect(response).to be_successful
        expect(assigns[:token]).to eq token
        expect(response.body).not_to match(/#{assigns[:token].token_hint}/)
      end

      it "does not allow retrieving someone else's access token" do
        user2 = User.create!
        token = user2.access_tokens.create!
        expect(token.user_id).to eq user2.id
        get "show", params: { id: token.id }
        assert_status(404)
      end

      it "allows updating a token" do
        token = @user.access_tokens.new
        token.developer_key = DeveloperKey.default
        token.save!
        expect(token.user_id).to eq @user.id
        expect(token.manually_created?).to be true
        put "update", params: { id: token.id, access_token: { purpose: "new purpose" } }
        expect(response).to be_successful
        expect(assigns[:token]).to eq token
        expect(assigns[:token].purpose).to eq "new purpose"
        expect(response.body).to match(/#{assigns[:token].token_hint}/)
      end

      it "allows regenerating a manually generated token" do
        token = @user.access_tokens.new
        token.developer_key = DeveloperKey.default
        token.save!
        expect(token.user_id).to eq @user.id
        expect(token.manually_created?).to be true
        put "update", params: { id: token.id, access_token: { regenerate: "1" } }
        expect(response).to be_successful
        expect(assigns[:token]).to eq token
        expect(assigns[:token].crypted_token).not_to eq token.crypted_token
        expect(response.body).to match(/#{assigns[:token].full_token}/)
      end

      it "does not allow regenerating a token while masquerading" do
        token = @user.access_tokens.new
        token.developer_key = DeveloperKey.default
        token.save!
        expect(token.user_id).to eq @user.id
        expect(token.manually_created?).to be true
        Account.site_admin.account_users.create!(user: @user)
        session[:become_user_id] = user_with_pseudonym.id
        put "update", params: { id: token.id, access_token: { regenerate: "1" } }
        assert_status(401)
      end

      it "does not allow regenerating a non-manually-generated token" do
        key = DeveloperKey.create!
        token = @user.access_tokens.create!(developer_key: key)
        expect(token.user_id).to eq @user.id
        expect(token.manually_created?).to be false
        put "update", params: { id: token.id, access_token: { regenerate: "1" } }
        expect(response).to be_successful
        expect(assigns[:token]).to eq token
        expect(assigns[:token].crypted_token).to eq token.crypted_token
        expect(response.body).not_to match(/#{assigns[:token].token_hint}/)
      end

      it "does not allow updating someone else's token" do
        user2 = User.create!
        token = user2.access_tokens.create!
        expect(token.user_id).to eq user2.id
        put "update", params: { id: token.id }
        assert_status(404)
      end

      context "with admin manage access tokens feature flag on" do
        before(:once) { Account.default.root_account.enable_feature!(:admin_manage_access_tokens) }

        context "with limit_personal_access_tokens setting on" do
          before(:once) { Account.default.change_root_account_setting!(:limit_personal_access_tokens, true) }

          context "as non-admin" do
            it "does not allow creating an access token" do
              post "create", params: { access_token: { purpose: "test", permanent_expires_at: "" } }
              assert_status(401)
            end

            it "does not allow updating an access token" do
              token = @user.access_tokens.create!
              put "update", params: { id: token.id, access_token: { regenerate: "1" } }
              assert_status(401)
            end
          end

          context "as admin" do
            before(:once) { @admin = account_admin_user }

            before { user_session(@admin) }

            it "allows creating an access token" do
              post "create", params: { access_token: { purpose: "test", permanent_expires_at: "" } }
              assert_status(200)
            end

            it "allows updating an access token" do
              token = @admin.access_tokens.create!
              put "update", params: { id: token.id, access_token: { regenerate: "1" } }
              assert_status(200)
            end
          end
        end

        context "with limit_personal_access_tokens setting off" do
          before(:once) { Account.default.change_root_account_setting!(:limit_personal_access_tokens, false) }

          context "as non-admin" do
            it "allows creating an access token" do
              post "create", params: { access_token: { purpose: "test", permanent_expires_at: "" } }
              assert_status(200)
            end

            it "allows updating an access token" do
              token = @user.access_tokens.create!
              put "update", params: { id: token.id, access_token: { regenerate: "1" } }
              assert_status(200)
            end
          end
        end
      end
    end
  end
end
