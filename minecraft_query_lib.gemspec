Gem::Specification.new do |s|
  s.name                  = "minecraft_query_lib"
  s.summary               = "Simple library to query minecraft servers in a more reliable way than using standard UDP"
  s.version               = "0.0.1"
  s.author                = "immortaleeb"
  s.platform              = Gem::Platform::RUBY
  s.required_ruby_version = '>=1.9'
  s.files                 = Dir['lib/*.rb', 'lib/**/*.rb']
  s.has_rdoc              = false
end