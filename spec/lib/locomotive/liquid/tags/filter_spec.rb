require 'spec_helper'

describe Locomotive::Liquid::Tags::Filter do
  it 'has a valid syntax' do
    markup = "contents.entries fields: [type, rum, rum.type, featured, favorite]"
    lambda do
      Locomotive::Liquid::Tags::Filter.new('filter', markup, ["{% endfilter %}"], {})
    end.should_not raise_error
  end

  it 'raises an error if the syntax is incorrect' do
    ["contents.entries",
     "contents.entries feilds: []"].each do |markup|
      lambda do
        Locomotive::Liquid::Tags::Filter.new('filter', markup, ["{% endfilter %}"], {})
      end.should raise_error
    end
  end

  it 'renders the collection' do
    template  = Liquid::Template.parse(default_template)
    text      = template.render!(liquid_context)
    binding.pry
    text.should_not == nil
    text.should_not == ''
    text.should match /!entry-1!/
  end

  it 'grabs the filter values from the filters and page params' do
    template  = Liquid::Template.parse(default_template)
    text      = template.render!(liquid_context(:fullpath => "/?entries[type]=one"))
    text.should_not == nil
    text.should_not == ''
    text.should match /!entry-1!/
  end

  def liquid_context(options={})
    ::Liquid::Context.new(
      {},
      {
        'fullpath' => options[:fullpath] || '/',
        'entries'  => Collection.new([{'_permalink' => 'entry-1', 'type' => 'one'},
                                      {'_permalink' => 'entry-2', 'type' => 'two'}])

      },{
        :page     => FactoryGirl.build(:page)
      }, true)
  end

  def default_template
    """
    {% filter entries fields: [type] %}
     {% for content_entry in filter.collection %}
         !{{ content_entry.type }}!
         !{{ content_entry._permalink }}!
       {% endfor %}
    {% endfilter %}
    """
  end

  class Collection
    def initialize(collection)
      @collection = collection || []
    end

    def each(&block)
      @collection.each(&block)
    end

    def method_missing(method, *args)
      @collection.send(method, *args)
    end

    def to_liquid
      self
    end
  end
end
