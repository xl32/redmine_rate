gem 'deface'
gem 'lockfile', '~> 2.1.3'
gem 'money'

group :test do
  # shoulda-matchers 6.x supports Rails 7.1+/8.0; the meta 'shoulda' gem still
  # pins matchers to the Rails-6-era 4.x line.
  gem 'shoulda-context'
  gem 'shoulda-matchers'
  # Redmine 6.x no longer bundles rails-controller-testing, but the functional
  # tests rely on assigns/assert_template.
  gem 'rails-controller-testing'
end
