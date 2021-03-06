module Middleman

  module Sitemap

    module Extensions

      module Proxies

        # Setup extension
        class << self

          # Once registered
          def registered(app)
            ::Middleman::Sitemap::Resource.send :include, ResourceInstanceMethods

            # Include methods
            app.send :include, InstanceMethods
          end

          alias :included :registered
        end

        module ResourceInstanceMethods
          # Whether this page is a proxy
          # @return [Boolean]
          def proxy?
            !!@proxied_to
          end

          # Set this page to proxy to a target path
          # @param [String] target
          # @return [void]
          def proxy_to(target)
            target = ::Middleman::Util.normalize_path(target)
            raise "You can't proxy #{path} to itself!" if target == path
            @proxied_to = target
          end

          # The path of the page this page is proxied to, or nil if it's not proxied.
          # @return [String]
          def proxied_to
            @proxied_to
          end

          # Whether this page has a template file
          # @return [Boolean]
          def template?
            if proxy?
              store.find_resource_by_path(proxied_to).template?
            else
              super
            end
          end

          def get_source_file
            if proxy?
              proxy_resource = store.find_resource_by_path(proxied_to)

              unless proxy_resource
                raise "Path #{path} proxies to unknown file #{proxied_to}:#{store.resources.map(&:path)}"
              end

              if proxy_resource.proxy?
                raise "You can't proxy #{path} to #{proxied_to} which is itself a proxy."
              end

              proxy_resource.source_file
            end
          end
        end

        module InstanceMethods
          def proxy_manager
            @_proxy_manager ||= ProxyManager.new(self)
          end

          def proxy(*args)
            proxy_manager.proxy(*args)
          end
        end

        class ProxyManager
          def initialize(app)
            @app = app

            @proxy_paths = {}
          end

          # Setup a proxy from a path to a target
          # @param [String] path
          # @param [String] target
          # @return [void]
          def proxy(path, target)
            @proxy_paths[::Middleman::Util.normalize_path(path)] = ::Middleman::Util.normalize_path(target)
            @app.sitemap.rebuild_resource_list!(:added_proxy)
          end

          # Update the main sitemap resource list
          # @return [void]
          def manipulate_resource_list(resources)
            resources + @proxy_paths.map do |key, value|
              p = ::Middleman::Sitemap::Resource.new(
                @app.sitemap,
                key
              )
              p.proxy_to(value)
              p
            end
          end
        end
      end
    end
  end
end
