require 'rails_helper'

RSpec.describe Bullet::Marketings::ReduceChurnsController, type: :request do
  let!(:store) { Oleg.create(:store) }

  describe 'PUT /bullet/marketings/reduce_churns/:id' do
    subject(:request) do
      put bullet_marketings_reduce_churn_path(reduce_churn.id), params: params, headers: { 'X-Inertia' => true }
    end

    let(:subscription_plan) { Oleg.create(:subscription_plan, store: store) }
    let!(:reduce_churn) { Oleg.create(:reduce_churn, store: store, subscription_plan: subscription_plan, status: initial_status) }
    let(:params) { {} }
    let!(:initial_status) { 'draft' }

    context 'when feature is not authorized' do
      let(:content_manager) { Oleg.create(:user_content_manager, store: store) }

      before { sign_in content_manager }

      describe 'PUT /bullet/marketings/reduce_churns/:id' do
        before { request }

        it 'redirects to /admin' do
          expect(response).to redirect_to admin_root_path
          expect(response).to have_http_status 303
        end
      end
    end

    context 'when feature is authorized' do
      let!(:owner) { Oleg.create(:user_owner, store: store) }

      before { sign_in owner }

      context 'with valid attributes' do
        let(:new_status) { 'active' }
        let(:params) do
          {
            plan_id: subscription_plan.id,
            percent_off: 25,
            deal_duration: 2,
            step2_subject: 'subject 1',
            step2_body: 'body 1',
            step2_cta_text: 'cta 1',
            step3_subject: 'subject 2',
            step3_body: 'body 2',
            step3_cta_text: 'cta 2',
            status: new_status
          }
        end

        it 'updates record' do
          expect do
            request
            reduce_churn.reload
          end.to change { reduce_churn.attributes }
        end

        it 'redirects to index' do
          request
          expect(response).to redirect_to bullet_marketings_reduce_churns_path
          expect(response).to have_http_status 303
        end

        context 'when changing status from active to archived' do
          let(:initial_status) { 'active' }
          let(:new_status) { 'archived' }

          context 'and there are scheduled emails' do
            let!(:user) { Oleg.create(:user, store: store) }
            let!(:scheduled_email) do
              Oleg.create(:reduce_churn_scheduled_email, automation: reduce_churn, product: subscription_plan, user: user)
            end

            it 'performs CancelReduceChurnWorker' do
              expect { request }
                .to enqueue_sidekiq_job(::Marketing::CancelReduceChurnWorker).with(user.id)
            end
          end
        end
      end

      context 'with invalid attributes' do
        let(:params) do
          {
            plan_id: subscription_plan.id,
            percent_off: -1,
            deal_duration: 0,
            step2_subject: '{{a}',
            step2_body: '{{a}',
            step3_subject: '{{a}',
            step3_body: '{{a}'
          }
        end
        let(:error_message) { "Variable '{{a}' was not properly terminated. Please check the number of braces." }

        it 'does not update record' do
          expect { request }.to_not change { reduce_churn.percent_off }
        end

        it 'redirects to edit page' do
          request
          expect(json_parsed_response['component']).to eq('ReduceChurns/Edit')
          expect(json_parsed_response['props']['errors'].keys).to include(*%w[
            percent_off deal_duration step2_subject step2_body step2_cta_text step3_subject step3_body step3_cta_text
          ])
          expect(json_parsed_response['props']['errors']['step2_subject']).to eq([error_message])
          expect(json_parsed_response['props']['errors']['step2_body']).to eq([error_message])
          expect(json_parsed_response['props']['errors']['step3_subject']).to eq([error_message])
          expect(json_parsed_response['props']['errors']['step3_body']).to eq([error_message])
          expect(json_parsed_response['props']['alert']).to eq(['error', 'Oops. Automation was not successfully updated. Please check error messages below'])
        end
      end
    end
  end

  describe 'DELETE /bullet/marketings/reduce_churns/:id' do
    subject(:request) do
      delete bullet_marketings_reduce_churn_path(reduce_churn.id), headers: { 'X-Inertia' => true }
    end

    let!(:reduce_churn) { Oleg.create(:reduce_churn, store: store) }

    context 'when feature is not authorized' do
      let(:content_manager) { Oleg.create(:user_content_manager, store: store) }

      before { sign_in content_manager }

      it 'redirects to /admin' do
        request
        expect(response).to redirect_to admin_root_path
        expect(response).to have_http_status 303
      end
    end

    context 'when feature is authorized' do
      let!(:owner) { Oleg.create(:user_owner, store: store) }

      before { sign_in owner }

      it 'redirects to index' do
        expect_any_instance_of(::Marketing::ReduceChurn).to receive(:soft_delete!)
        request
        expect(response).to redirect_to bullet_marketings_reduce_churns_path
        expect(response).to have_http_status 303
      end
    end
  end

  describe 'POST /bullet/marketings/reduce_churns' do
    subject(:request) { post bullet_marketings_reduce_churns_path, params: params, headers: { 'X-Inertia' => true } }

    let!(:owner) { Oleg.create(:user_owner, store: store) }
    let(:subscription_plan) { Oleg.create(:subscription_plan, store: store) }
    let(:params) do
      {
        plan_id: subscription_plan.id,
        percent_off: 25,
        deal_duration: 2,
        step2_subject: 'subject 1',
        step2_body: 'body 1',
        step2_cta_text: 'cta 1',
        step3_subject: 'subject 2',
        step3_body: 'body 2',
        step3_cta_text: 'cta 2',
        status: 'active'
      }
    end

    before { sign_in owner }

    it 'creates the new record' do
      expect { request }.to change { Marketing::ReduceChurn.count }.by(1)
    end

    it 'redirects to index' do
      request
      expect(response).to redirect_to bullet_marketings_reduce_churns_path
      expect(response).to have_http_status 303
    end

    context 'when params are wrong' do
      let(:params) do
        {
          plan_id: subscription_plan.id,
          percent_off: -1,
          deal_duration: 0,
          step2_subject: '{{a}',
          step2_body: '{{a}',
          step3_subject: '{{a}',
          step3_body: '{{a}'
        }
      end
      let(:error_message) { "Variable '{{a}' was not properly terminated. Please check the number of braces." }

      it 'returns errors' do
        subject
        expect(json_parsed_response['component']).to eq('ReduceChurns/New')
        expect(json_parsed_response['props']['errors'].keys).to include(*%w[
          percent_off deal_duration step2_subject step2_body step3_subject step3_body
        ])
        expect(json_parsed_response['props']['errors']['step2_subject']).to eq([error_message])
        expect(json_parsed_response['props']['errors']['step2_body']).to eq([error_message])
        expect(json_parsed_response['props']['errors']['step3_subject']).to eq([error_message])
        expect(json_parsed_response['props']['errors']['step3_body']).to eq([error_message])
        expect(json_parsed_response['props']['alert']).to eq(['error', 'Oops. Automation was not successfully created. Please check error messages below'])
      end
    end
  end

  describe 'GET /bullet/marketings/reduce_churns/export_stats' do
    subject(:perform) { get export_stats_bullet_marketings_reduce_churn_path(reduce_churn.id), headers: { 'X-Inertia' => true } }

    let!(:owner) { Oleg.create(:user_owner, store: store) }
    let(:subscription_plan) { Oleg.create(:subscription_plan, store: store) }
    let!(:reduce_churn) { Oleg.create(:reduce_churn, store: store, subscription_plan: subscription_plan, status: 'active') }
    let!(:export_file) { Oleg.create(:export_file, store: store) }

    before do
      sign_in owner
      allow_any_instance_of(described_class).to receive(:export_file).and_return(export_file)
    end

    it 'passes the given params' do
      expect {
        get export_stats_bullet_marketings_reduce_churn_path(reduce_churn.id, search: 'test')
      }.to enqueue_sidekiq_job(Marketing::ExportReduceChurnStatsWorker).with(
        {
          'search' => 'test',
          'controller' => 'bullet/marketings/reduce_churns',
          'action' => 'export_stats',
          'id' => reduce_churn.id.to_s,
          'marketing_reduce_churn_id' => reduce_churn.id
        },
        export_file.id
      )
    end

    it 'calls ::Marketing::ExportReduceChurnStatsWorker' do
      expect { perform }
        .to enqueue_sidekiq_job(Marketing::ExportReduceChurnStatsWorker).with(
          {
            'controller' => 'bullet/marketings/reduce_churns',
            'action' => 'export_stats',
            'id' => reduce_churn.id.to_s,
            'marketing_reduce_churn_id' => reduce_churn.id
          },
          export_file.id
        )
    end

    it 'redirects with fallback' do
      perform
      expect(response).to redirect_to stats_bullet_marketings_reduce_churn_path(reduce_churn.id)
      expect(flash[:success]).to eq('Almost done with CSV. Check Exported Files on the Settings tab.')
    end

    it 'redirects back' do
      get export_stats_bullet_marketings_reduce_churn_path(reduce_churn.id), headers: {
        'X-Inertia' => true,
        'HTTP_REFERER' => stats_bullet_marketings_reduce_churn_path(reduce_churn.id, page: 2)
      }

      expect(response).to redirect_to stats_bullet_marketings_reduce_churn_path(reduce_churn.id, page: 2)
      expect(flash[:success]).to eq('Almost done with CSV. Check Exported Files on the Settings tab.')
    end
  end
end
