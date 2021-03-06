require 'rails_helper'

RSpec.describe TasksController, type: :controller do
  let(:client) { instance_double(VCAP::CloudController::Diego::BbsTaskClient, desire_task: nil) }
  let(:tasks_enabled) { true }
  let(:app_model) { VCAP::CloudController::AppModel.make }
  let(:space) { app_model.space }
  let(:org) { space.organization }

  describe '#create' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    let(:droplet) do
      VCAP::CloudController::DropletModel.make(
        app_guid: app_model.guid,
        state: VCAP::CloudController::DropletModel::STAGED_STATE)
    end

    let(:request_body) do
      {
        "name": 'mytask',
        "command": 'rake db:migrate && true',
        "memory_in_mb": 2048,
      }
    end

    before do
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)
      VCAP::CloudController::FeatureFlag.make(name: 'task_creation', enabled: tasks_enabled, error_message: nil)

      app_model.droplet = droplet
      app_model.save

      CloudController::DependencyLocator.instance.register(:bbs_task_client, client)
      allow_any_instance_of(VCAP::CloudController::Diego::TaskRecipeBuilder).to receive(:build_app_task)
    end

    it 'returns a 202 and the task' do
      post :create, params: { app_guid: app_model.guid }.merge(request_body), as: :json

      expect(response.status).to eq(202)
      expect(parsed_body['name']).to eq('mytask')
      expect(parsed_body['state']).to eq('RUNNING')
      expect(parsed_body['memory_in_mb']).to eq(2048)
      expect(parsed_body['sequence_id']).to eq(1)
    end

    it 'creates a task for the app' do
      expect(app_model.tasks.count).to eq(0)

      post :create, params: { app_guid: app_model.guid }.merge(request_body), as: :json

      expect(app_model.reload.tasks.count).to eq(1)
      expect(app_model.tasks.first).to eq(VCAP::CloudController::TaskModel.last)
    end

    context 'permissions' do
      context 'when the task_creation feature flag is disabled' do
        let(:tasks_enabled) { false }

        it 'raises 403 for non-admins' do
          post :create, params: { app_guid: app_model.guid }.merge(request_body), as: :json

          expect(response.status).to eq(403)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('task_creation')
        end

        it 'succeeds for admins' do
          set_current_user_as_admin(user: user)
          post :create, params: { app_guid: app_model.guid }.merge(request_body), as: :json

          expect(response.status).to eq(202)
        end
      end

      context 'when the user does not have write scope' do
        before do
          set_current_user(user, scopes: ['cloud_controller.read'])
        end

        it 'raises 403' do
          post :create, params: { app_guid: app_model.guid }.merge(request_body), as: :json

          expect(response.status).to eq(403)
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user does not have write permissions on the app space' do
        before do
          allow_user_read_access_for(user, spaces: [space])
          disallow_user_write_access(user, space: space)
        end

        it 'returns a 403 unauthorized' do
          post :create, params: { app_guid: app_model.guid }.merge(request_body), as: :json

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user does not have read permissions on the app space' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound' do
          post :create, params: { app_guid: app_model.guid }.merge(request_body), as: :json

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end
    end

    context 'when the app does not exist' do
      it 'returns a 404 ResourceNotFound' do
        post :create, params: { app_guid: 'bogus' }.merge(request_body), as: :json

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'App not found'
      end
    end

    context 'when the user has requested an invalid field' do
      it 'returns a 400 and a helpful error' do
        request_body[:invalid] = 'field'

        post :create, params: { app_guid: app_model.guid }.merge(request_body), as: :json

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include "Unknown field(s): 'invalid'"
      end
    end

    context 'when there is a validation failure' do
      it 'returns a 422 and a helpful error' do
        stub_const('VCAP::CloudController::TaskModel::COMMAND_MAX_LENGTH', 6)
        request_body[:command] = 'a' * 7

        post :create, params: { app_guid: app_model.guid }.merge(request_body), as: :json

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'command must be shorter than 7 characters'
      end
    end

    context 'invalid task' do
      it 'returns a useful error message' do
        post :create, params: { app_guid: app_model.guid }

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
      end
    end

    describe 'droplets' do
      context 'when a droplet guid is not provided' do
        it "successfully creates the task on the app's droplet" do
          post :create, params: { app_guid: app_model.guid }.merge(request_body), as: :json

          expect(response.status).to eq(202)
          expect(parsed_body['droplet_guid']).to include(droplet.guid)
        end

        context 'and the app does not have an assigned droplet' do
          let(:droplet) { nil }

          it 'returns a 422 and a helpful error' do
            post :create, params: { app_guid: app_model.guid }.merge(request_body), as: :json

            expect(response.status).to eq 422
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include 'Task must have a droplet. Specify droplet or assign current droplet to app.'
          end
        end
      end

      context 'when a custom droplet guid is provided' do
        let(:custom_droplet) {
          VCAP::CloudController::DropletModel.make(app_guid: app_model.guid,
                                                   state: VCAP::CloudController::DropletModel::STAGED_STATE)
        }

        it 'successfully creates a task on the specifed droplet' do
          post :create, params: { app_guid: app_model.guid }.merge(
            "name": 'mytask',
            "command": 'rake db:migrate && true',
            "droplet_guid": custom_droplet.guid
          ), as: :json

          expect(response.status).to eq 202
          expect(parsed_body['droplet_guid']).to eq(custom_droplet.guid)
          expect(parsed_body['droplet_guid']).to_not eq(droplet.guid)
        end

        context 'and the droplet is not found' do
          it 'returns a 404' do
            post :create, params: { app_guid: app_model.guid }.merge(
              "name": 'mytask',
              "command": 'rake db:migrate && true',
              "droplet_guid": 'fake-droplet-guid'
            ), as: :json

            expect(response.status).to eq 404
            expect(response.body).to include 'ResourceNotFound'
            expect(response.body).to include 'Droplet not found'
          end
        end

        context 'and the droplet does not belong to the app' do
          let(:custom_droplet) { VCAP::CloudController::DropletModel.make(state: VCAP::CloudController::DropletModel::STAGED_STATE) }

          it 'returns a 404' do
            post :create, params: { app_guid: app_model.guid }.merge(
              "name": 'mytask',
              "command": 'rake db:migrate && true',
              "droplet_guid": custom_droplet.guid
            ), as: :json

            expect(response.status).to eq 404
            expect(response.body).to include 'ResourceNotFound'
            expect(response.body).to include 'Droplet not found'
          end
        end
      end
    end
  end

  describe '#show' do
    let!(:task) { VCAP::CloudController::TaskModel.make name: 'mytask', app_guid: app_model.guid, memory_in_mb: 2048 }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access_for(user, spaces: [space])
      allow_user_secret_access(user, space: space)
    end

    it 'returns a 200 and the task' do
      get :show, params: { task_guid: task.guid }

      expect(response.status).to eq 200
      expect(parsed_body['name']).to eq('mytask')
      expect(parsed_body['memory_in_mb']).to eq(2048)
    end

    context 'permissions' do
      context 'when the user does not have read scope' do
        before do
          set_current_user(user, scopes: [])
        end

        it 'raises 403' do
          get :show, params: { task_guid: task.guid }

          expect(response.status).to eq(403)
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user does not have read permissions on the app space' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound' do
          get :show, params: { task_guid: task.guid }

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Task not found'
        end
      end

      context 'when the user has read, but not write permissions on the app space' do
        before do
          allow_user_read_access_for(user, spaces: [space])
          disallow_user_write_access(user, space: space)
        end

        it 'returns a 200' do
          get :show, params: { task_guid: task.guid }

          expect(response.status).to eq 200
        end
      end

      context 'perm permissions' do
        before do
          disallow_user_read_access(user, space: space)
          disallow_user_write_access(user, space: space)
        end

        context 'when the user has no permissions' do
          it 'returns a 404' do
            get :show, params: { task_guid: task.guid }

            expect(response.status).to eq 404
          end
        end

        context 'when the user has permission to read tasks in the app space or org' do
          before do
            allow_user_perm_permission(:can_read_task?, space_guid: space.guid, org_guid: org.guid)
          end

          it 'returns a 200' do
            get :show, params: { task_guid: task.guid }

            expect(response.status).to eq 200
          end
        end
      end
    end

    it 'returns a 404 if the task does not exist' do
      get :show, params: { task_guid: 'bogus' }

      expect(response.status).to eq 404
      expect(response.body).to include 'ResourceNotFound'
      expect(response.body).to include 'Task not found'
    end
  end

  describe '#index' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access_for(user, spaces: [space])
    end

    it 'returns tasks the user has read access' do
      task_1 = VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)
      task_2 = VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)
      VCAP::CloudController::TaskModel.make

      get :index

      response_guids = parsed_body['resources'].map { |r| r['guid'] }
      expect(response.status).to eq(200)
      expect(response_guids).to match_array([task_1.guid, task_2.guid])
    end

    it 'provides the correct base url in the pagination links' do
      get :index

      expect(parsed_body['pagination']['first']['href']).to include('/v3/tasks')
    end

    context 'when pagination options are specified' do
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:params) { { 'page' => page, 'per_page' => per_page } }

      it 'paginates the response' do
        VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)
        VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)

        get :index, params: params

        parsed_response = parsed_body
        expect(parsed_response['pagination']['total_results']).to eq(2)
        expect(parsed_response['resources'].length).to eq(per_page)
      end
    end

    context 'when accessed as an app subresource' do
      before do
        allow_user_secret_access(user, space: space)
      end

      it 'uses the app as a filter' do
        task_1 = VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)
        task_2 = VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)
        VCAP::CloudController::TaskModel.make

        get :index, params: { app_guid: app_model.guid }

        expect(response.status).to eq(200)
        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response_guids).to match_array([task_1.guid, task_2.guid])
      end

      it 'provides the correct base url in the pagination links' do
        get :index, params: { app_guid: app_model.guid }

        expect(parsed_body['pagination']['first']['href']).to include("/v3/apps/#{app_model.guid}/tasks")
      end

      context 'when the user cannot view secrets' do
        before do
          disallow_user_secret_access(user, space: space)
        end

        it 'excludes secrets' do
          VCAP::CloudController::TaskModel.make(app: app_model)

          get :index, params: { app_guid: app_model.guid }

          expect(parsed_body['resources'][0]).not_to have_key('command')
        end
      end

      context 'the app does not exist' do
        it 'returns a 404 Resource Not Found' do
          get :index, params: { app_guid: 'hello-i-do-not-exist' }

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user does not have permissions to read the app' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 Resource Not Found error' do
          get :index, params: { app_guid: app_model.guid }

          expect(response.body).to include 'ResourceNotFound'
          expect(response.status).to eq 404
        end
      end

      context 'when space_guids, org_guids, or app_guids are present' do
        it 'returns a 400 Bad Request' do
          get :index, params: {
            app_guid: app_model.guid,
            'space_guids' => [app_model.space.guid],
            'organization_guids' => [app_model.organization.guid],
            'app_guids' => [app_model.guid]
          }

          expect(response.status).to eq 400
          expect(response.body).to include "Unknown query parameter(s): 'space_guids', 'organization_guids', 'app_guids'"
        end
      end
    end

    context 'when the user has global read access' do
      before do
        allow_user_global_read_access(user)
      end

      it 'returns a 200 and all tasks' do
        task_1 = VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)
        task_2 = VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)
        task_3 = VCAP::CloudController::TaskModel.make

        get :index

        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response.status).to eq(200)
        expect(response_guids).to match_array([task_1, task_2, task_3].map(&:guid))
      end
    end

    context 'perm permissions' do
      before do
        allow_user_read_access_for(user, spaces: [])
        VCAP::CloudController::TaskModel.make(app: app_model)
        VCAP::CloudController::TaskModel.make(app: app_model)
      end

      context 'when the user has no permissions' do
        it 'returns no tasks' do
          get :index

          expect(response.status).to eq 200
          expect(parsed_body['resources']).to have(0).items
        end
      end

      context 'when the user has permission to read tasks in the app space' do
        before do
          allow_user_perm_permission_for(:task_readable_space_guids, visible_guids: [space.guid])
        end

        it 'returns all the tasks in that space' do
          get :index

          expect(response.status).to eq 200
          expect(parsed_body['resources']).to have(2).items
        end
      end
    end

    describe 'query params errors' do
      context 'invalid param format' do
        it 'returns 400' do
          get :index, params: { per_page: 'meow' }

          expect(response.status).to eq 400
          expect(response.body).to include('Per page must be a positive integer')
          expect(response.body).to include('BadQueryParameter')
        end
      end

      context 'unknown query param' do
        it 'returns 400' do
          get :index, params: { meow: 'bad-val', nyan: 'mow' }

          expect(response.status).to eq 400
          expect(response.body).to include('BadQueryParameter')
          expect(response.body).to include('Unknown query parameter(s)')
          expect(response.body).to include('nyan')
          expect(response.body).to include('meow')
        end
      end
    end
  end

  describe '#cancel' do
    let!(:task) { VCAP::CloudController::TaskModel.make name: 'usher', app_guid: app_model.guid }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)
      CloudController::DependencyLocator.instance.register(:bbs_task_client, client)
      allow(client).to receive(:cancel_task).and_return(nil)
    end

    it 'returns a 202' do
      put :cancel, params: { task_guid: task.guid }

      expect(response.status).to eq 202
      expect(parsed_body['name']).to eq('usher')
      expect(parsed_body['guid']).to eq(task.guid)
    end

    context 'when the task does not exist' do
      it 'returns a 404 ResourceNotFound' do
        put :cancel, params: { task_guid: 'bogus-guid' }

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'Task not found'
      end
    end

    context 'when InvalidCancel is raised' do
      before do
        allow_any_instance_of(VCAP::CloudController::TaskCancel).to receive(:cancel).and_raise(VCAP::CloudController::TaskCancel::InvalidCancel.new('sad trombone'))
      end

      it 'returns a 422 Unprocessable' do
        put :cancel, params: { task_guid: task.guid }

        expect(response.status).to eq 422
        expect(response.body).to include('sad trombone')
      end
    end

    context 'permissions' do
      context 'when the user does not have read permissions on the app space' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound' do
          put :cancel, params: { task_guid: task.guid }

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Task not found'
        end
      end

      context 'when the user has read, but not write permissions on the app space' do
        before do
          allow_user_read_access_for(user, spaces: [space])
          disallow_user_write_access(user, space: space)
        end

        it 'returns a 403 NotAuthorized' do
          put :cancel, params: { task_guid: task.guid }

          expect(response.status).to eq 403
          expect(response.body).to include('NotAuthorized')
        end
      end
    end
  end
end
