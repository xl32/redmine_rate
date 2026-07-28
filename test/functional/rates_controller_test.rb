require_relative '../test_helper'

class RatesControllerTest < ActionController::TestCase
  setup do
    TimeEntryActivity.generate!
  end

  def self.should_be_unauthorized(&block)
    should 'should return a forbidden status code' do
      instance_eval(&block)
      assert_response :forbidden
    end

    should 'should display the standard unauthorized page' do
      instance_eval(&block)
      assert_template 'common/error'
    end

    context 'with mime type of xml' do
      should 'should return an forbidden error' do
        @request.env['HTTP_ACCEPT'] = 'application/xml'
        instance_eval(&block)
        assert_response :forbidden
      end
    end
  end

  def mock_rate(stubs = {})
    @project = Project.generate!
    stubs = {
      date_in_effect: Time.zone.today,
      project: @project,
      amount: 100.0,
      user: @user
    }.merge(stubs)
    @mock_rate = Rate.generate!(stubs)
  end

  def mock_locked_rate
    @mock_rate = mock_rate
    @mock_rate.time_entries << TimeEntry.generate!
    @mock_rate
  end

  context 'as regular user' do
    setup do
      @user = User.generate!
      @request.session[:user_id] = @user.id
    end

    context 'responding to GET index' do
      should_be_unauthorized { get :index }
    end

    context 'responding to GET show' do
      should_be_unauthorized { get :show, params: { id: '37' } }
    end

    context 'responding to GET new' do
      should_be_unauthorized { get :new }
    end

    context 'responding to GET edit' do
      should_be_unauthorized { get :edit, params: { id: '37' } }
    end

    context 'responding to POST create' do
      should_be_unauthorized { post :create, params: { rate: { these: 'params' } } }
    end

    context 'responding to PUT update' do
      should_be_unauthorized { put :update, params: { id: '37', rate: { these: 'params' } } }
    end

    context 'responding to DELETE destroy' do
      should_be_unauthorized { delete :destroy, params: { id: '37' } }
    end
  end

  context 'as an administrator' do
    setup do
      @user = User.generate! { |u| u.admin = true }
      @request.session[:user_id] = @user.id
    end

    context 'responding to GET index' do
      should 'should redirect to the homepage' do
        get :index
        assert_redirected_to home_url
      end

      should 'should display an error flash message' do
        get :index
        assert_match(/not found/, flash[:error])
      end

      context 'via the read-only REST API' do
        should 'return a 404 when no user_id is given' do
          with_settings rest_api_enabled: '1' do
            get :index, params: { key: @user.api_key }, format: 'xml'
          end
          assert_response :not_found
        end
      end
    end

    context 'responding to GET index with user' do
      setup do
        mock_rate
      end

      should 'should expose all historic rates for the user as @rates' do
        get :index, params: { user_id: @user.id }
        assert_equal assigns(:rates), [@mock_rate]
      end

      context 'via the read-only REST API' do
        should 'render all rates as xml' do
          with_settings rest_api_enabled: '1' do
            get :index, params: { user_id: @user.id, key: @user.api_key }, format: 'xml'
          end

          assert_response :success
          assert_select 'rates[type=array]' do
            assert_select 'rate' do
              assert_select 'id', text: @mock_rate.id.to_s
              assert_select 'amount', text: /100/
              assert_select 'date_in_effect'
              assert_select 'locked', text: 'false'
            end
          end
        end

        should 'render all rates as json' do
          with_settings rest_api_enabled: '1' do
            get :index, params: { user_id: @user.id, key: @user.api_key }, format: 'json'
          end

          assert_response :success
          json = ActiveSupport::JSON.decode(response.body)
          assert_kind_of Array, json['rates']
          assert_equal @mock_rate.id, json['rates'].first['id']
        end
      end
    end

    context 'responding to GET show' do
      setup do
        mock_rate
      end

      should 'should expose the @requested rate as @rate' do
        get :show, params: { id: @mock_rate.id }
        assert_equal assigns(:rate), @mock_rate
      end

      context 'via the read-only REST API' do
        should 'render the requested rate as xml' do
          with_settings rest_api_enabled: '1' do
            get :show, params: { id: @mock_rate.id, key: @user.api_key }, format: 'xml'
          end

          assert_response :success
          assert_select 'rate' do
            assert_select 'id', text: @mock_rate.id.to_s
            assert_select 'amount', text: /100/
            assert_select 'locked', text: 'false'
            assert_select 'editable', text: 'true'
          end
        end

        should 'render the requested rate as json' do
          with_settings rest_api_enabled: '1' do
            get :show, params: { id: @mock_rate.id, key: @user.api_key }, format: 'json'
          end

          assert_response :success
          json = ActiveSupport::JSON.decode(response.body)
          assert_equal @mock_rate.id, json['rate']['id']
        end
      end
    end

    context 'responding to GET new' do
      should 'should redirect to the homepage' do
        get :new
        assert_redirected_to home_url
      end

      should 'should display an error flash message' do
        get :new
        assert_match(/not found/, flash[:error])
      end
    end

    context 'responding to GET new with user' do
      should 'should be successful' do
        get :new, params: { user_id: @user.id }
        assert_response :success
      end

      should 'should expose a new rate as @rate' do
        get :new, params: { user_id: @user.id }
        assert assigns(:rate)
        assert assigns(:rate).new_record?
      end
    end

    context 'responding to GET edit' do
      setup do
        mock_rate
      end

      should 'should expose the requested rate as @rate' do
        get :edit, params: { id: @mock_rate.id }
        assert_equal assigns(:rate), @mock_rate
      end

      context 'on a locked rate' do
        setup do
          mock_locked_rate
        end

        should 'should not have a Update button' do
          get :edit, params: { id: @mock_rate.id }
          assert_select 'input[type=submit]', count: 0
        end

        should 'should show the locked icon' do
          get :edit, params: { id: @mock_rate.id }
          # Propshaft digests asset filenames (locked-<digest>.png), so match on the stem.
          assert_select "img[src*='locked']"
        end

        should 'should have an Update button when the lock is disabled in the settings' do
          with_rate_lock_disabled { get :edit, params: { id: @mock_rate.id } }

          assert_select 'input[type=submit]', count: 1
        end
      end
    end

    context 'responding to POST create' do
      context 'with valid params' do
        setup do
          @project = Project.generate!
        end

        should 'should expose a newly created rate as @rate' do
          post :create, params: { rate: { project_id: @project.id, amount: '50', date_in_effect: Time.zone.today.to_s, user_id: @user.id } }
          assert assigns(:rate)
        end

        should 'should redirect to the rate list' do
          post :create, params: { rate: { project_id: @project.id, amount: '50', date_in_effect: Time.zone.today.to_s, user_id: @user.id } }

          assert_redirected_to rates_url(user_id: @user.id)
        end

        should 'should redirect to the back_url if set' do
          back_url = '/rates'
          post :create, params: { rate: { project_id: @project.id,
                                          amount: '50',
                                          date_in_effect: Time.zone.today.to_s,
                                          user_id: @user.id }, back_url: back_url }

          assert_redirected_to back_url
        end
      end

      context 'with invalid params' do
        should 'should expose a newly created but unsaved rate as @rate' do
          post :create, params: { rate: { amount: 0 } }
          assert assigns(:rate).new_record?
        end

        should "should re-render the 'new' template" do
          post :create, params: { rate: { amount: 0 } }
          assert_template 'new'
        end
      end
    end

    context 'responding to PUT update' do
      context 'with valid params' do
        setup do
          mock_rate
        end

        should 'should update the requested rate' do
          put :update, params: { id: @mock_rate.id, rate: { amount: '150' } }

          assert_equal 150.0, @mock_rate.reload.amount
        end

        should 'should expose the requested rate as @rate' do
          put :update, params: { id: @mock_rate.id, rate: { amount: 0 } }

          assert_equal assigns(:rate), @mock_rate
        end

        should 'should redirect to the rate list' do
          put :update, params: { id: @mock_rate.id, rate: { amount: 0 } }

          assert_redirected_to rates_url(user_id: @user.id)
        end

        should 'should redirect to the back_url if set' do
          back_url = '/rates'
          put :update, params: { id: @mock_rate.id, back_url: back_url, rate: { amount: 0 } }

          assert_redirected_to back_url
        end
      end

      context 'with invalid params' do
        setup do
          mock_rate
        end

        should 'should not update the requested rate' do
          put :update, params: { id: @mock_rate.id, rate: { amount: 'asdf' } }

          assert_equal 100.0, @mock_rate.reload.amount
        end

        should 'should expose the rate as @rate' do
          put :update, params: { id: @mock_rate.id, rate: { amount: 'asdf' } }

          assert_equal assigns(:rate), @mock_rate
        end

        should "should re-render the 'edit' template" do
          put :update, params: { id: @mock_rate.id, rate: { amount: 'asdf' } }

          assert_template 'edit'
        end
      end

      context 'on a locked rate' do
        setup do
          mock_locked_rate
        end

        should 'should not save the rate' do
          put :update, params: { id: @mock_rate.id, rate: { amount: 150 } }

          assert_equal 100, @mock_rate.reload.amount
        end

        should 'should set the locked rate as @rate' do
          put :update, params: { id: @mock_rate.id, rate: { amount: 200 } }

          assert_equal assigns(:rate), @mock_rate
        end

        should "should re-render the 'edit' template" do
          put :update, params: { id: @mock_rate.id, rate: { amount: 0 } }

          assert_template 'edit'
        end

        should 'should render an error message' do
          put :update, params: { id: @mock_rate.id, rate: { amount: 0 } }

          assert_match(/locked/, flash[:error])
        end

        should 'should save the rate when the lock is disabled in the settings' do
          with_rate_lock_disabled do
            put :update, params: { id: @mock_rate.id, rate: { amount: 150 } }
          end

          assert_equal 150, @mock_rate.reload.amount
          assert_redirected_to rates_url(user_id: @user.id)
        end
      end
    end

    context 'responding to DELETE destroy' do
      setup do
        mock_rate
      end

      should 'should destroy the requested rate' do
        assert_difference('Rate.count', -1) do
          delete :destroy, params: { id: @mock_rate.id }
        end
      end

      should "should redirect to the user's rates list" do
        delete :destroy, params: { id: @mock_rate.id }
        assert_redirected_to rates_url(user_id: @user.id)
      end

      should 'should redirect to the back_url if set' do
        back_url = '/rates'
        delete :destroy, params: { id: @mock_rate.id, back_url: back_url, rate: { amount: 0 } }

        assert_redirected_to back_url
      end

      context 'on a locked rate' do
        setup do
          mock_locked_rate
        end

        should 'should display an error message' do
          delete :destroy, params: { id: @mock_rate.id }
          assert_match(/locked/, flash[:error])
        end

        should 'should destroy the rate when the lock is disabled in the settings' do
          assert_difference('Rate.count', -1) do
            with_rate_lock_disabled { delete :destroy, params: { id: @mock_rate.id } }
          end

          assert_redirected_to rates_url(user_id: @user.id)
        end
      end
    end

    context 'write access via the REST API' do
      setup do
        @project = Project.generate!
      end

      should 'create a rate and return 201' do
        with_settings rest_api_enabled: '1' do
          assert_difference 'Rate.count', 1 do
            post :create,
                 params: { key: @user.api_key,
                           rate: { project_id: @project.id, amount: '75',
                                   date_in_effect: Time.zone.today.to_s, user_id: @user.id } },
                 format: 'json'
          end
        end

        assert_response :created
        json = ActiveSupport::JSON.decode(response.body)
        assert_equal 75.0, json['rate']['amount'].to_f
      end

      should 'return 422 when creating with invalid params' do
        with_settings rest_api_enabled: '1' do
          post :create, params: { key: @user.api_key, rate: { amount: 'not-a-number' } }, format: 'json'
        end

        assert_response 422
      end

      should 'update a rate and return 204' do
        rate = mock_rate
        with_settings rest_api_enabled: '1' do
          put :update, params: { key: @user.api_key, id: rate.id, rate: { amount: '175' } }, format: 'json'
        end

        assert_response :no_content
        assert_equal 175.0, rate.reload.amount
      end

      should 'return 422 when updating a locked rate' do
        rate = mock_locked_rate
        with_settings rest_api_enabled: '1' do
          put :update, params: { key: @user.api_key, id: rate.id, rate: { amount: '175' } }, format: 'json'
        end

        assert_response 422
        assert_equal 100.0, rate.reload.amount
      end

      should 'update a locked rate when the lock is disabled in the settings' do
        rate = mock_locked_rate
        with_settings rest_api_enabled: '1' do
          with_rate_lock_disabled do
            put :update, params: { key: @user.api_key, id: rate.id, rate: { amount: '175' } }, format: 'json'
          end
        end

        assert_response :no_content
        assert_equal 175.0, rate.reload.amount
      end

      should 'delete a rate and return 204' do
        rate = mock_rate
        with_settings rest_api_enabled: '1' do
          assert_difference 'Rate.count', -1 do
            delete :destroy, params: { key: @user.api_key, id: rate.id }, format: 'json'
          end
        end

        assert_response :no_content
      end

      should 'return 422 when deleting a locked rate' do
        rate = mock_locked_rate
        with_settings rest_api_enabled: '1' do
          assert_no_difference 'Rate.count' do
            delete :destroy, params: { key: @user.api_key, id: rate.id }, format: 'json'
          end
        end

        assert_response 422
      end
    end
  end
end
