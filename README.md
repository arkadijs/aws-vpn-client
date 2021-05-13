Open two terminal windows (or tabs). Run `./samlserver` in one, then run `./aws-connect.sh` in another. Re-enter O365 password in the browser. The VPN should be up with 10/8 route setup to VPN gateway.

#### macOS users

Depending on your machine Security & Privacy settings and macOS version (10.15+), you may get an error _cannot be opened because the developer cannot be verified_. Please [read on](https://github.com/hashicorp/terraform/issues/23033#issuecomment-542302933) for a simple workaround.

Alternativelly, to set global preference to _Allow apps downloaded from: Anywhere_, execute:

    $ sudo spctl --master-disable

## aws-vpn-client

This is PoC to connect to the AWS Client VPN with OSS OpenVPN using SAML
authentication. Tested on macOS and Linux, should also work on other POSIX OS with a minor changes.

See [my blog post](https://smallhacks.wordpress.com/2020/07/08/aws-client-vpn-internals/) for the implementation details.

## Content of the repository

- [openvpn-v2.4.9-aws.patch](openvpn-v2.4.9-aws.patch) - patch required to build
AWS compatible OpenVPN v2.4.9, based on the
[AWS source code](https://amazon-source-code-downloads.s3.amazonaws.com/aws/clientvpn/osx-v1.2.5/openvpn-2.4.5-aws-2.tar.gz) (thanks to @heprotecbuthealsoattac) for the link.
- [server.go](server.go) - Go server to listed on http://127.0.0.1:35001 and save
SAML Post data to the file
- [aws-connect.sh](aws-connect.sh) - bash wrapper to run OpenVPN. It runs OpenVPN first time to get SAML Redirect and open browser and second time with actual SAML response

## How to use

1. Build patched openvpn version and put it to the folder with a script
1. Start HTTP server with `go run server.go`
1. Set VPN_HOST in the [aws-connect.sh](aws-connect.sh)
1. Replace CA section in the sample [vpn.conf](vpn.conf) with one from your AWS configuration
1. Finally run `aws-connect.sh` to connect to the AWS.

### Additional Steps

Inspect your ovpn config and remove the following lines if present
- `auth-user-pass` (we dont want to show user prompt)
- `auth-federate` (do not retry on failures)
- `auth-retry interact` (propietary AWS keyword)
- `remote` and `remote-random-hostname` (already handled in CLI and can cause conflicts with it)

## Todo

Better integrate SAML HTTP server with a script or rewrite everything on golang
