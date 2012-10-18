module Locomotive
  module CarrierWave
    module Uploader
      module Asset

        extend ActiveSupport::Concern

        included do

          process :set_content_type
          process :set_size
          process :set_width_and_height
          version :compiled, :if => :wants_compilation? do
            process :compile_js_css
          end

        end

        module ClassMethods

          def content_types
            {
              :image      => ['image/jpeg', 'image/pjpeg', 'image/gif', 'image/png', 'image/x-png', 'image/jpg', 'image/x-icon'],
              :media      => [/^video/, 'application/x-shockwave-flash', 'application/x-flash-video', 'application/x-swf', /^audio/, 'application/ogg', 'application/x-mp3'],
              :pdf        => ['application/pdf', 'application/x-pdf', 'application/doc', 'application/docx', 'application/msword'],
              :stylesheet => ['text/css'],
              :javascript => ['text/javascript', 'text/js', 'application/x-javascript', 'application/javascript', 'text/x-component'],
              :font       => ['application/x-font-ttf', 'application/vnd.ms-fontobject', 'image/svg+xml', 'application/x-woff'],
              :scss       => ['text/x-scss'],
              :coffeescript => ['text/x-coffeescript']
            }
          end


        end

        def set_content_type(*args)
          value = :other
          content_type = file.content_type == 'application/octet-stream' ? File.mime_type?(original_filename) : file.content_type

          self.class.content_types.each_pair do |type, rules|
            rules.each do |rule|
              case rule
              when String then value = type if content_type == rule
              when Regexp then value = type if (content_type =~ rule) == 0
              end
            end
          end

          model.content_type = value
        end

        def set_size(*args)
          model.size = file.size
        end

        def set_width_and_height
          if model.image?
            magick = ::Magick::Image.read(current_path).first
            model.width, model.height = magick.columns, magick.rows
          end
        end

        def image?(file)
          model.image?
        end

        def wants_compilation?( text )
          model.respond_to?(:stylesheet_or_javascript?) and model.stylesheet_or_javascript? and model.compile?
        end

        def compile_js_css(*args)
          cache_stored_file! if !cached?

          pre_suffix = model.stylesheet? ? '.css' : '.js'
          path = model.source.path.to_s.gsub( /(\.scss|\.coffee)$/, "#{pre_suffix}\\1" )
          FileUtils.cp( model.source.path, path )
          # With using Sprockets we are able to import everything from gems or the app itself
          assets = Rails.application.assets

          # Sprockets uses a Cache on Production, but we need the version that allows us to append a path
          assets = assets.instance_variable_get('@environment') if assets.class == Sprockets::Index
          # we do not want to change something, so no index expiration
          assets.define_singleton_method('expire_index!', proc { false } )
          # append necessary paths
          ( Locomotive.config.assets_append_paths || [] ).each { |p| assets.append_path( p ) }

          assets.append_path( File.dirname( path ) )

          #
          # and finaly compile all the stuff
          asset = if model.stylesheet?
            assets.append_path( create_local_assets_temp_directory! )
            Sprockets::ProcessedAsset.new( assets, path, Pathname.new(path) )
          else
            assets.append_path( File.expand_path( model.source.store_dir, Rails.public_path ) )
            Sprockets::BundledAsset.new( assets, path, Pathname.new( path ) )
          end

          asset.write_to( current_path )
        rescue
          raise ::CarrierWave::ProcessingError, "#{$!} #{$@}"
        end

        def remote_storage?
          ::CarrierWave::Uploader::Base.storage == ::CarrierWave::Storage::Fog
        end

        def create_local_assets_temp_directory!
          local_assets_temp_directory = Rails.root.join( 'tmp', 'sprockets_fog_local_assets' )
          Dir.mkdir( local_assets_temp_directory ) unless File.directory? local_assets_temp_directory

          asset_type_folder = model.stylesheet? ? "stylesheets" : "javascripts"

          asset_type_temp_directory = local_assets_temp_directory.join( asset_type_folder )
          Dir.mkdir( asset_type_temp_directory ) unless File.directory? asset_type_temp_directory

          model.site.theme_assets.where( folder: asset_type_folder ).each do |asset|
            File.open( asset_type_temp_directory.join( asset.source_filename ), "w" ) do |f|
              f.write( asset.source.read )
            end
          end

          asset_type_temp_directory
        end

      end
    end
  end
end
