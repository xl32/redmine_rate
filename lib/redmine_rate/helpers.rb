module RedmineRate
  module Helpers
    def rate_last_caching_run
      if RedmineRate.settings[:last_caching_run].present? &&
         RedmineRate.settings[:last_caching_run].to_date
        format_time(RedmineRate.settings[:last_caching_run])
      else
        l(:text_no_cache_run)
      end
    end

    def rate_last_cache_clearing_run
      if RedmineRate.settings[:last_cache_clearing_run].present? &&
         RedmineRate.settings[:last_cache_clearing_run].to_date
        format_time(RedmineRate.settings[:last_cache_clearing_run])
      else
        l(:text_no_cache_run)
      end
    end

    # Allows more parameters than the standard sort_header_tag
    def rate_sort_header_tag(column, options = {})
      caption = options.delete(:caption) || titleize(ActiveSupport::Inflector.humanize(column))
      default_order = options.delete(:default_order) || 'asc'
      options[:title] = l(:label_sort_by, "\"#{caption}\"") unless options[:title]
      content_tag('th',
                  rate_sort_link(column,
                                 caption,
                                 default_order,
                                 method: options[:method], update: options[:update], user_id: options[:user_id]),
                  options)
    end

    # Allows more parameters than the standard sort_link and is hard coded to use
    # the RatesController and to have an :method and :update options
    def rate_sort_link(column, caption, default_order, options = {})
      css = nil
      order = default_order

      if column.to_s == @sort_criteria.first_key
        if @sort_criteria.first_asc?
          css = 'sort asc'
          order = 'desc'
        else
          css = 'sort desc'
          order = 'asc'
        end
      end
      caption ||= column.to_s.humanize

      sort_options = { sort: @sort_criteria.add(column.to_s, order).to_param }
      # don't reuse params if filters are present

      params.permit!
      url_options = params.key?(:set_filter) ? sort_options : params.merge(sort_options)

      # Add project_id to url_options
      url_options = url_options.merge(project_id: params[:project_id]) if params.key?(:project_id)

      ##### Hard code url to the Rates index
      url_options[:controller] = 'rates'
      url_options[:action] = 'index'
      url_options[:user_id] ||= options[:user_id]
      #####

      link_to(caption,
              {
                update: options[:update] || 'content',
                url: url_options,
                method: options[:method] || :post,
                remote: true
              },
              href: url_for(url_options),
              class: css)
    end

    def currency_codes_for_select
      currencies = []
      Money::Currency.table.values.each do |currency|
        currencies << [currency[:name] + ' (' + currency[:iso_code] + ')', currency[:iso_code]]
      end
      currencies.sort
    end

    def currency_name(use_symbol = false)
      iso_code = RedmineRate.settings[:currency].blank? ? 'eur' : RedmineRate.settings[:currency]
      currency = Money::Currency.find(iso_code)
      use_symbol ? currency.symbol : currency
    end

    def show_number_with_currency(num)
      locale = User.current.language if User.current.language.present?
      locale ||= Setting.default_language
      number_to_currency(num, unit: currency_name(true), locale: locale, precision: 2)
    end
  end
end

ActionView::Base.send :include, RedmineRate::Helpers
