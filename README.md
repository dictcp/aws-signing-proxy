# aws-signing-proxy
Small reverse proxy that signs http requests to AWS services on the fly using IAM credentials. It can be used to be able to make http calls with regular http clients or browsers to the new AWS ElasticSearch service. So you don't need to rely on IP restrictions but on the more granular IAM permissions.

## Usage
- Run it with `bundle install --deployment &&  bundle exec ./proxy.rb`
- In your browser call http://localhost:8080/
