require 'spec_helper'
require 'perm'

RSpec.describe 'Perm', type: :integration, skip: ENV.fetch('CF_RUN_PERM_SPECS') { 'false' } != 'true' do
  include ControllerHelpers

  let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }
  let(:assignee) { VCAP::CloudController::User.make }
  let(:uaa_target) { 'test.example.com' }
  let(:actor) { CloudFoundry::Perm::V1::Models::Actor.new(id: assignee.guid, issuer: uaa_target) }

  let(:perm_host) { ENV.fetch('PERM_RPC_HOST') { 'localhost:6283' } }
  let(:client) { CloudFoundry::Perm::V1::Client.new(perm_host) }

  before do
    TestConfig.config[:perm] = {
      enabled: true,
      host: perm_host
    }

    allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:usernames_for_ids).with([assignee.guid]).and_return({ assignee.guid => assignee.username })
    allow_any_instance_of(VCAP::CloudController::UaaTokenDecoder).to receive(:uaa_issuer).and_return(uaa_target)

    set_current_user_as_admin(iss: uaa_target)
  end

  describe 'POST /v2/organizations' do
    [:user, :manager, :auditor, :billing_manager].each do |role|
      it "creates the org-#{role}-<org_id> role" do
        post '/v2/organizations', { name: 'v2-org' }.to_json

        expect(last_response.status).to eq(201)

        json_body = JSON.parse(last_response.body)
        org_id = json_body['metadata']['guid']
        role_name = "org-#{role}-#{org_id}"

        role = client.get_role(role_name)
        expect(role.name).to eq(role_name)
        expect(role.id).not_to be_nil
      end
    end
  end

  describe 'PUT /v2/ogranizations/:guid/:role/:user_guid' do
    let(:org) { VCAP::CloudController::Organization.make }

    [:user, :manager, :auditor, :billing_manager].each do |role|
      describe "PUT /v2/organizations/:guid/#{role}s/:user_guid" do
        let(:role_name) { "org-#{role}-#{org.guid}" }

        before do
          client.create_role role_name
        end

        it "assigns the specifier user to the org #{role} role" do
          expect(client.list_actor_roles(actor)).to be_empty

          put "/v2/organizations/#{org.guid}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(201)

          roles = client.list_actor_roles(actor)
          expect(roles).not_to be_empty
          expect(roles[0].name).to eq role_name
        end
      end
    end
  end

  describe 'POST /v2/spaces' do
    let(:org) { VCAP::CloudController::Organization.make(user_guids: [assignee.guid]) }

    [:developer, :manager, :auditor].each do |role|
      it "creates the space-#{role}-<space_id> role" do
        post '/v2/spaces', {
          name: 'v2-space',
          organization_guid: org.guid
        }.to_json

        expect(last_response.status).to eq(201)

        json_body = JSON.parse(last_response.body)
        space_id = json_body['metadata']['guid']
        role_name = "space-#{role}-#{space_id}"

        role = client.get_role(role_name)
        expect(role.name).to eq(role_name)
        expect(role.id).not_to be_nil
      end
    end
  end

  describe 'PUT /v2/spaces/:guid/:role/:user_guid' do
    let(:org) { VCAP::CloudController::Organization.make(user_guids: [assignee.guid]) }
    let(:space) {
      VCAP::CloudController::Space.make(
        organization: org,
      )
    }

    [:developer, :manager, :auditor].each do |role|
      describe "PUT /v2/spaces/:guid/#{role}s/:user_guid" do
        let(:role_name) { "space-#{role}-#{space.guid}" }

        before do
          client.create_role(role_name)
        end

        it "assigns the specified user to the space #{role} role" do
          expect(client.list_actor_roles(actor)).to be_empty

          put "/v2/spaces/#{space.guid}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(201)

          roles = client.list_actor_roles(actor)
          expect(roles).not_to be_empty
          expect(roles[0].name).to eq role_name
        end
      end
    end
  end
end
