module Locomotive
  module Liquid
    module Tags

      class InputTag < ::Liquid::Tag
        Syntax = /(\w+|\w+\.\w+)\s*\:\s*(#{::Liquid::QuotedFragment}+)?/

        def initialize(tag_name, markup, tokens, context)
          markup.scan(Syntax) do |key, value|
            @name = value if key == 'name'
            @value = value if key == 'value'
          end
        end
        SELECTED = 'checked'
        def selected
          param = params[@name]
          selected = param == @value ? SELECTED : ''
        end
      end

      # Display a radio button
      # {% radio name: nameparam, value: valueparam %}
      # output
      class Radio < InputTag
        def render(context)
          %!<input type="radio" name="#{@name}" value="#{@value}" #{selected}/>!
        end
      end
      ::Liquid::Template.register_tag('radio', Radio)
    end
  end
end
