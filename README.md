# aws-signing-proxy
Small reverse proxy that signs http requests to AWS services on the fly using IAM credentials. It can be used to be able to make http calls with regular http clients or browsers to the new AWS ElasticSearch service. So you don't need to rely on IP restrictions but on the more granular IAM permissions.

## Usage
- Run it with `bundle install --deployment &&  bundle exec ./proxy.rb`
- In your browser call http://localhost:8080/
- It works with nginx for multiple domain proxying with HTTP header
```
    location / {
            proxy_set_header X-UPSTREAM-URL https://xxxxxxxxxxxxxxx.us-east-1.es.amazonaws.com;
            proxy_set_header X-UPSTREAM-REGION us-east-1;
            proxy_pass http://127.0.0.1:8080;
    }
```
