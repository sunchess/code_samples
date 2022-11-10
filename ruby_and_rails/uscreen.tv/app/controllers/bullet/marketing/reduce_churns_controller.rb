module Bullet
  module Marketings
    class ReduceChurnsController < BulletController
      around_action :use_storefront_locale, only: %i[stats export_stats]

      include MarketingAutomation
      authorize_feature :marketing

      def index
        records = current_store.reduce_churns
          .not_archived.order(id: :desc).page(params[:page]).per(12)

        inertia :reduce_churn,
                reduceChurns: ActiveModel::Serializer::CollectionSerializer.new(records, serializer: ReduceChurnIndexSerializer),
                totalCount: records.total_count,
                totalPages: records.total_pages,
                hasRecords: records.any?
      end

      def new
        inertia 'reduce_churns/new',
                plans: serialized_offers(subscription_plans),
                currency: current_store.currency
      end

      def edit
        inertia 'reduce_churns/edit',
                currentSettings: ReduceChurnsSerializer.new(non_archived_reduce_churn).serializable_hash,
                plans: serialized_offers(filtered_subscription_plans),
                currency: current_store.currency
      end

      def create
        form = ::Bullet::Marketing::ReduceChurnForm.new(create_params)
        if form.valid?
          form.save
          flash['success'] = 'Automation successfully created'
          redirect_to bullet_marketings_reduce_churns_path, turbolinks: false, status: :see_other
        else
          inertia 'reduce_churns/new',
                  errors: form.errors.messages,
                  plans: serialized_offers(subscription_plans),
                  currency: current_store.currency,
                  alert: ['error', 'Oops. Automation was not successfully created. Please check error messages below']
        end
      end

      def update
        form = ::Bullet::Marketing::ReduceChurnForm.new(update_params)
        if form.valid?
          form.save
          flash['success'] = 'Automation successfully updated'
          redirect_to bullet_marketings_reduce_churns_path, turbolinks: false, status: :see_other
        else
          inertia 'reduce_churns/edit',
                  currentSettings: ReduceChurnsSerializer.new(non_archived_reduce_churn).serializable_hash,
                  plans: serialized_offers(filtered_subscription_plans),
                  currency: current_store.currency,
                  errors: form.errors.messages,
                  alert: ['error', 'Oops. Automation was not successfully updated. Please check error messages below']
        end
      end

      def destroy
        non_archived_reduce_churn.soft_delete!
        flash['success'] = 'Automation successfully deleted'
        redirect_to bullet_marketings_reduce_churns_path, turbolinks: false, status: :see_other
      end

      def stats
        stats = ::Bullet::Marketing::ReduceChurnStatsQuery
          .new(params.merge(marketing_reduce_churn_id: reduce_churn_automation.id))
          .page(params[:page])
          .per(20)

        inertia 'reduce_churns/stats',
                mrr: reduce_churn_automation.monthly_recurring_revenue,
                reasons: reasons,
                subscriptions: reduce_churn_automation.subscriptions.active.count,
                title: reduce_churn_automation.subscription_plan.title,
                stats: stats.map { |s| ::Bullet::ReduceChurnStatsSerializer.new(s).serializable_hash },
                total_pages: stats.total_pages,
                has_records: reduce_churn_automation.stats.any?
      end

      def export_stats
        ::Marketing::ExportReduceChurnStatsWorker.perform_async(
          params.merge(marketing_reduce_churn_id: reduce_churn_automation.id).to_h,
          export_file.id
        )
        redirect_back fallback_location: stats_bullet_marketings_reduce_churn_path(reduce_churn_automation.id),
                      turbolinks: false,
                      status: :see_other,
                      flash: { success: 'Almost done with CSV. Check Exported Files on the Settings tab.' }
      end

      private

      def set_current_tab
        @current_tab = 'marketing'
      end

      def export_file
        current_store.export_files.create!(export: ExportFile.exports[:reduce_churns_stats])
      end

      def subscription_plans
        @subscription_plans ||= current_store.subscription_plans.not_deleted.without_reduce_churns
      end

      def subscription_plan
        @subscription_plan ||= current_store.subscription_plans.not_deleted.find(params[:plan_id])
      end

      def non_archived_reduce_churn
        @non_archived_reduce_churn ||= current_store.reduce_churns.not_archived.find(params[:id])
      end

      def reduce_churn_automation
        @reduce_churn_automation ||= current_store.reduce_churns.active.find(params[:id])
      end

      def update_params
        params.merge(
          automation: non_archived_reduce_churn || ::Marketing::ReduceChurn.new,
          subscription_plan: subscription_plan,
          store: current_store
        )
      end

      def create_params
        params.merge(
          automation: ::Marketing::ReduceChurn.new,
          subscription_plan: subscription_plan,
          store: current_store
        )
      end

      def reasons
        ::Marketing::CancellationSurvey
          .where(marketing_reduce_churn_id: reduce_churn_automation.id)
          .where.not(option: nil)
          .group(:option)
          .count
          .each.with_object({}) { |(k, v), h| h[I18n.t("cancellation.new.#{k}")] = v }
      end

      def use_storefront_locale(&action)
        I18n.with_locale(current_store&.platform_locale || I18n.default_locale, &action)
      end

      def filtered_subscription_plans
        subscription_plans.or(SubscriptionPlan.where(id: non_archived_reduce_churn.subscription_plan.id))
      end
    end
  end
end
