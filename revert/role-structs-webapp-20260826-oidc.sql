-- Revert structs-pg:role-structs-webapp-20260826-oidc from pg

BEGIN;

    REVOKE SELECT, INSERT, UPDATE, DELETE
        ON structs.oidc_client,
           structs.oidc_authorization_request,
           structs.oidc_authorization_code,
           structs.oidc_access_token
        FROM structs_webapp;

COMMIT;
