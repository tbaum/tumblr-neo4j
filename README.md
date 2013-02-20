tumblr-neo4j
============

create a tumbler api-key http://www.tumblr.com/oauth/apps and write it into local-config `.tumblr_api_key`


Run it Local
------------
download and start Neo4j, see http://www.neo4j.org/install

    npm install
    ./node_modules/streamline/bin/_coffee app._coffee

then open your browser at http://localhost:3000


Deploy to Heroku
----------------

    heroku create my-app-name
    heroku addons:add neo4j
    heroku config:set TUMBLR_API_KEY=ENS5wHXXXXXXXXXXXXXXXXXXXXXXmNOaY5KG8
    git push heroku master

