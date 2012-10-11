module Locomotive
  class ThemeAsset

    include Locomotive::Mongoid::Document

    ## extensions ##
    include Extensions::Asset::Types

    ## fields ##
    field :local_path
    field :content_type
    field :compile,           :type => Boolean, :default => false
    field :width,   :type => Integer
    field :height,  :type => Integer
    field :size,    :type => Integer
    field :folder,  :default => nil
    mount_uploader :source, ThemeAssetUploader, :mount_on => :source_filename

    ## associations ##
    belongs_to :site, :class_name => 'Locomotive::Site'

    ## indexes ##
    index :site_id
    index [[:site_id, Mongo::ASCENDING], [:local_path, Mongo::ASCENDING]]

    ## callbacks ##
    before_validation :check_for_folder_changes
    before_validation :store_plain_text
    before_validation :sanitize_folder
    before_validation :build_local_path

    ## validations ##
    validates_presence_of   :site
    validates_presence_of   :source, :on => :create
    validates_presence_of   :plain_text_name, :if => Proc.new { |a| a.performing_plain_text? }
    validates_uniqueness_of :local_path, :scope => :site_id
    validates_integrity_of  :source
    validates_processing_of :source, :if => :compile

    validate                :content_type_can_not_changed

    ## named scopes ##

    ## accessors ##
    attr_accessor   :plain_text_name, :plain_text, :plain_text_type, :performing_plain_text
    attr_accessible :folder, :source, :plain_text_type, :performing_plain_text, :plain_text_name, :plain_text, :compile

    ## methods ##

    def mime_type_folder
      case self.content_type
      when :scss then 'stylesheets'
      when :coffeescript then 'javascripts'
      else self.content_type.to_s.pluralize
      end
    end

    def content_type_to_extension
      case self.content_type
      when :stylesheet then 'css'
      when :javascript then 'js'
      when :coffeescript then 'coffee'
      else self.content_type
      end
    end

    def stylesheet?
      [:scss, :stylesheet].include?(self.content_type)
    end

    def javascript?
      [:coffeescript, :javascript].include?(self.content_type)
    end


    def stylesheet_or_javascript?
      self.stylesheet? || self.javascript?
    end

    def embedable_type
      return :image if self.content_type == :image
      return :stylesheet if ((self.content_type == :scss and self.compile?) or self.content_type == :stylesheet)
      return :javascript if ((self.content_type == :coffeescript and self.compile?) or self.content_type == :javascript)
      nil
    end

    def local_path_without_root( what = self.local_path )
      what.gsub(/^.*?#{self.mime_type_folder}\//,'')
    end

    def select_source
      self.compile? ? self.source.compiled : self.source
    end

    def plain_text_name
      if not @plain_text_name_changed
        @plain_text_name ||= self.safe_source_filename
      end
      @plain_text_name.gsub(/(\.[a-z0-9A-Z]+)$/, '') rescue nil
    end

    def plain_text_name=(name)
      @plain_text_name_changed = true
      @plain_text_name = name
    end

    def plain_text
      if RUBY_VERSION =~ /1\.9/
        @plain_text ||= (self.source.read.force_encoding('UTF-8') rescue nil)
      else
        @plain_text ||= self.source.read
      end
    end

    def plain_text_type=( str )
      @plain_text_type = str.try(:to_sym)
    end

    def plain_text_type
      @plain_text_type || (stylesheet_or_javascript? ? self.content_type : nil)
    end

    def performing_plain_text?
      Boolean.set(self.performing_plain_text) || false
    end

    def store_plain_text
      return if self.persisted? && !self.stylesheet_or_javascript?
      self.content_type ||= @plain_text_type if self.performing_plain_text?
      data = self.performing_plain_text? ? self.plain_text : self.source.read
      return if !self.stylesheet_or_javascript? || self.plain_text_name.blank? || data.blank?
      sanitized_source = self.escape_shortcut_urls(data)
      self.source = ::CarrierWave::SanitizedFile.new({
        :tempfile => StringIO.new(sanitized_source),
        :filename => "#{self.plain_text_name}.#{self.content_type_to_extension}"
      })

      @plain_text = sanitized_source # no need to reset the plain_text instance variable to have the last version
    end

    def to_liquid
      { :url => self.select_source.url }.merge(self.attributes).stringify_keys
    end

    def as_json(options = {})
      Locomotive::ThemeAssetPresenter.new(self, options).as_json
    end

    def self.all_grouped_by_folder(site)
      assets = site.theme_assets.order_by([[:slug, :asc]])
      assets.group_by { |a| a.folder.split('/').first.to_sym }
    end

    protected

    def safe_source_filename
      self.source_filename || self.source.send(:original_filename) rescue nil
    end

    def sanitize_folder
      self.folder = self.mime_type_folder if self.folder.blank?

      # no accents, no spaces, no leading and ending trails
      self.folder = ActiveSupport::Inflector.transliterate(self.folder).gsub(/(\s)+/, '_').gsub(/^\//, '').gsub(/\/$/, '')

      # folder should begin by a root folder
      if (self.folder =~ /^(stylesheets|javascripts|images|media|fonts)/).nil?
        self.folder = File.join(self.mime_type_folder, self.folder)
      end
    end

    def build_local_path
      if filename = self.safe_source_filename
        self.local_path = File.join(self.folder, filename)
      else
        nil
      end
    end

    def escape_shortcut_urls(text)
      return if text.blank?

      text.gsub(/[("'](\/(stylesheets|javascripts|images|media|fonts)\/(([^;.]+)\/)*([a-zA-Z_\-0-9]+)\.[a-z]{2,4})[#?]*[a-zA-Z_\-0-9]*[)"']/) do |path|

        sanitized_path = path.gsub(/[("'\?#)]\w*/, '').gsub(/^\//, '')

        if asset = self.site.theme_assets.where(:local_path => sanitized_path).first
          "#{path.first}#{asset.source.url}#{path.last}"
        else
          path
        end
      end
    end

    def check_for_folder_changes
      # https://github.com/jnicklas/carrierwave/issues/330
      # https://github.com/jnicklas/carrierwave-mongoid/issues/23
      if self.persisted? && self.folder_changed? && !self.source_filename_changed?
        # a simple way to rename a file
        old_asset         = self.class.find(self._id)
        file              = old_asset.source.file
        file.content_type = File.mime_type?(file.path).to_s if file.content_type.nil?
        self.source       = file
        self.changed_attributes['source_filename'] = nil # delete the old file
      end
    end

    def content_type_can_not_changed
      self.errors.add(:source, :extname_changed) if self.persisted? && self.content_type_changed?
    end

  end
end
