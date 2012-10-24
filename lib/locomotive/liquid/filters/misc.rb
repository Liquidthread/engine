module Locomotive
  module Liquid
    module Filters
      module Misc

        def modulo(word, index, modulo)
          (index.to_i + 1) % modulo == 0 ? word : ''
        end

        def integer(input)
          input.to_i
        end

        def first(input)
          input.first
        end

        def last(input)
          input.last
        end

        def json(input)
          if input.respond_to?(:_source)
            input.send(:_source).to_json
          elsif input.respond_to?(:collection)
            input.send(:collection).map do |collection_item|
              collection_item.attributes.keep_if do |key, value|
                !%w(site_id created_at updated_at custom_fields_recipe _type _visible content_type_id).index(key)
              end
            end.to_json
          elsif input.respond_to?(:to_json)
            input.send(:to_json) rescue {}.to_json
          else
            input
          end
        end

        def default(input, value)
          input.blank? ? value : input
        end

        # Render the navigation for a paginated collection
        def default_pagination(paginate, *args)
          return '' if paginate['parts'].empty?

          options = args_to_options(args)

          previous_label  = options[:previous_label] || I18n.t('pagination.previous')
          next_label      = options[:next_label] || I18n.t('pagination.next')

          previous_link = (if paginate['previous'].blank?
            "<span class=\"disabled prev_page\">#{previous_label}</span>"
          else
            "<a href=\"#{absolute_url(paginate['previous']['url'])}\" class=\"prev_page\">#{previous_label}</a>"
          end)

          links = ""
          paginate['parts'].each do |part|
            links << (if part['is_link']
              "<a href=\"#{absolute_url(part['url'])}\">#{part['title']}</a>"
            elsif part['hellip_break']
              "<span class=\"gap\">#{part['title']}</span>"
            else
              "<span class=\"current\">#{part['title']}</span>"
            end)
          end

          next_link = (if paginate['next'].blank?
            "<span class=\"disabled next_page\">#{next_label}</span>"
          else
            "<a href=\"#{absolute_url(paginate['next']['url'])}\" class=\"next_page\">#{next_label}</a>"
          end)

          %{<div class="pagination #{options[:css]}">
              #{previous_link}
              #{links}
              #{next_link}
            </div>}
        end

      end

      ::Liquid::Template.register_filter(Misc)

    end
  end
end
