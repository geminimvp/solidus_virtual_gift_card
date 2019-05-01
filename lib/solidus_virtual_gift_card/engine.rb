# frozen_string_literal: true

module SolidusVirtualGiftCard
  class Engine < Rails::Engine
    isolate_namespace Spree
    engine_name 'solidus_virtual_gift_card'

    config.autoload_paths += %W(#{config.root}/lib)

    # use rspec for tests
    config.generators do |g|
      g.test_framework :rspec
    end

    initializer 'solidus_virtual_gift_card.environment', before: :load_config_initializers do |app|
      if Spree::Backend::Config.respond_to?(:menu_items)
        Spree::Backend::Config.configure do |config|
          config.menu_items << config.class::MenuItem.new(
            [:gift_cards],
            'wpforms',
            label: :gift_cards,
            condition: -> { can?(:manage, Spree::VirtualGiftCard) }
          )
        end
      end
    end

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), '../../app/**/*_decorator*.rb')) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end

    config.to_prepare(&method(:activate).to_proc)
  end
end
