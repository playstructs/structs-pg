-- Deploy structs-pg:function-unique-random to pg

BEGIN;

    -- The following code is adapted from...
    -- PostgreSQL unique random defaults, by Derek Sivers. Article: https://sive.rs/rand1

    create or replace function structs.gen_random_bytes(int) returns bytea as '$libdir/pgcrypto', 'pg_random_bytes' language c strict;

    create or replace function structs.random_human_string(len int) returns text as $$
    declare
        chars text[] = '{2,3,4,5,6,7,8,9,A,B,C,D,E,F,G,H,K,L,M,N,P,Q,R,S,T,U,V,X,Y,Z}';
        result text = '';
        i int = 0;
        rand bytea;
    begin
        -- generate secure random bytes and convert them to a string of chars.
        rand = structs.gen_random_bytes($1);
        for i in 0..len-1 loop
                -- rand indexing is zero-based, chars is 1-based.
                result = result || chars[1 + (get_byte(rand, i) % array_length(chars, 1))];
            end loop;
        return result;
    end;
    $$ language plpgsql;

    -- return random string confirmed to not exist in given tablename.colname
    create or replace function structs.unique_human_random(len int, _table text, _col text) returns text as $$
    declare
        result text;
        numrows int;
    begin
        result = structs.random_human_string(len);
        loop
            execute format('select 1 from structs.%I where %I = %L', _table, _col, result);
            get diagnostics numrows = row_count;
            if numrows = 0 then
                return result;
            end if;
            result = structs.random_human_string(len);
        end loop;
    end;
    $$ language plpgsql;

COMMIT;
