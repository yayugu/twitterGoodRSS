require './model'

desc 'Setup Database'
task 'db:migrate' do
  puts 'Setup Database...'
  DataMapper::Logger.new($stdout, :debug)
  DataMapper.setup(:default, ENV['DATABASE_URL'] || 'sqlite3:db.sqlite3')
  DataMapper.auto_migrate!
end


