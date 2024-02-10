#!/bin/bash

openssl genrsa -out common-words.local.key 2048
openssl req -new -key common-words.local.key -out common-words.local.csr
openssl x509 -req -days 365 -in common-words.local.csr -signkey common-words.local.key -out common-words.local.crt
openssl x509 -in common-words.local.crt -text -noout

exit 0