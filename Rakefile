require 'rubygems'
require 'rake/clean'
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
  s.name = 'fliewr'
  s.version = File.read('VERSION')
  s.date = File.mtime('VERSION')
  s.summary = 'Flickr Viewer'
  s.description = 'Gtk application to monitor updates from Flickr contacts'
  s.author = 'Paul Philippov'
  s.email = 'themactep@gmail.com'
  s.homepage = 'http://themactep.com/fliewr'

  s.executables = ['fliewr']
  s.files = FileList["{bin,data,lib}/**/*","[A-Z]*"].to_a
  s.require_path = "lib"
  s.bindir = "bin"

  s.has_rdoc = false
  s.extra_rdoc_files = ['README', 'LICENSE']

  s.add_dependency "ppds-libs"
  s.add_dependency "libxml-ruby"
  s.add_dependency "rest-client"

  s.rubyforge_project = 'fliewr'
end

Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
  p.need_tar = true
  p.need_zip = true
end
