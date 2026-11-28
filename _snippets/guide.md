# Rotating an API key

Keys for the payments API last ninety days. This guide shows how to replace
one without dropping a single request.

## Before you start

You need the `ops` role in the admin console and a shell with the `payctl`
tool installed. Check your version first:

```sh
payctl version
```

Anything older than 3.2 cannot hold two active keys at once, so upgrade
before going further.

## Steps

1. Create the new key and give it a name you will recognise later:

   ```sh
   payctl keys create --name "checkout-2026-12"
   ```

2. Add the new key to the secret store next to the old one. Both stay
   valid while you deploy.
3. Deploy the services that call the API (checkout, refunds, and the
   nightly reconciler).
4. Watch the dashboard for an hour. Requests signed with the old key
   should fall to zero.
5. Revoke the old key:

   ```sh
   payctl keys revoke "checkout-2026-09"
   ```

If anything goes wrong before step 5, the old key still works, so roll the
deploy back and try again.
