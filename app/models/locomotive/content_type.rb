module Locomotive
  class ContentType

    include Locomotive::Mongoid::Document

    ## extensions ##
    include CustomFields::Source
    include Extensions::ContentType::DefaultValues
    include Extensions::ContentType::ItemTemplate
    include Extensions::ContentType::Sync

    ## fields ##
    field :name
    field :description
    field :slug
    field :label_field_id,              :type => BSON::ObjectId
    field :label_field_name
    field :group_by_field_id,           :type => BSON::ObjectId
    field :order_by
    field :order_direction,             :default => 'asc'
    field :public_submission_enabled,   :type => Boolean, :default => false
    field :public_submission_accounts,  :type => Array

    ## associations ##
    belongs_to  :site,      :class_name => 'Locomotive::Site'
    has_many    :entries,   :class_name => 'Locomotive::ContentEntry', :dependent => :destroy

    ## named scopes ##
    scope :ordered, :order_by => :updated_at.desc

    ## indexes ##
    index [[:site_id, Mongo::ASCENDING], [:slug, Mongo::ASCENDING]]

    ## callbacks ##
    before_validation   :normalize_slug
    after_validation    :bubble_fields_errors_up
    before_update       :update_label_field_name_in_entries

    ## validations ##
    validates_presence_of   :site, :name, :slug
    validates_uniqueness_of :slug, :scope => :site_id
    validates_size_of       :entries_custom_fields, :minimum => 1, :message => :too_few_custom_fields

    ## behaviours ##
    custom_fields_for :entries

    ## methods ##

    def order_manually?
      self.order_by == '_position'
    end

    def order_by_definition(reverse_order = false)
      direction = self.order_manually? ? 'asc' : self.order_direction || 'asc'

      if reverse_order
        direction = (direction == 'asc' ? 'desc' : 'asc')
      end

      [order_by_attribute, direction]
    end

    def ordered_entries(conditions = {})
      conditions = translate_scope_by_id((conditions || {}).stringify_keys)
      _overriden_order_by = conditions.delete("order_by").try(:split)
      _order_by_definition = _overriden_order_by || self.order_by_definition
      self.entries.order_by([_order_by_definition]).where(conditions)
    end

    def groupable?
      !!self.group_by_field && %w(select belongs_to tag_set).include?(group_by_field.type)
    end

    def group_by_field
      self.entries_custom_fields.find(self.group_by_field_id) rescue nil
    end

    def list_or_group_entries
      if self.groupable?
        if group_by_field.type == 'select'
          self.entries.group_by_select_option(self.group_by_field.name, self.order_by_definition)
        elsif group_by_field.type == 'tag_set'
          self.entries.group_by_tag(self.group_by_field.name, self.order_by_definition)
        else
          group_by_belongs_to_field(self.group_by_field)
        end
      else
        self.ordered_entries
      end
    end

    def class_name_to_content_type(class_name)
      self.class.class_name_to_content_type(class_name, self.site)
    end

    def label_field_id=(value)
      # update the label_field_name if the label_field_id is changed
      new_label_field_name = self.entries_custom_fields.where(:_id => value).first.try(:name)
      self.label_field_name = new_label_field_name
      super(value)
    end

    def label_field_name=(value)
      # mandatory if we allow the API to set the label field name without an id of the field
      @new_label_field_name = value unless value.blank?
      super(value)
    end

    # Retrieve from a class name the associated content type within the scope of a site.
    # If no content type is found, the method returns nil
    #
    # @param [ String ] class_name The class name
    # @param [ Locomotive::Site ] site The Locomotive site
    #
    # @return [ Locomotive::ContentType ] The content type matching the class_name
    #
    def self.class_name_to_content_type(class_name, site)
      if class_name =~ /^Locomotive::Entry(.*)/
        site.content_types.find($1)
      else
        nil
      end
    end

    def to_presenter
      Locomotive::ContentTypePresenter.new(self)
    end

    def as_json(options = {})
      self.to_presenter.as_json
    end

    protected

    def group_by_belongs_to_field(field)
      grouped_entries     = self.ordered_entries.group_by(&:"#{field.name}_id")
      columns             = grouped_entries.keys
      target_content_type = self.class_name_to_content_type(field.class_name)
      all_columns         = target_content_type.ordered_entries

      all_columns.map do |column|
        if columns.include?(column._id)
          {
            :name     => column._label(target_content_type),
            :entries  => grouped_entries.delete(column._id)
          }
        else
          nil
        end
      end.compact.tap do |groups|
        unless grouped_entries.empty? # "orphans" ?
          groups << { :name => nil, :entries => grouped_entries.values.flatten }
        end
      end
    end

    def order_by_attribute
      return self.order_by if %w(created_at updated_at _position).include?(self.order_by)
      self.entries_custom_fields.find(self.order_by).name rescue 'created_at'
    end

    def normalize_slug
      self.slug = self.name.clone if self.slug.blank? && self.name.present?
      self.slug.permalink! if self.slug.present?
    end

    def bubble_fields_errors_up
      return if self.errors[:entries_custom_fields].empty?

      hash = { :base => self.errors[:entries_custom_fields] }

      self.entries_custom_fields.each do |field|
        next if field.valid?
        key = field.persisted? ? field._id.to_s : field.position.to_i
        hash[key] = field.errors.to_a
      end

      self.errors.set(:entries_custom_fields, hash)
    end

    def update_label_field_name_in_entries
      self.klass_with_custom_fields(:entries).update_all :_label_field_name => self.label_field_name
    end

    # Makes sure the class_name filled in a belongs_to or has_many field
    # does not belong to another site. Adds an error if it presents a
    # security problem.
    #
    # @param [ CustomFields::Field ] field The field to check
    #
    def ensure_class_name_security(field)
      if field.class_name =~ /^Locomotive::Entry([a-z0-9]+)$/
        content_type = Locomotive::ContentType.find($1)

        if content_type.site_id != self.site_id
          field.errors.add :class_name, :security
        end
      else
        # for now, does not allow external classes
        field.errors.add :class_name, :security
      end
    end

    # Translates with_scope conditions that use strings to proper scopes by id for field types that need it
    # Example:
    # "field_name: given_value" ----> "field_name_id: <id of select option with name == given_value>"
    def translate_scope_by_id(conditions = {})
      translated_conditions = {}
      types_needing_translation = %w(select tag_set)
      conditions.each_pair do |key, value|
        key_parts = key.split('.')
        field_name = key_parts[0]
        key_parts.length > 1 ? search_modifier = key_parts[1] : ""

        field = self.entries_custom_fields.where({"name" => field_name}).first

        if( !field.nil? && types_needing_translation.include?(field.type) )
          if(field.type == "select")
            if value.empty?
              # with_scope select_field = "" should give the entries not assigned a value
              translated_conditions["#{field_name}_id"] = nil
            else
              option = field.select_options.where({'name' => value}).first
              #if there's no option by that name, then no entries will be given - the Id is one that's never been used
              #if there is an option, find the entries by that option's id
              option.nil? ? translated_conditions["#{field_name}_id"] = BSON::ObjectId.new : translated_conditions["#{field_name}_id"] = option._id
            end
          elsif(field.type == "tag_set")
            if value.empty?
              translated_conditions["#{field_name.singularize}_ids"] = nil
            else
              tag_list = value.split(',').map {|tag_name| CustomFields::Types::TagSet::Tag.find_tag_by_name(tag_name)}
              tag_list.delete_if{|tag| tag.nil?}
              if tag_list.blank?
                translated_conditions["raw_#{field_name.singularize}_ids"] = []
              else
                translated_conditions["raw_#{field_name.singularize}_ids"] = {"$all" => tag_list.map{|x| x['_id']} }
              end
            end
          else
            translated_conditions[key] = value
          end
        else
          translated_conditions[key] = value
        end
      end
      translated_conditions
    end

  end
end

