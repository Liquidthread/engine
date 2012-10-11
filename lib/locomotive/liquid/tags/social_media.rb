module Locomotive
  module Liquid
    module Tags
      module Social
        SocialButtonSyntax = /(\w+|\w+\.\w+)\s*\:\s*(#{::Liquid::QuotedFragment})/
        class SocialButton < ::Liquid::Tag
          @@required_fields = []
          def initialize(tag_name, markup, tokens, context)
            @social_options = {}
            markup.scan(SocialButtonSyntax).each do |option, value|
              if @@required_fields
                binding.pry
              end
            end
            # raise ::Liquid::SyntaxError.new("Syntax Error in '#{tag_name}'")
          end
        end
    # %a.facebook-share-button(href="https://www.facebook.com/sharer/sharer.php?u={{ shareurl }}&t={{ sharetext }}" rel="external" target="_blank") f
    # .facebook-like-button
    #   .fb-like(data-href="{{ shareurl }}" data-send="false" data-layout="button_count" data-width="150" data-show-faces="false")
    # .twitter-share-box
    #   %a.twitter-share-button(href="https://twitter.com/share" data-url="{{ shareurl }}" data-text="{{ sharetext }}") Tweet
    # .pintrest-button
    #   %a.pin-it-button(count-layout="horizontal" href="http://pinterest.com/pin/create/button/?url={{ shareurl }}&media={{ sharephoto }}&description={{ sharetext }}" target="_blank")
    #     %img(border="0" src="//assets.pinterest.com/images/PinExt.png" title="Pin It")
    # %a.print-button{:href => "#", :onclick => "window.print(); return false;"}
    #   Print
    #   %i.icon-print
    # %a.email-share-link{:href => "mailto:recipient@example.com?body={{ shareurl }} {{ sharetext }}e&subject={{ ecard.copy | escape }}", :rel => "external", :target => "_blank"}
    #   Email
    #   %i.icon-envelope

        class FacebookLikeButton < SocialButton
          @@required_fields = %w(share_text share_url share_photo)
          def render(context)
            %(<h1>FacebookLikeButton</h1>)
          end
        end

        class FacebookShareButton < SocialButton
          @@required_fields = %w(share_text share_url share_photo)
          def render(context)
            %(<h1>FacebookShareButton</h1>)
          end
        end

        class PintrestPinitButton < SocialButton
          @@required_fields = %w(share_text share_url share_photo)
          def render(context)
            %(<h1>PintrestPinitButton</h1>)
          end
        end

        class TwitterTweetButton < SocialButton
          @@required_fields = %w(share_text share_url share_photo)
          def render(context)
            %(<h1>TwitterTweetButton</h1>)
          end
        end

        class EmailShareButton < SocialButton
          @@required_fields = %w(share_text share_url share_photo)
          def render(context)
            %(<h1>EmailShareButton</h1>)
          end
        end

        class PrintButton < SocialButton
          def render(context)
            %(<h1>PrintButton</h1>)
          end
        end

        class TwitterJavascriptTag < ::Liquid::Tag
          def render(context)
            %(<script type="text/javascript">
              (function(d,s,id){
                var js, tjs = d.getElementsByTagName(s)[0];
                if(d.getElementById(id)) return;
                js = d.createElement(s); js.id = id;
                js.src = "//platform.twitter.com/widgets.js";
                tjs.parentNode.insertBefore(js,tjs);
              }(document,'script','twitter-wjs'));
            </script>)
          end
        end

        class FacebookJavascriptTag < ::Liquid::Tag
          Syntax = /(#{::Liquid::Expression}+)?/
          def initialize(tag_name, markup, tokens, context)
            if markup =~ Syntax
              @account_id = $1.gsub('\'', '')
            else
              raise ::Liquid::SyntaxError.new("Syntax Error in 'facebook_javascript_tag' - Valid syntax: facebook_javascript_tag <account_id>")
            end
            super
          end
          def render(context)
            %(<script type="text/javascript">
              (function(d, s, id){
                var js, fjs = d.getElementsByTagName(s)[0];
                if (d.getElementById(id)) return;
                js = d.createElement(s); js.id = id;
                js.src = "//connect.facebook.net/en_US/all.js#xfbml=1&appId=#{@account_id}";
                fjs.parentNode.insertBefore(js, fjs);
              }(document,'script','facebook-jssdk'));
            </script>)
          end
        end

        class FacebookMetaTags < ::Liquid::Tag

          def initialize(tag_name, markup, tokens, context)

          end

          def render(context)
            %(<h1>FacebookMetaTag</h1>)
          end

        end

        class JQueryTag < ::Liquid::Tag
          def render(context)
            '<script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/1.8.2/jquery.min.js"></script>'
          end
        end
      end
      ::Liquid::Template.register_tag('twitter_javascript_tag',  Social::TwitterJavascriptTag)
      ::Liquid::Template.register_tag('facebook_javascript_tag', Social::FacebookJavascriptTag)
      ::Liquid::Template.register_tag('facebook_meta_tags',      Social::FacebookMetaTags)
      ::Liquid::Template.register_tag('facebook_like_button',    Social::FacebookLikeButton)
      ::Liquid::Template.register_tag('facebook_share_button',   Social::FacebookShareButton)
      ::Liquid::Template.register_tag('pintrest_pinit_button',   Social::PintrestPinitButton)
      ::Liquid::Template.register_tag('twitter_tweet_button',    Social::TwitterTweetButton)
      ::Liquid::Template.register_tag('email_share_button',      Social::EmailShareButton)
      ::Liquid::Template.register_tag('print_button',            Social::PrintButton)
      ::Liquid::Template.register_tag('jquery_tag',              Social::JQueryTag)
    end
  end
end
