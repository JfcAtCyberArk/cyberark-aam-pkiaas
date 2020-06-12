#!/bin/bash
set -e
export CONJUR_APPLIANCE_URL=https://conjur-master
export CONJUR_AUTHN_LOGIN="host/pki-admin"
export CONJUR_CERT_FILE="$(pwd)/conjur.pem"
export CONJUR_ACCOUNT="conjur"
export CONJUR_AUTHN_API_KEY="2rx82kr2ynspkf04d5h1b3sdnfwpv5gy3zdr8h028fvnv616nksn0"

source conjur_utils.sh
session_token=$(conjur_authenticate)
export session_token="$session_token"

# create the self signed certificate
data='{
  "commonName": "cyberark.pki.local",
  "keyAlgo": "RSA",
  "keyBits": "2048",
  "selfSigned": true
}'
curl --fail -H "Content-Type: application/json" \
  -H "$session_token" \
  --data "$data" \
  http://localhost:8080/ca/generate
  

# create a test template
data='{
  "templateName": "testingTemplate",
  "keyAlgo": "RSA",
  "keyBits": "2048"
}'
curl --fail -H "Content-Type: application/json" \
  -H "$session_token" \
  --data "$data" \
  http://localhost:8080/template/create


# create a test certificate
data='{
  "commonName": "subdomain.example.com",
  "templateName": "testingTemplate",
  "timeToLive": 3600
}'
response=$(curl --fail -s -H "Content-Type: application/json" \
  -H "$session_token" \
  --data "$data" \
  http://localhost:8080/certificate/create)


# parse the result and get the certificate serial number
serialNumber=$(echo "$response" | jq -r .serialNumber)
certificateResponse=$(echo "$response" | jq -r .certificate)

response=$(curl --fail -s -H "Content-Type: application/json" \
  -H "$session_token" \
  http://localhost:8080/certificate/$serialNumber)

certificateReturned=$(echo "$response" | jq -r .certificate)

if [ "${certificateResponse}" != "${certificateReturned}" ]; then
  echo "ERROR: Certificate should match but does not!"
  return 1
fi

# revoke specific certificate
data=$(cat <<-END
{
  "serialNumber": "$serialNumber"
}
END
)
response=$(curl --fail -s -H "Content-Type: application/json" \
  -X POST \
  --data "$data" \
  -H "$session_token" \
  http://localhost:8080/certificate/revoke)


# certificate list
response=$(curl --fail -s -H "Content-Type: application/json" \
  -H "$session_token" \
  http://localhost:8080/certificates)
echo "All your certifiates: $response"


# Lets revoke all the certificates that exists
for serialNumber in $(echo "${response}" | jq '.["certificates"]' | jq -r -c '.[]'); do
    data="{\"serialNumber\": \"$serialNumber\"}"
	response=$(curl --fail -s -H "Content-Type: application/json" \
		-X POST \
		--data "$data" \
		-H "$session_token" \
		http://localhost:8080/certificate/revoke)
	echo "revoked $serialNumber and response was $response"
done

# Lets look at the CRL
response=$(curl --fail -s \
  http://localhost:8080/crl)
if [[ -z $response ]]; then
  echo "ERROR: CRL Should have content"
  return 1
fi

# LETS PURGE!
curl --fail -s -H "Content-Type: application/json" \
	-X POST \
	-H "$session_token" \
	http://localhost:8080/purge


# Lets get our CA Certificate
curl --fail -s \
	http://localhost:8080/ca/certificate

# Lets get the CA chain
# TODO CURRENTLY THIS IS RETURNING A 500
# response=$(curl --fail -s \
# 	http://localhost:8080/ca/chain)
# echo "CA CHAIN"
# echo "$response"


# Lets play with the templates
# list the templates
response=$(curl --fail -s \
	-H "$session_token" \
	http://localhost:8080/templates)

# parse first template name (Should be only)
templateName=$(echo "$response" | jq  '.["templates"]' | jq -r '.[0]')

# get a specific template
curl --fail -s \
	-H "$session_token" \
	"http://localhost:8080/template/$templateName"

# delete that same template we just examined
curl --fail -s \
	-H "$session_token" \
	-X "DELETE" \
	"http://localhost:8080/template/delete/$templateName"


# re-create same template so I can test manually
data='{
  "templateName": "testingTemplate",
  "keyAlgo": "RSA",
  "keyBits": "2048"
}'
curl --fail -H "Content-Type: application/json" \
  -H "$session_token" \
  --data "$data" \
  http://localhost:8080/template/create