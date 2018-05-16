require 'rubocop/rake_task'
require 'safe_yaml/load'

task default: %w[assets:verify rubocop proof]
task external: %w[assets:verify rubocop proof_external]

namespace :assets do
  task :precompile do
    puts `bundle exec jekyll build`
  end

  task :verify do
    ruby './verify.rb'
  end
end

task proof: 'assets:precompile' do
  Rake::Task[:check_site].invoke(
    check_html: true,
    disable_external: true,
    hydra: { max_concurrency: 50 }
  )
end

task proof_external: 'assets:precompile' do
  Rake::Task[:check_site].invoke(
    external_only: true,
    http_status_ignore: [0, 301, 302, 403, 503],
    hydra: { max_concurrency: 20 }
  )
end

RuboCop::RakeTask.new

task :check_site, [:opts] do |_task, args|
  require 'html-proofer'

  dir = './_site'
  if File.exist?('_config.yml')
    config = SafeYAML.load_file('_config.yml')
    dir = config['destination'] || dir
  end
  defaults = {
    assume_extension: true,
    check_favicon: true,
    check_opengraph: true,
    file_ignore: ["#{dir}/google75bd212ec246ba4f.html"],
    url_ignore: ['https://fonts.gstatic.com/',
                 'https://abs.twimg.com',
                 'https://cdn.syndication.twimg.com',
                 'https://fonts.googleapis.com/',
                 'https://pbs.twimg.com',
                 'https://syndication.twitter.com'],
    cache: { timeframe: '1w' }
  }
  HTMLProofer.check_directory(dir, defaults.merge(args.opts)).run
end
