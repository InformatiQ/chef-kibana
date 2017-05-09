resource_name :kibana_plugin

property :name, String, name_property: true
property :url, String
property :plugin_dir, String, default: ::File.join(node['kibana']['base_dir'], 'current', 'installedPlugins')
property :kibana_home, String, default: ::File.join(node['kibana']['base_dir'], 'current')
property :plugins_registry, String, default: ::File.join(node['kibana']['base_dir'], 'installedPugins.json')

default_action :nothing

load_current_value do
  if ::File.exist?(plugins_registry)
    pfile = ::File.open(plugins_registry)
    plugins = JSON.parse(pfile.read)
    url plugins[name]
  end
end

def plugin_exists?(name)
  list_arg = node['kibana']['version'][0].to_i > 4 ? 'list' : '-l'
  cmd_line = "bin/kibana plugin #{list_arg}"
  cmd = Mixlib::ShellOut.new(cmd_line, cwd: kibana_home)
  cmd.run_command
  cmd.stdout.include? name
end

def update_plugin_reg(action)
  plugins = ::File.exist?(plugins_registry) ? JSON.parse(::File.read(plugins_registry)) : {}
  case action
  when 'add'
    plugins[name] = new_resource.url
  when 'remove'
    plugins.delete(name)
  end
  ::File.open(plugins_registry, 'w') { |file| file.write(JSON.pretty_generate(plugins)) }
end

action :install do
  install_arg = node['kibana']['version'][0].to_i > 4 ? "install #{url}" : "-i #{name} -u #{url}"
  plugin_install = "bin/kibana plugin #{install_arg} -d #{plugin_dir}"
  execute 'plugin-install' do
    cwd kibana_home
    command plugin_install
    not_if { plugin_exists?(new_resource.name) }
  end
  update_plugin_reg('add')
end

action :remove do
  remove_arg = node['kibana']['version'][0].to_i > 4 ? "remove #{name}" : "--remove #{name}"
  plugin_remove = "bin/kibana plugin #{remove_arg} -d #{plugin_dir}"
  execute 'plugin-remove' do
    cwd kibana_home
    command plugin_remove
    only_if { plugin_exists?(new_resource.name) }
  end
  update_plugin_reg('remove')
end

action :update do
  if new_resource.url != current_resource.url
    kibana_plugin name do
      action :remove
      plugin_dir new_resource.plugin_dir
      kibana_home new_resource.kibana_home
      only_if { plugin_exists?(new_resource.name) }
    end
    kibana_plugin name do
      action :install
      url new_resource.url
      plugin_dir new_resource.plugin_dir
      kibana_home new_resource.kibana_home
    end
  end
end
