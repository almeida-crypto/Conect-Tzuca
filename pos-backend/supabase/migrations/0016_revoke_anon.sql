-- 0016: segunda cerradura. Sin cuenta no se toca ninguna tabla aunque algún día una quede sin RLS.
-- (Hoy RLS ya lo frena todo; esto es por si una migración futura se equivoca.)

revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke all on sequences from anon;
