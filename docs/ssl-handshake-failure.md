# SSLV3 alert handshake failure (Cursor / VS Code)

## Symptom

You may see errors like:

```
SSLV3_ALERT_HANDSHAKE_FAILURE
```

Despite the name, this is a generic TLS handshake failure. It does not mean
SSLv3 is being used.

## Common causes

- TLS interception (corporate proxy, antivirus, or VPN).
- Missing or untrusted root/intermediate certificates.
- Misconfigured proxy settings in the app or environment.
- System clock out of sync.
- Old app build or OS TLS libraries.

## Quick fixes (most common first)

1. Try a different network (hotspot) and disable VPN/SSL inspection.
2. Verify system time is correct (auto time sync on).
3. Update Cursor / VS Code to the latest version.

## Proxy and TLS inspection checks

If you are on a corporate network:

1. Ensure the corporate root CA is installed in the OS trust store.
2. If a proxy is required, configure it explicitly:

   - Environment variables: `HTTPS_PROXY`, `HTTP_PROXY`, `NO_PROXY`
   - VS Code settings: `http.proxy`, `http.proxyStrictSSL`

   Keep `http.proxyStrictSSL` enabled unless you are testing. If you disable
   it to confirm a proxy issue, re-enable it immediately after.

## Validate the handshake outside the app

Replace `<host>` with the service you are connecting to (for example, the API
endpoint shown in logs).

```
openssl s_client -connect <host>:443 -servername <host>
curl -Iv https://<host>/
```

If these fail with a certificate or handshake error, the issue is in the
network/proxy/cert chain, not in the app.

## If it still fails

Collect and share:

- The exact error message and timestamp.
- Whether the issue reproduces on another network.
- The configured proxy settings (sanitized).
- Output of the `openssl` or `curl` commands above.
