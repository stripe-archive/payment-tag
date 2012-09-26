task :build do
  require 'sprockets'
  require 'uglifier'

  class Sprockets::JstProcessor
    def self.default_namespace
      'this.PaymentTag'
    end
  end

  environment = Sprockets::Environment.new
  environment.append_path 'src'

  File.open('lib/tag.dev.js', 'w+') do |file|
    file.write environment['index'].to_s
  end

  File.open('lib/tag.js', 'w+') do |file|
    file.write Uglifier.compile(environment['index'].to_s)
  end
end

task :watch do
  require 'listen'
  Rake::Task['build'].execute
  puts 'Watching...'

  Listen.to('src') do
    puts 'Rebuilding...'
    Rake::Task['build'].execute
    puts 'Built'
  end
end

task :default => :build
