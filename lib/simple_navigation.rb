module SimpleNavigation

  module Helper

    attr_accessor :current_menu_id

    def simple_navigation(name)
      # Load navigation hash
      navigation = SimpleNavigation::Builder.navigation[name.to_sym]
      # Reset current menu
      self.current_menu_id = nil
      # Render root menus
      content_tag(:ul,
        navigation[:menus].map{ |menu| render_menu(menu) },
        :id => navigation[:id],
        :class => 'simple_navigation')
    end # simple_navigation(name)

    def render_menu(menu)
      class_name = 'menu'
      # Render submenus first so we can detect if current menu
      # is between child menu's
      menus = ''
      menus = content_tag(:ul,
        menu[:menus].map{ |child| render_menu(child) },
        :id => [menu[:id], 'menus'].join('_')) if menu.has_key?(:menus)
      # Is this menu is the current?
      if current_menu?(menu)
        class_name << ' current'
        self.current_menu_id = menu[:id]
      # Is the current menu under this menu?
      elsif self.current_menu_id
        class_name << ' current_child' if self.current_menu_id.to_s.match(/^#{menu[:id]}/)
      end
      # Render menu
      content_tag(:li,
        render_menu_title(menu) + menus,
        :id => menu[:id],
        :class => class_name)
    end # render_menu(menu)

    def render_menu_title(menu)
      title = ''
      if menu[:options][:i18n]
        if menu.has_key?(:title)
          title = t(menu[:translation], :default => menu[:title])
        else
          title = t(menu[:translation], :default => menu[:name].to_s.titleize)
        end
      else
        if menu.has_key?(:title)
          title = menu[:title]
        else
          title = menu[:name].to_s.titleize
        end
      end
      title = link_to(title, url_for(menu[:url])) if menu.has_key?(:url)
      title
    end # render_menu_title(menu)

    protected

      def current_menu?(menu)
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

      class Navigation

        attr_accessor :id, :menus, :name, :options, :translation

        def initialize(name, options = {})
          options.merge!(:i18n => false) unless options.has_key?(:i18n)
          self.translation = name
          self.id = ['simple_navigation', name].join('_')
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
          options.merge!(:prefix => [self.id, 'menus'].join('_'))
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
            options.merge!(:prefix => [self.id, 'menus'].join('_'))
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
