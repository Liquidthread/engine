module Locomotive
  module SitesHelper

    def ordered_current_site_locales
      current_site.locales + (Locomotive.config.site_locales - current_site.locales)
    end

    def options_for_site_locales
      Locomotive.config.site_locales.map do |locale|
        [I18n.t("locomotive.locales.#{locale}"), locale]
      end
    end

    def options_for_seo_image(site_param)
      site_param.theme_assets.reduce({}) do |options, asset|
        if asset.content_type == :image
          options.merge({
            asset.source_filename => ThemeAssetUploader.url_for(site_param, asset.local_path) 
          })
        else
          options
        end
      end
    end
    
  end
end