module Locomotive
  module Liquid
    module Tags
      class Filter < ::Liquid::Block
        # {% filter contents.filtered_collection fields: [select_field, association.select_field, bool_field] %}
        #   {% for f in filter.filters %}
        #     {{ f.name }}
        #   {% endfor %}
        #   {% for content_entry in filter.collection %}
        #     !{{ content_entry }}!
        #   {% endfor %}
        # {% endfilter %}

        TagAttributes = /\s*\[*([\w.]*):*\,*\s*\]*/

        def initialize(tag_name, markup, tokens, context)
          @collection, fields, *@filters =
            markup.scan(TagAttributes).flatten.delete_if{|x| x == ""}
          @collection_name = @collection.split(".").last
          throw SyntaxError unless @collection && @filters && @filters.is_a?(Array) &&
            @filters.length > 0 && fields == 'fields'
          super
        end

        def render(context)
          arguments = parse_filter_values(context['fullpath'], @filters, @collection_name)
          context.stack do
            filter = {
              'filters'    => build_filters(@collection, @filters, context, arguments),
              'collection' => filtered_collection(@collection, @filters, context, arguments)
            }.stringify_keys
            context['filter'] = filter
            render_all(@nodelist, context)
          end
        end

        private

        def parse_filter_values(path, filters, collection)
          return {} unless path =~ /\?/
          params = ::Rack::Utils::parse_nested_query(path.split("?").last)
          {}.tap do |ret|
            coll = params[@collection_name]
            coll.each do |key, value|
              filters.each do |filter|
                ret[key] = value if filter.split(".").first == key
              end
            end if coll
          end
        end

        def build_filters(collection_name, filters, context, filter_values)
          ret = []
          type = context[collection_name].content_type
          filters.each do |filter|
            fields = type.entries_custom_fields
            filter_object = filter.split(".").reduce(nil) do |reduce_ret, field_name|
              field = fields.to_a.find {|x| x.name == field_name}
              throw Exception.new("Field not found") unless field
              case field.type
              when 'select'
                {
                  'name' => field.name,
                  'param' => "#{filter_to_param(filter)}[]",
                  'type' => 'select',
                  'options' => field.select_options.map{|x|{'label' => x.name, 'value' => x.name }}
                }
              when 'boolean'
                {
                  'name' => field.name,
                  'param' => filter_to_param(filter),
                  'type' => 'boolean'
                }
              when 'many_to_many' || 'has_many'
                content_type = field.class_name.constantize.first.content_type
                fields = content_type.entries_custom_fields
                c = context["contents.#{content_type.slug}"].send(:collection)
                {
                  'name' => field.name,
                  'param' => "#{filter_to_param(filter)}[]",
                  'type' => 'model',
                  'options' => c.map{|x|{'label' => x._permalink, 'value' => x._permalink }}
                }
              else reduce_ret
              end
            end
            ret << filter_object.stringify_keys
          end
          ret
        end

        def filtered_collection(collection_name, filters, context, filter_values)
          type = context[collection_name].content_type
          filtered = Set.new
          filters.each do |filter|
            (association_name, subfield_name) = filter.split(".")
            fields             = type.entries_custom_fields
            association_values = filter_values[association_name]
            if subfield_name && association_values
              subfield_values  = association_values[subfield_name]
            end
            next unless association_values
            association        = fields.to_a.find {|x| x.name == association_name}
            association_type   = association.class_name.constantize.first.content_type
            if subfield_name
              subfield = association_type.entries_custom_fields.to_a.find{|x| x.name == subfield_name }
              criteria = case subfield.type
                when 'select'
                  option_ids = subfield.select_options.where({
                    :name.in => subfield_values }).map &:_id
                  {"#{subfield_name}_id".to_sym.in => option_ids}
                when 'boolean'
                  {"#{subfield_name}".to_sym => (subfield_values == 'on' || subfield_values == 'true')}
                end
              association_type.entries.where(criteria).map(
                &"#{association.inverse_of.singularize}_ids".to_sym).flatten.each do |id|
                filtered << id
              end
            else
              criteria = case association.type
                when 'many_to_many' || 'has_many'
                  binding.pry
                when 'belongs_to'
                  binding.pry
                when 'select'
                  binding.pry
                when 'boolean'
                  binding.pry
                when 'string'
                  binding.pry
                else throw Error.new("Invalid filter association type: #{association.type}")
                end
              type.entries.where(criteria).map(:_id).each do |id|
                filtered << id
              end
            end
          end
          type.entries.where({:_id.in => filtered.to_a}).to_liquid.stringify_keys
        end


        def filter_to_param(filter)
          "#{@collection_name}[#{filter.split(".").join("][")}]"
        end

        # def subfield

      end

      ::Liquid::Template.register_tag('filter', Filter)
    end
  end
end
