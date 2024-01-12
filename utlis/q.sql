alter table playerrank 
add constraint playerrank_pk check(battingrank > 0 and bowlingrank > 0 and allrounderank > 0);

alter table teamrank
add constraint teamrank_pk check(odirank > 0 and t20irank > 0 and testrank > 0);

-- Create roles
--CREATE ROLE playermanager;
CREATE ROLE teammanager;
CREATE ROLE admin;
CREATE ROLE tournamentmanager;
CREATE ROLE datamanager;

-- Grant privileges to PlayerManager role

GRANT ALL PRIVILEGES ON TABLE player,batsman,bowler,playerrank TO playermanager;

-- Grant privileges to TeamsManager role
GRANT ALL PRIVILEGES ON TABLE captain,coach,wicketkeeper,team,teamrank TO teammanager;

-- Grant privileges to Admin role
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin;

-- Grant privileges to TournamentManager role
GRANT ALL PRIVILEGES ON TABLE tournament,match,umpire,scorecard TO tournamentmanager;

-- Create DataManager role
-- Grant INSERT permission on all tables
GRANT INSERT ON ALL TABLES IN SCHEMA public TO datamanager;
-- GRANT SEQUNCE PERMISSIONS
GRANT INSERT ON ALL SEQUENCES IN SCHEMA public TO datamanager;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin,playermanager,teammanager,tournamentmanager;

--check users
select usesysid as user_id,
       usename as username,
       usesuper as is_superuser,
       passwd as password_md5,
       valuntil as password_expiration
from pg_shadow
order by usename;
-- Grant login privilege
CREATE OR REPLACE FUNCTION user_creation()
RETURNS TRIGGER AS $$
BEGIN
    EXECUTE 'CREATE USER ' || quote_ident(NEW.username) || ' WITH PASSWORD ' || quote_literal(NEW.password);
	EXECUTE 'GRANT CONNECT ON DATABASE "DBMS Cricket" TO ' ||quote_ident(NEW.username) ;
    EXECUTE 'GRANT USAGE ON SCHEMA public TO ' || quote_ident(NEW.username);
   EXECUTE 'GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO ' || quote_ident(NEW.username);
  IF NEW.userrole = 'admin' THEN
    EXECUTE 'ALTER USER ' || quote_ident(NEW.username) || ' SET ROLE admin';
    EXECUTE 'GRANT admin to ' || quote_ident(NEW.username);
	ELSIF NEW.userrole = 'playermanager' THEN
	EXECUTE 'ALTER USER ' || quote_ident(NEW.username) || ' SET ROLE playermanager';
    EXECUTE 'GRANT playermanager to ' || quote_ident(NEW.username);
	ELSIF NEW.userrole = 'teammanager' THEN
	EXECUTE 'ALTER USER ' || quote_ident(NEW.username) || ' SET ROLE teammanager';
    EXECUTE 'GRANT teammanager to ' || quote_ident(NEW.username);
	ELSIF NEW.userrole = 'datamanager' THEN
	EXECUTE 'ALTER USER ' || quote_ident(NEW.username) || ' SET ROLE datamanager';
    EXECUTE 'GRANT datamanager to ' || quote_ident(NEW.username);
	ELSIF NEW.userrole = 'tournamentmanager' THEN
	EXECUTE 'ALTER USER ' || quote_ident(NEW.username) || ' SET ROLE tournamentmanager';
    EXECUTE 'GRANT tournamentmanager to ' || quote_ident(NEW.username);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER user_creation_trigger
BEFORE INSERT ON users
FOR EACH ROW
EXECUTE FUNCTION user_creation();
--create triger to set password=hasehd_password after insert
CREATE OR REPLACE FUNCTION set_password()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE users SET password=NEW.hashed_password WHERE username = NEW.username;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


drop trigger if exists set_password_trigger on users;

create trigger set_password_trigger
after insert on users
for each row
execute procedure set_password();


DROP TRIGGER IF EXISTS user_creation_trigger ON users;
DROP TRIGGER IF EXISTS user_deletion_trigger ON users;

SELECT * FROM pg_user WHERE usename = 'abdrehman';


CREATE OR REPLACE FUNCTION user_deletion()
RETURNS TRIGGER AS $$
BEGIN
    EXECUTE 'REVOKE CONNECT ON DATABASE "DBMS Cricket" FROM ' ||quote_ident(OLD.username) ;
    EXECUTE 'ALTER USER ' || quote_ident(OLD.username) || ' SET ROLE NONE';
    EXECUTE 'REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM ' || quote_ident(OLD.username);
    EXECUTE 'REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM ' || quote_ident(OLD.username);
    EXECUTE 'REVOKE USAGE ON SCHEMA public FROM ' || quote_ident(OLD.username);
    EXECUTE 'DROP USER ' || quote_ident(OLD.username);
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_deletion_trigger
BEFORE DELETE ON users
FOR EACH ROW
EXECUTE FUNCTION user_deletion();

SELECT grantor,
       grantee,
       table_name,
       privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'tournamentmanager';



--psql -U postgres -h localhost -d "checking" -f "C:\Users\Engr. Ghulam Abbas\Downloads\backup_file(10).sql"
-- psql -U abbas -d "DBMS Cricket" -h localhost -p 5432 
-- "SELECT * FROM team;"
