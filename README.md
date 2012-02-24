TwitterGoodRSS
====================

TwitterGoodRSS is web service generate RSS better than Twitter official one.


Install
------------------

### Heroku
    git clone git://github.com/yayugu/twitterGoodRSS.git
    cd TwitterGoodRSS
    heroku create --stack cedar
    git push heroku master
    heroku config:add CONSUMER_KEY="**********"
    heroku config:add CONSUMER_SECRET="*********"
    heroku run rake db:migrate
Done!


### local or normal server
    git clone git://github.com/yayugu/twitterGoodRSS.git
    cd TwitterGoodRSS
    echo "ENV['CONSUMER_KEY'] = '******'" >> env.rb
    echo "ENV['CONSUMER_SECRET'] = '******'" >> env.rb
    rake db:migrate
Done!

This program suppose DB is:

SQLite: on local or normal server

postgreSQL: on Heroku



You want to use another DB, please change code around DataMapper.

