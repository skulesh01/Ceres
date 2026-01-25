# Identity (LDAP) for “one password everywhere”

## Goal
Provide a single source of truth for credentials so that:
- Keycloak (web SSO) uses the same password as
- IMAP/SMTP (mail clients) and
- any other service that can do LDAP auth.

This is the closest equivalent to “как по LDAP”: one directory, one password, consistent password change.

## Current repo status (why this is needed)
- There is no LDAP/FreeIPA/OpenLDAP deployment or Keycloak LDAP federation in the current CERES manifests.
- Current `deployment/mailcow.yaml` is a minimal mail stack (postfix+dovecot+roundcube) without mailbox/user management and without LDAP auth configuration.

## Recommended architecture
- Deploy an LDAP directory (OpenLDAP initially; FreeIPA later if you need integrated CA/Kerberos).
- Configure Keycloak **User Federation (LDAP)**:
  - Users live in LDAP.
  - Keycloak reads users from LDAP and can write password changes back (WRITABLE).
- Configure the mail services (Dovecot/Postfix) to authenticate users against LDAP.

## Security principles
- Do NOT sync raw passwords through your own app.
- Do NOT store passwords in Git.
- Use TLS for LDAP (LDAPS/StartTLS) in production.
- Restrict LDAP network access (NetworkPolicy / firewall).

## Bootstrap (dev/internal)
1) Deploy OpenLDAP:

```bash
cd /opt/ceres/Ceres
bash scripts/setup-identity-openldap.sh
```

It will generate passwords unless provided via env:

```bash
LDAP_ADMIN_PASSWORD='...' LDAP_CONFIG_PASSWORD='...' bash scripts/setup-identity-openldap.sh
```

2) Configure Keycloak LDAP federation:

```bash
LDAP_ADMIN_PASSWORD='(from step 1 output)' bash scripts/setup-keycloak-ldap-federation.sh
```

## Next work (required to complete “one password for everything”)
1) Add TLS to LDAP and update Keycloak federation URL to `ldaps://...`.
2) Implement mailbox provisioning + LDAP-backed auth for IMAP/SMTP:
   - Either migrate to a mail stack that supports LDAP cleanly (Postfix+Dovecot configs as ConfigMaps),
   - Or rework the current mail deployment to load LDAP auth config (depends on image capabilities).
3) Update onboarding flow:
   - Create user in LDAP (not Keycloak DB),
   - Send “set password” / onboarding email,
   - Ensure webmail is reachable (Ingress + DNS + proper TLS).
