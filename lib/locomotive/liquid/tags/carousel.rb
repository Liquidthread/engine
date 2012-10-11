module Locomotive
  module Liquid
      module Tags

      # Carousel a collection

      # Carousel is like a paginate, but it includes all pages for client-side switching

      # Usage:
      #

      # {% carousel contents.projects by 5 %}
      # #myCarousel.carousel.slide
      #   {{ carousel.prev_link }}
      #   .carousel-inner
      #     {% for page in carousel.pages %}
      #       %div(class="item {% if page.selected %}selected{% endif %}")
      #         {% for project in page.collection %}
      #           {{ project.name }}
      #         {% endfor %}
      #     {% endfor %}
      #   {{ carousel.next_link }}
      # {% endpaginate %}

      class Carousel < ::Liquid::Block

        Syntax = /(#{::Liquid::Expression}+)\s+by\s+([0-9]+)/

        def initialize(tag_name, markup, tokens, context)
          if markup =~ Syntax
            @collection_name = $1
            @per_page = $2.to_i
          else
            raise ::Liquid::SyntaxError.new("Syntax Error in 'carousel' - Valid syntax: paginate <collection> by <number>")
          end

          super
        end

        def render(context)
          context.stack do
            collection = context[@collection_name]

            raise ::Liquid::ArgumentError.new("Cannot carousel array '#{@collection_name}'. Not found.") if collection.nil?

            name = @collection_name.split(".").last
            params_page = context["params.#{name}_page"] || 1
            current_page = 1
            path = sanitize_path(context['fullpath'])
            num_pages = 0
            carousel = {
              :pages => [].tap do |ret|
                coll = collection.is_a?(Array) ? collection : collection.send(:collection)
                coll.each_slice(@per_page) {|x| num_pages += 1 }
                coll.each_slice(@per_page) do |page|
                  ret << {
                    :current_page  => current_page,
                    :selected      => (params_page == current_page),
                    :first         => (current_page == 1),
                    :last          => (current_page == num_pages),
                    :collection    => page
                  }.stringify_keys!
                  current_page += 1
                end
              end,
              :num_pages     => num_pages,
              :previous_page => (current_page - 1),
              :next_page     => (current_page + 1),
              :per_page      => @per_page
            }.stringify_keys!

            context['carousel'] = carousel

            render_all(@nodelist, context)
          end
        end

        private

        def sanitize_path(path)
          _path = path.gsub(/page=[0-9]+&?/, '').gsub(/_pjax=true&?/, '')
          _path = _path.slice(0..-2) if _path.last == '?' || _path.last == '&'
          _path
        end

      end

      ::Liquid::Template.register_tag('carousel', Carousel)
    end
  end
end
