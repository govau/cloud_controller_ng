ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('../app', __dir__))
$LOAD_PATH.unshift(File.expand_path('../middleware', __dir__))

require 'bundler/setup' # Set up gems listed in the Gemfile.

# instead of using require 'bootscale/rails' per the docs, we'll
# instead do what it does, so that we can specify a custom TMPDIR
require 'bootscale'
Bootscale.setup(cache_directory: ENV['BOOTSCALE_TMP'] || 'tmp/bootscale')
require 'bootscale/active_support'
Bootscale::ActiveSupport.setup
