-- Deploy structs-pg:role-structs-webapp-20260826-oidc to pg
--
-- The webapp owns the entire OIDC provider lifecycle: it seeds the client
-- registry from deployment configuration, records in-flight authorization
-- requests, issues and consumes authorization codes, and revokes tokens.

BEGIN;

    GRANT SELECT, INSERT, UPDATE, DELETE
        ON structs.oidc_client,
           structs.oidc_authorization_request,
           structs.oidc_authorization_code,
           structs.oidc_access_token
        TO structs_webapp;

COMMIT;
