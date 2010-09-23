module SimpleNavigation

  # Simple Navigation helper methods module
  module Helper

    attr_accessor :current_menu_id

    # Renders simple navigation menu by key name
    def simple_navigation(name)

      # Load navigation hash
      navigation = SimpleNavigation::Builder.navigation[name.to_sym]

      # Reset current menu
      self.current_menu_id = nil

      html_attrs = { :id => navigation[:id], :class => 'simple_navigation' }
      html_attrs[:class] << " #{navigation[:class]}" if navigation.has_key?(:class)

      # Render root menus
      content_tag(:ul, navigation[:menus].map{ |menu| render_menu(menu) }, html_attrs)

    end # simple_navigation(name)

    protected

      # Render menu element
      def render_menu(menu, options = {})

        # Set default html attributes
        html_attrs = { :id => menu[:id] }
        html_attrs[:class] = menu[:class] || ""

        # Render submenus first so we can detect if current menu
        # is between child menu's
        menus = ''
        menus = content_tag(:ul,
          menu[:menus].map{ |child| render_menu(child, options) }) if menu.has_key?(:menus)

        # Is this menu is the current?
        if current_menu?(menu)
          html_attrs[:class] << ' current'
          self.current_menu_id = menu[:id]
        # If any of the children menus is the current
        # mark parent menu as current too
        elsif self.current_menu_id
          html_attrs[:class] << ' current' if
            self.current_menu_id.to_s.match(/^#{menu[:id]}/)
        end

        # Render menu
        content_tag(:li, render_menu_title(menu) + menus, html_attrs)

      end # render_menu(menu)

      # Renders the menu title
      #
      # * If menu hash has the title key it is used as the title for the menu being rendered
      # * If menu hash +:title+ key is not present then it formats +:name+ key as titleized string
      # * If menu hash +:title+ key is not present and i18n is turned on, then it will use +:name+ key as translation key
      def render_menu_title(menu)
        title = if menu.has_key?(:title)
          menu[:title]
        else
          if menu[:options][:i18n]
            t(menu[:translation], :default => menu[:name].to_s.titleize)
          else
            menu[:name].to_s.titleize
          end
        end
        link_to(title, (menu.has_key?(:url) ? url_for(menu[:url]) : "#" ))
      end # render_menu_title(menu)

      # Detects if the menu being rendered is the current
      # (it also marks parent menus as current).
      def current_menu?(menu)
        return false unless menu.has_key?(:url)
        current = (controller.params[:controller] == menu[:url][:controller].gsub(/^\//, "")) &&
          (controller.params[:action] == menu[:url][:action])
        if menu.has_key?(:urls)
           (menu[:urls].is_a?(Array) ? menu[:urls] : [menu[:urls]]).each do |controllers|
            (controllers.is_a?(Array) ? controllers : [controllers]).each do |c|
              current |= controller.params[:controller] == c[:controller].gsub(/^\//, "")
              if c.has_key?(:only)
                current &= (c[:only].is_a?(Array) ? c[:only] : [c[:only]]).include?(controller.params[:action])
              end
              if c.has_key?(:except)
                current &= !((c[:except].is_a?(Array) ? c[:except] : [c[:except]]).include?(controller.params[:action]))
              end
            end
          end
        end
        current
      end # current_menu?

  end # Helper

  # Simple Navigation configuration class
  class Configuration

    attr_accessor :navigation

    def initialize
      self.navigation = {}
    end

    def config(&block)
      builder = Builder.new
      yield builder
      builder.navigations.each { |tmp| self.navigation[tmp[:name]] = tmp }
    end

    # Simple Navigation configuration builder
    class Builder

      attr_accessor :navigations, :prefix

      def initialize
        self.navigations = []
      end

      # Create a new navigation
      def navigation(name, options = {}, &block)
        options.merge!(:i18n => false) unless options.has_key?(:i18n)
        navigation = Navigation.new(name, options)
        yield navigation
        self.navigations << navigation.build
      end

      # Render new navigation
      def build
        { :navigations => navigations }
      end

      # Hash structure containing simple navigation menu configuration
      class Navigation

        attr_accessor :id, :menus, :name, :options, :translation

        def initialize(name, options = {})
          options.merge!(:i18n => false) unless options.has_key?(:i18n)
          self.translation = ['simple_navigation', name].join('.')
          self.id = name
          self.menus = []
          self.name = name
          self.options = options
        end

        # Create a new root menu
        def menu(name, *args, &block)
          title = args.first.is_a?(String) ? args.first : nil
          options = args.last.is_a?(::Hash) ? args.last : {}
          options.merge!(:i18n => self.options[:i18n])
          options.merge!(:translation => [self.translation, 'menus'].join('.'))
          options.merge!(:prefix => self.id)
          menu = Menu.new(name, title, options)
          yield menu if block
          self.menus << menu.build
        end

        # render menu
        def build
          { :id => self.id.to_sym,
            :name => self.name.to_sym,
            :menus => self.menus,
            :options => self.options }
        end

        # Menu builder
        class Menu

          attr_accessor :id, :menus, :name, :options, :title, :translation, :url, :urls

          def initialize(name, title = nil, options = {})
            self.id = [options[:prefix], name].join('_')
            self.menus = []
            self.name = name
            self.title = title
            self.translation = [options[:translation], name].join('.')
            self.url = options[:url]
            self.urls = []
            options.delete(:translation)
            options.delete(:url)
            self.options = options
          end

          # Create a new child menu
          def menu(name, *args, &block)
            title = args.first.is_a?(String) ? args.first : nil
            options = args.last.is_a?(::Hash) ? args.last : {}
            options.merge!(:i18n => self.options[:i18n])
            options.merge!(:translation => [self.translation, 'menus'].join('.'))
            options.merge!(:prefix => self.id)
            menu = Menu.new(name, title, options)
            yield menu if block
            self.menus << menu.build
          end

          def connect(options = {})
            options[:controller] = self.url[:controller] unless options.has_key?(:controller)
            self.urls << options
          end

          def build
            menu = { :id => self.id.to_sym, :name => self.name.to_sym,
              :options => self.options }
            # Add keys with values only:
            menu.merge!(:menus => self.menus) unless self.menus.empty?
            menu.merge!(:title => self.title) unless self.title.nil?
            menu.merge!(:translation => [self.translation, 'title'].join('.')) if self.options[:i18n] == true
            menu.merge!(:url => self.url) unless self.url.nil?
            menu.merge!(:urls => self.urls) unless self.urls.empty?
            # Return menu hash
            menu
          end
        end # Menu
      end # Navigation
    end # Builder
  end # Configuration

  Builder = Configuration.new

end # SimpleNavigation

ActionView::Base.send :include, SimpleNavigation::Helper
