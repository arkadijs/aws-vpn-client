#!/bin/bash -e

# replace with your hostname
VPN_HOST="cvpn-endpoint-0ab4dec2ff2af2947.prod.clientvpn.us-east-2.amazonaws.com"
# path to the patched openvpn
OVPN_BIN="./openvpn.$(uname -s)_$(uname -m)"
# path to the configuration file
OVPN_CONF="vpn.conf"
PORT=443
PROTO=udp

wait_file() {
  local file="$1"; shift
  local wait_seconds="${1:-10}"; shift # 10 seconds as default timeout
  until test $((wait_seconds--)) -eq 0 -o -f "$file" ; do sleep 1; done
  ((++wait_seconds))
}

# create random hostname prefix for the vpn gw
RAND=$(openssl rand -hex 12)

# resolv manually hostname to IP, as we have to keep persistent ip address
SRV=$(dig a +short "${RAND}.${VPN_HOST}"|head -n1)

# cleanup
rm -f response.txt saml-response.txt

echo "Getting SAML redirect URL from the AUTH_FAILED response (host: ${SRV}:${PORT})"
$OVPN_BIN --config "${OVPN_CONF}" --verb 3 \
    --proto "$PROTO" --remote "${SRV}" "${PORT}" \
    --auth-user-pass <( printf "%s\n%s\n" "N/A" "ACS::35001" ) \
    2>&1 | tee response.txt

OVPN_OUT=$(grep AUTH_FAILED,CRV1 response.txt)

echo "Opening browser and wait for the response file..."
URL=$(echo "$OVPN_OUT" | grep -Eo 'https://.+')

case $(uname -s) in
    Linux*)     xdg-open "$URL";;
    Darwin*)    open "$URL";;
    *)          echo "Could not determine 'open' command for this OS"; exit 1;;
esac

wait_file "saml-response.txt" 100 || {
  echo "SAML Authentication time out"
  exit 1
}

# get SID from the reply
VPN_SID=$(echo "$OVPN_OUT" | awk -F : '{print $7}')

echo "Running OpenVPN with sudo. Enter password if requested"

# Finally OpenVPN with a SAML response we got
# Delete saml-response.txt after connect
sudo bash -c "$OVPN_BIN --config "${OVPN_CONF}" \
    --verb 3 --auth-nocache --inactive 3600 \
    --proto "$PROTO" --remote $SRV $PORT \
    --script-security 2 \
    --route-up '/bin/rm response.txt saml-response.txt' \
    --auth-user-pass <( printf \"%s\n%s\n\" \"N/A\" \"CRV1::${VPN_SID}::$(cat saml-response.txt)\" )"
