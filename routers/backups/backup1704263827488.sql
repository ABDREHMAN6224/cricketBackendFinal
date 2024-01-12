--
-- PostgreSQL database dump
--

-- Dumped from database version 15.5
-- Dumped by pg_dump version 16.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: match_creation(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.match_creation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if exists(select * from match where date=NEW.date and ((team1id=new.team1id and team2id=new.team2id)or(team1id=new.team2id and team2id=new.team1id))) then
        raise exception 'Match already exists';
    end if;
    if exists(select * from match where date=NEW.date and (team1id=new.team1id or team2id=new.team1id)) then
        raise exception 'Team already has a match on this date';
    end if;
    if exists(select * from match where date=NEW.date and umpire=new.umpire) then
        raise exception 'Umpire already has a match on this date';
    end if;
    if exists(select * from match where date=NEW.date and locationid=new.locationid) then
        raise exception 'Stadium already has a match on this date';
    end if;
    --check if team1id and team2id are not same
    if new.team1id=new.team2id then
        raise exception 'Team1id and Team2id cannot be same';
    end if;
    --check that date cannot be in future
    if new.date>current_date then
        raise exception 'Date cannot be in future';
    end if;
    --check if both teams have 11 players
    if (select count(*) from player where teamid=new.team1id)=11 and (select count(*) from player where teamid=new.team2id)=11 then
        raise exception 'Both teams do not have 11 players';
    end if;
    return new;
end;
$$;


ALTER FUNCTION public.match_creation() OWNER TO postgres;

--
-- Name: match_delete(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.match_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    --check if match data is in scorecard, if yes then delete from scorecard otherwise just delete match
    if exists(select * from scorecard where matchid=old.matchid) then
        delete from scorecard where matchid=old.matchid;
    end if;
	    return old;

end;
$$;


ALTER FUNCTION public.match_delete() OWNER TO postgres;

--
-- Name: match_insertion(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.match_insertion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    update umpire set nomatches=nomatches+1 where umpireid=new.umpire;
    --if winner is team1id increase totalwins of team1id and icrease totallosses of team2id
    if new.winnerteam=new.team1id then
        update team set totalwins=totalwins+1 where teamid=new.team1id;
        update team set totallosses=totallosses+1 where teamid=new.team2id;
        --increase matches as captain for captain and totalwins
        update captain set matchesascaptain=matchesascaptain+1,totalwins=totalwins+1 where playerid=(select captainid from team where teamid=new.team1id);
        --increase matches as captain for team2
        update captain set matchesascaptain=matchesascaptain+1 where playerid=(select captainid from team where teamid=new.team2id);       
    --if winner is team2id increase totalwins of team2id
    elsif new.winnerteam=new.team2id then
        update team set totalwins=totalwins+1 where teamid=new.team2id;
        update team set totallosses=totallosses+1 where teamid=new.team1id;
        --increase matches as captain for captain and totalwins
        update captain set matchesascaptain=matchesascaptain+1,totalwins=totalwins+1 where playerid=(select captainid from team where teamid=new.team2id);
        --increase matches as captain for team1
        update captain set matchesascaptain=matchesascaptain+1 where playerid=(select captainid from team where teamid=new.team1id);
    --if match is a draw increase draws of both teams
    elsif new.winnerteam is null then
        update team set draws=draws+1 where teamid=new.team1id;
        update team set draws=draws+1 where teamid=new.team2id;
        --increase matches as captain for captain
        update captain set matchesascaptain=matchesascaptain+1 where playerid=(select captainid from team where teamid=new.team1id);
        --increase matches as captain for captain
        update captain set matchesascaptain=matchesascaptain+1 where playerid=(select captainid from team where teamid=new.team2id);
    end if;
    return new;
end;
$$;


ALTER FUNCTION public.match_insertion() OWNER TO postgres;

--
-- Name: player_deletion(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.player_deletion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    delete from playerrank where playerid=old.playerid;
    update playerrank set battingrank=battingrank-1 where battingrank>(select battingrank from playerrank where playerid=old.playerid);
    update playerrank set bowlingrank=bowlingrank-1 where bowlingrank>(select bowlingrank from playerrank where playerid=old.playerid);
    update playerrank set allrounderrank=allrounderrank-1 where allrounderrank>(select allrounderrank from playerrank where playerid=old.playerid);
    --delete from scorecard
    delete from scorecard where playerid=old.playerid;
    --set captainid to null if player is captain
    update team set captainid=null where captainid=old.playerid;
    --set wicketkeeperid to null if player is wicketkeeper
    update team set wicketkeeperid=null where wicketkeeperid=old.playerid;
    --delete from captain table and wicketkeeper table
    delete from captain where playerid=old.playerid;
    delete from wicketkeeper where playerid=old.playerid;
    --delte from batsman or bowler and from both if player is allrounder based on type
    if lower(old.playertype)='batsman' then
        delete from batsman where playerid=old.playerid;
    elsif lower(old.playertype)='bowler' then
        delete from bowler where playerid=old.playerid;
    elsif lower(old.playertype)='allrounder' then
        delete from batsman where playerid=old.playerid;
        delete from bowler where playerid=old.playerid;
    end if;


    return old;
end;
$$;


ALTER FUNCTION public.player_deletion() OWNER TO postgres;

--
-- Name: player_insertion(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.player_insertion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    --check if max rank is null than assign 1 else assign max rank+1
    if (select max(battingrank) from playerrank) is null then
        insert into playerrank values(new.playerid,1,1,1);
    else
        insert into playerrank values(new.playerid,(select max(battingrank) from playerrank)+1,(select max(bowlingrank) from playerrank)+1,(select max(allrounderrank) from playerrank)+1);
    end if;
    --check if team has already 11 players only if teamid is not null
    if new.teamid is not null then
        if (select count(*) from player where teamid=new.teamid)=11 then
            raise exception 'Team already has 11 players';
        end if;
    end if;
    --if team id is not null then check that it has max 5 batsman, 5 bowlers and 5 allrounder
    if new.teamid is not null then
        if (select count(*) from player where teamid=new.teamid and lower(playertype)='batsman')>=5 then
            raise exception 'Team already has 5 batsman';
        end if;
        if (select count(*) from player where teamid=new.teamid and lower(playertype)='bowler')>=5 then
            raise exception 'Team already has 5 bowlers';
        end if;
        if (select count(*) from player where teamid=new.teamid and lower(playertype)='allrounder')>=5 then
            raise exception 'Team already has 5 allrounders';
        end if;
    end if;
    --if playertype is batsman then insert into batsman table(playerid,0,0,0,'Right',0,0)
    if lower(new.playertype)='batsman' then
        insert into batsman values(new.playerid,0,0,0,'Right',0,0);
    --if playertype is bowler then insert into bowler table(playerid,0,0,0,'Right',0,0)
    elsif lower(new.playertype)='bowler' then
        insert into bowler values(new.playerid,0,'Left','Leg-Spin',0,0,0,0,0,0);
    --if playertype is allrounder then insert into batsman table(playerid,0,0,0,'Right',0,0) and insert into bowler table(playerid,0,0,0,'Right',0,0)
    elsif lower(new.playertype)='allrounder' then
        insert into batsman values(new.playerid,0,0,0,'Right',0,0);
        insert into bowler values(new.playerid,0,'Left','Leg-Spin',0,0,0,0,0,0);
    end if;
    return new;
end;
$$;


ALTER FUNCTION public.player_insertion() OWNER TO postgres;

--
-- Name: player_rank_insertion(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.player_rank_insertion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    --check if rank jump is not greater tahn 3 compared to previous rank
    if new.battingrank is not null then
        if new.battingrank>(select battingrank from playerrank where playerid=new.playerid)+3 then
            raise exception 'Rank cannot be greater than previous rank+3';
        end if;
    end if;
    if new.bowlingrank is not null then
        if new.bowlingrank>(select bowlingrank from playerrank where playerid=new.playerid)+3 then
            raise exception 'Rank cannot be greater than previous rank+3';
        end if;
    end if;
    if new.allrounderrank is not null then
        if new.allrounderrank>(select allrounderrank from playerrank where playerid=new.playerid)+3 then
            raise exception 'Rank cannot be greater than previous rank+3';
        end if;
    end if;
    if new.battingrank is not null then
        if new.battingrank>(select max(battingrank) from playerrank)+1 then
            raise exception 'Rank cannot be greater than max rank+1';
        end if;
    end if;
    if new.bowlingrank is not null then
        if new.bowlingrank>(select max(bowlingrank) from playerrank)+1 then
            raise exception 'Rank cannot be greater than max rank+1';
        end if;
    end if;
    if new.allrounderrank is not null then
        if new.allrounderrank>(select max(allrounderrank) from playerrank)+1 then
            raise exception 'Rank cannot be greater than max rank+1';
        end if;
    end if;
    return new;
end;
$$;


ALTER FUNCTION public.player_rank_insertion() OWNER TO postgres;

--
-- Name: player_rank_updation(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.player_rank_updation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
--update ranks of other players, like if battingrank of player is updated then update battingrank of other players
begin
    if new.battingrank is not null then
        if new.battingrank<>old.battingrank then
            update playerrank set battingrank=battingrank+1 where battingrank>=new.battingrank and battingrank<old.battingrank and playerid!=old.playerid;
            update playerrank set battingrank=battingrank-1 where battingrank<=new.battingrank and battingrank>old.battingrank and playerid!=old.playerid;
        end if;
    elsif new.bowlingrank is not null then

        if new.bowlingrank<>old.bowlingrank then
            update playerrank set bowlingrank=bowlingrank+1 where bowlingrank>=new.bowlingrank and bowlingrank<old.bowlingrank and playerid!=old.playerid;
            update playerrank set bowlingrank=bowlingrank-1 where bowlingrank<=new.bowlingrank and bowlingrank>old.bowlingrank and playerid!=old.playerid;
        end if;
    elsif new.allrounderrank is not null then
    
            if new.allrounderrank<>old.allrounderrank then
                update playerrank set allrounderrank=allrounderrank+1 where allrounderrank>=new.allrounderrank and allrounderrank<old.allrounderrank and playerid!=old.playerid;
                update playerrank set allrounderrank=allrounderrank-1 where allrounderrank<=new.allrounderrank and allrounderrank>old.allrounderrank and playerid!=old.playerid;
            end if;
        end if; 
        
    return new;
end;
$$;


ALTER FUNCTION public.player_rank_updation() OWNER TO postgres;

--
-- Name: scorecard_insertion(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.scorecard_insertion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    --after insertion check from player table using playerid and if its batsman or allrounder then update batsman table with noruns,nosixes,nofours,ballsfaced,totalinningsbatted
    if exists(select * from player where playerid=new.playerid and (lower(playertype)='batsman' or lower(playertype)='allrounder')) then
        update batsman set noruns=noruns+new.noruns, nosixes=nosixes+new.nosixes, nofours=nofours+new.nofours, ballsfaced=ballsfaced+new.noballsfaced, totalinningsbatted=totalinningsbatted+1 where playerid=new.playerid;
    end if;
    --after insertion check from player table using playerid and if its bowler or allrounder then update bowler table with nowickets,oversbowled,maidenovers,runsconceded,totalinningsbowled,noballsbowled
    if exists(select * from player where playerid=new.playerid and (lower(playertype)='bowler' or lower(playertype)='allrounder')) then
        update bowler set nowickets=nowickets+new.nowickets, oversbowled=oversbowled+new.oversbowled, maidenovers=maidenovers+new.maidenovers, runsconceded=runsconceded+new.runsconceded, totalinningsbowled=totalinningsbowled+1,noballsbowled=noballsbowled+new.noballs where playerid=new.playerid;
    end if;
   
    return new;
end;
$$;


ALTER FUNCTION public.scorecard_insertion() OWNER TO postgres;

--
-- Name: set_password(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_password() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE users SET password=NEW.hashed_password WHERE username = NEW.username;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_password() OWNER TO postgres;

--
-- Name: team_after_insertion(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.team_after_insertion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    --update teamid for captain and wicketkeeper
    update player set teamid=new.teamid where playerid=new.captainid;
    update player set teamid=new.teamid where playerid=new.wicketkeeperid;
    --assign maximum rank to team in teamrank table
    --check if max rank is null than assign 1 else assign max rank+1
    if (select max(t20irank) from teamrank) is null then
        insert into teamrank values(new.teamid,1,1,1);
    else
    insert into teamrank values(new.teamid,(select max(t20irank) from teamrank)+1,(select max(odirank) from teamrank)+1,(select max(testrank) from teamrank)+1);
    end if;
    return new;
end;
$$;


ALTER FUNCTION public.team_after_insertion() OWNER TO postgres;

--
-- Name: team_captainid_check(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.team_captainid_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if exists(select * from team where captainid=new.captainid and teamid!=new.teamid) then
        raise exception 'Captain already assigned to another team';
    end if;
    return new;
end;
$$;


ALTER FUNCTION public.team_captainid_check() OWNER TO postgres;

--
-- Name: team_coachid_check(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.team_coachid_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if exists(select * from team where coachid=new.coachid and teamid!=new.teamid) then
        raise exception 'Coach already assigned to another team';
    end if;
    return new;
end;
$$;


ALTER FUNCTION public.team_coachid_check() OWNER TO postgres;

--
-- Name: team_deletion(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.team_deletion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    --set players teamid to null
    update player set teamid=null where teamid=old.teamid;
    --delete from match
    delete from match where team1id=old.teamid or team2id=old.teamid;
    --delete from teamrank
    delete from teamrank where teamid=old.teamid;
    --update teamrank
    update teamrank set t20irank=t20irank-1 where t20irank>(select t20irank from teamrank where teamid=old.teamid);
    update teamrank set odirank=odirank-1 where odirank>(select odirank from teamrank where teamid=old.teamid);
    update teamrank set testrank=testrank-1 where testrank>(select testrank from teamrank where teamid=old.teamid);
    return old;
end;
$$;


ALTER FUNCTION public.team_deletion() OWNER TO postgres;

--
-- Name: team_insertion(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.team_insertion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    --check if team has already 1 coach
    if (select count(*) from team where coachid=new.coachid and teamid!=new.teamid)>0 then
        raise exception 'Coach already assigned to another team';
    end if;
    --check if team has already 1 captain
    if (select count(*) from team where captainid=new.captainid and teamid!=new.teamid)>0 then
        raise exception 'Captain already assigned to another team';
    end if;
    --check if team has already 1 wicketkeeper
    if (select count(*) from team where wicketkeeperid=new.wicketkeeperid and teamid!=new.teamid)>0 then
        raise exception 'Wicketkeeper already assigned to another team';
    end if;
    
    return new;
end;
$$;


ALTER FUNCTION public.team_insertion() OWNER TO postgres;

--
-- Name: team_rank_insertion(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.team_rank_insertion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    --check if rank jump is not greater tahn 3 compared to previous rank
    if new.t20irank is not null then
        if new.t20irank>(select t20irank from teamrank where teamid=new.teamid)+3 then
            raise exception 'Rank cannot be greater than previous rank+3';
        end if;
    end if;
    if new.odirank is not null then
        if new.odirank>(select odirank from teamrank where teamid=new.teamid)+3 then
            raise exception 'Rank cannot be greater than previous rank+3';
        end if;
    end if;
    if new.testrank is not null then
        if new.testrank>(select testrank from teamrank where teamid=new.teamid)+3 then
            raise exception 'Rank cannot be greater than previous rank+3';
        end if;
    end if;
    if new.t20irank is not null then
        if new.t20irank>(select max(t20irank) from teamrank)+1 then
            raise exception 'Rank cannot be greater than max rank+1';
        end if;
    end if;
    if new.odirank is not null then
        if new.odirank>(select max(odirank) from teamrank)+1 then
            raise exception 'Rank cannot be greater than max rank+1';
        end if;
    end if;
    if new.testrank is not null then
        if new.testrank>(select max(testrank) from teamrank)+1 then
            raise exception 'Rank cannot be greater than max rank+1';
        end if;
    end if;
    return new;
end;
$$;


ALTER FUNCTION public.team_rank_insertion() OWNER TO postgres;

--
-- Name: team_rank_updation(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.team_rank_updation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
--update ranks of other teams, like if teamrank of team is updated then update teamrank of other teams ranks are t20irank,odirank,testrank  only update if rnk has changed
begin
      if new.t20irank is not null then
            if new.t20irank<>old.t20irank then
                update teamrank set t20irank=t20irank+1 where t20irank>=new.t20irank and t20irank<old.t20irank and teamid!=old.teamid;
                update teamrank set t20irank=t20irank-1 where t20irank<=new.t20irank and t20irank>old.t20irank and teamid!=old.teamid;
            end if;
        elsif new.odirank is not null then
            if new.odirank<>old.odirank then
                update teamrank set odirank=odirank+1 where odirank>=new.odirank and odirank<old.odirank and teamid!=old.teamid;
                update teamrank set odirank=odirank-1 where odirank<=new.odirank and odirank>old.odirank and teamid!=old.teamid;
            end if;
        elsif new.testrank is not null then

            if new.testrank<>old.testrank then
                update teamrank set testrank=testrank+1 where testrank>=new.testrank and testrank<old.testrank and teamid!=old.teamid;
                update teamrank set testrank=testrank-1 where testrank<=new.testrank and testrank>old.testrank and teamid!=old.teamid;
            end if;
        end if;

    return new;
end;
$$;


ALTER FUNCTION public.team_rank_updation() OWNER TO postgres;

--
-- Name: team_wicketkeeperid_check(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.team_wicketkeeperid_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if exists(select * from team where wicketkeeperid=new.wicketkeeperid and teamid!=new.teamid) then
        raise exception 'Wicketkeeper already assigned to another team';
    end if;
    return new;
end;
$$;


ALTER FUNCTION public.team_wicketkeeperid_check() OWNER TO postgres;

--
-- Name: tournament_deletion(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.tournament_deletion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    delete from match where tournamentid=old.tournamentid;
    return old;
end;
$$;


ALTER FUNCTION public.tournament_deletion() OWNER TO postgres;

--
-- Name: updateplayerrank(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.updateplayerrank() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        begin
        if new.battingrank != old.battingrank then
            if new.battingrank > old.battingrank then
                update playerrank set battingrank = battingrank + 1 where battingrank >= new.battingrank and battingrank < old.battingrank and playerid != old.playerid;
            elsif new.battingrank < old.battingrank then
                update playerrank set battingrank = battingrank - 1 where battingrank <= new.battingrank and battingrank > old.battingrank and playerid != old.playerid;
            end if;
        end if;
        if new.bowlingrank != old.bowlingrank then
            if new.bowlingrank > old.bowlingrank then
                update playerrank set bowlingrank = bowlingrank + 1 where bowlingrank >= new.bowlingrank and bowlingrank < old.bowlingrank and playerid != old.playerid;
            elsif new.bowlingrank < old.bowlingrank then
                update playerrank set bowlingrank = bowlingrank - 1 where bowlingrank <= new.bowlingrank and bowlingrank > old.bowlingrank and playerid != old.playerid;
            end if;
        end if;
        if new.allrounderrank != old.allrounderrank then
            if new.allrounderrank > old.allrounderrank then
                update playerrank set allrounderrank = allrounderrank + 1 where allrounderrank >= new.allrounderrank and allrounderrank < old.allrounderrank and playerid != old.playerid;
            elsif new.allrounderrank < old.allrounderrank then
                update playerrank set allrounderrank = allrounderrank - 1 where allrounderrank <= new.allrounderrank and allrounderrank > old.allrounderrank and playerid != old.playerid;
            end if;
        end if;
        return new;
        end;
        $$;


ALTER FUNCTION public.updateplayerrank() OWNER TO postgres;

--
-- Name: user_creation(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.user_creation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.user_creation() OWNER TO postgres;

--
-- Name: user_deletion(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.user_deletion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    EXECUTE 'REVOKE CONNECT ON DATABASE "DBMS Cricket" FROM ' ||quote_ident(OLD.username) ;
    EXECUTE 'ALTER USER ' || quote_ident(OLD.username) || ' SET ROLE NONE';
    EXECUTE 'REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM ' || quote_ident(OLD.username);
    EXECUTE 'REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM ' || quote_ident(OLD.username);
	    EXECUTE 'REVOKE USAGE ON SCHEMA public FROM ' || quote_ident(OLD.username);
    EXECUTE 'DROP USER ' || quote_ident(OLD.username);
  RETURN OLD;
END;
$$;


ALTER FUNCTION public.user_deletion() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: batsman; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.batsman (
    playerid integer NOT NULL,
    nosixes integer NOT NULL,
    nofours integer NOT NULL,
    noruns integer NOT NULL,
    bathand character varying(256),
    ballsfaced integer,
    totalinningsbatted integer,
    CONSTRAINT batsman_batand_check CHECK ((lower((bathand)::text) = ANY (ARRAY['left'::text, 'right'::text])))
);


ALTER TABLE public.batsman OWNER TO postgres;

--
-- Name: bowler; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bowler (
    playerid integer NOT NULL,
    nowickets integer NOT NULL,
    bowlhand character varying(256),
    bowltype character varying(256),
    oversbowled integer,
    maidenovers integer,
    runsconceded integer,
    totalinningsbowled integer,
    dotballs integer,
    noballsbowled integer,
    CONSTRAINT bowler_bowlhand_check CHECK ((lower((bowlhand)::text) = ANY (ARRAY['left'::text, 'right'::text]))),
    CONSTRAINT bowler_bowlype_check CHECK ((lower((bowltype)::text) = ANY (ARRAY['fast'::text, 'medium'::text, 'leg-spin'::text, 'off-spin'::text])))
);


ALTER TABLE public.bowler OWNER TO postgres;

--
-- Name: player; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.player (
    playerid integer NOT NULL,
    playername character varying(256) NOT NULL,
    dob date NOT NULL,
    teamid integer,
    totalt20i integer NOT NULL,
    totalodi integer NOT NULL,
    totaltest integer NOT NULL,
    playertype character varying(256),
    playerstatus character varying(256),
    playerpicpath character varying(255),
    countryid integer,
    CONSTRAINT player_status_check CHECK ((lower((playerstatus)::text) = ANY (ARRAY['active'::text, 'retired'::text]))),
    CONSTRAINT player_type_check CHECK ((lower((playertype)::text) = ANY (ARRAY['batsman'::text, 'bowler'::text, 'allrounder'::text])))
);


ALTER TABLE public.player OWNER TO postgres;

--
-- Name: allrounder_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.allrounder_view AS
 SELECT player.playername,
    batsman.noruns,
    batsman.nosixes,
    batsman.nofours,
    batsman.ballsfaced,
    batsman.totalinningsbatted,
    bowler.nowickets,
    bowler.oversbowled,
    bowler.maidenovers,
    bowler.runsconceded,
    bowler.totalinningsbowled,
    bowler.noballsbowled
   FROM ((public.batsman
     JOIN public.bowler USING (playerid))
     JOIN public.player USING (playerid));


ALTER VIEW public.allrounder_view OWNER TO postgres;

--
-- Name: batsman_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.batsman_view AS
 SELECT player.playername,
    batsman.noruns,
    batsman.nosixes,
    batsman.nofours,
    batsman.ballsfaced,
    batsman.totalinningsbatted
   FROM (public.batsman
     JOIN public.player USING (playerid));


ALTER VIEW public.batsman_view OWNER TO postgres;

--
-- Name: bowler_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.bowler_view AS
 SELECT player.playername,
    bowler.nowickets,
    bowler.oversbowled,
    bowler.maidenovers,
    bowler.runsconceded,
    bowler.totalinningsbowled,
    bowler.noballsbowled
   FROM (public.bowler
     JOIN public.player USING (playerid));


ALTER VIEW public.bowler_view OWNER TO postgres;

--
-- Name: captain; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.captain (
    playerid integer NOT NULL,
    matchesascaptain integer,
    totalwins integer
);


ALTER TABLE public.captain OWNER TO postgres;

--
-- Name: captain_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.captain_view AS
 SELECT player.playername,
    captain.matchesascaptain,
    captain.totalwins
   FROM (public.captain
     JOIN public.player USING (playerid));


ALTER VIEW public.captain_view OWNER TO postgres;

--
-- Name: coach; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.coach (
    coachname character varying(30) NOT NULL,
    picture character varying(255),
    coachid integer NOT NULL
);


ALTER TABLE public.coach OWNER TO postgres;

--
-- Name: coach_coachid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.coach_coachid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.coach_coachid_seq OWNER TO postgres;

--
-- Name: coach_coachid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.coach_coachid_seq OWNED BY public.coach.coachid;


--
-- Name: team; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.team (
    teamid integer NOT NULL,
    teamname character varying(256) NOT NULL,
    coachid integer,
    captainid integer,
    teampicpath character varying(255),
    totalwins integer,
    totallosses integer,
    draws integer,
    wicketkeeperid integer
);


ALTER TABLE public.team OWNER TO postgres;

--
-- Name: coach_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.coach_view AS
 SELECT coach.coachname,
    team.teamname
   FROM (public.coach
     JOIN public.team USING (coachid));


ALTER VIEW public.coach_view OWNER TO postgres;

--
-- Name: country; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.country (
    countryid integer NOT NULL,
    country character varying(50) NOT NULL
);


ALTER TABLE public.country OWNER TO postgres;

--
-- Name: country_countryid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.country ALTER COLUMN countryid ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.country_countryid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 99999
    CACHE 1
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    userid integer NOT NULL,
    username character varying(256),
    userpicpath character varying(256) DEFAULT 'https://media.istockphoto.com/id/1337144146/vector/default-avatar-profile-icon-vector.jpg?s=612x612&w=0&k=20&c=BIbFwuv7FxTWvh5S3vB6bkT0Qv8Vn8N5Ffseq84ClGI='::character varying,
    userrole character varying(256),
    password character varying(256),
    datejoined date,
    hashed_password character varying(256),
    CONSTRAINT role_check CHECK ((lower((userrole)::text) = ANY (ARRAY['playermanager'::text, 'admin'::text, 'teammanager'::text, 'tournamentmanager'::text, 'datamanager'::text])))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: db_user; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.db_user AS
 SELECT users.userid,
    users.username,
    users.userrole,
    users.userpicpath,
    users.datejoined
   FROM public.users;


ALTER VIEW public.db_user OWNER TO postgres;

--
-- Name: location; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.location (
    locationid integer NOT NULL,
    location character varying(256) NOT NULL
);


ALTER TABLE public.location OWNER TO postgres;

--
-- Name: location_locationid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.location ALTER COLUMN locationid ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.location_locationid_seq
    START WITH 22
    INCREMENT BY 1
    MINVALUE 22
    MAXVALUE 99999
    CACHE 1
);


--
-- Name: match; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.match (
    matchid integer NOT NULL,
    date timestamp without time zone NOT NULL,
    tournamentid integer,
    team1id integer,
    team2id integer,
    winnerteam integer,
    umpire integer,
    locationid integer,
    matchtype character varying(255),
    CONSTRAINT match_matchtype_check CHECK ((lower((matchtype)::text) = ANY (ARRAY['odi'::text, 't20'::text, 'test'::text])))
);


ALTER TABLE public.match OWNER TO postgres;

--
-- Name: match_matchid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.match ALTER COLUMN matchid ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.match_matchid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 9999
    CACHE 1
);


--
-- Name: umpire; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.umpire (
    umpirename character varying(255),
    nomatches integer NOT NULL,
    umpirepicpath character varying(256),
    countryid integer,
    umpireid integer NOT NULL
);


ALTER TABLE public.umpire OWNER TO postgres;

--
-- Name: match_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.match_view AS
 SELECT match.matchid,
    team1.teamname AS team1,
    team2.teamname AS team2,
    match.date,
    location.location,
    umpire.umpirename,
    winner.teamname AS winner
   FROM (((((public.match
     JOIN public.team team1 ON ((team1.teamid = match.team1id)))
     JOIN public.team team2 ON ((team2.teamid = match.team2id)))
     JOIN public.location ON ((location.locationid = match.locationid)))
     JOIN public.umpire ON ((umpire.umpireid = match.umpire)))
     JOIN public.team winner ON ((winner.teamid = match.winnerteam)));


ALTER VIEW public.match_view OWNER TO postgres;

--
-- Name: player_playerid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.player ALTER COLUMN playerid ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.player_playerid_seq
    START WITH 20
    INCREMENT BY 1
    MINVALUE 20
    NO MAXVALUE
    CACHE 1
);


--
-- Name: playerrank; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.playerrank (
    playerid integer NOT NULL,
    battingrank integer DEFAULT 0,
    bowlingrank integer DEFAULT 0,
    allrounderrank integer DEFAULT 0,
    CONSTRAINT playerrank_pk CHECK (((battingrank > 0) AND (bowlingrank > 0) AND (allrounderrank > 0)))
);


ALTER TABLE public.playerrank OWNER TO postgres;

--
-- Name: player_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.player_view AS
 SELECT player.playername,
    player.playertype,
    team.teamname,
    playerrank.battingrank,
    playerrank.bowlingrank,
    playerrank.allrounderrank,
    batsman.noruns,
    batsman.nosixes,
    batsman.nofours,
    batsman.ballsfaced,
    batsman.totalinningsbatted,
    bowler.nowickets,
    bowler.oversbowled,
    bowler.maidenovers,
    bowler.runsconceded,
    bowler.totalinningsbowled,
    bowler.noballsbowled
   FROM ((((public.player
     JOIN public.team USING (teamid))
     JOIN public.playerrank USING (playerid))
     LEFT JOIN public.batsman USING (playerid))
     LEFT JOIN public.bowler USING (playerid));


ALTER VIEW public.player_view OWNER TO postgres;

--
-- Name: playerrank_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.playerrank_view AS
 SELECT player.playername,
    playerrank.battingrank,
    playerrank.bowlingrank,
    playerrank.allrounderrank
   FROM (public.playerrank
     JOIN public.player USING (playerid));


ALTER VIEW public.playerrank_view OWNER TO postgres;

--
-- Name: scorecard; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.scorecard (
    matchid integer NOT NULL,
    playerid integer NOT NULL,
    noruns integer,
    nosixes integer,
    nofours integer,
    noballsfaced integer,
    nowickets integer,
    oversbowled integer,
    maidenovers integer,
    runsconceded integer,
    extras integer,
    noballs integer
);


ALTER TABLE public.scorecard OWNER TO postgres;

--
-- Name: scorecard_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.scorecard_view AS
 SELECT scorecard.matchid,
    player.playername,
    scorecard.noruns,
    scorecard.nosixes,
    scorecard.nofours,
    scorecard.noballsfaced,
    scorecard.nowickets,
    scorecard.oversbowled,
    scorecard.maidenovers,
    scorecard.runsconceded
   FROM (public.scorecard
     JOIN public.player USING (playerid));


ALTER VIEW public.scorecard_view OWNER TO postgres;

--
-- Name: team_teamid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.team ALTER COLUMN teamid ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.team_teamid_seq
    START WITH 4
    INCREMENT BY 1
    MINVALUE 4
    MAXVALUE 999999
    CACHE 1
);


--
-- Name: teamrank; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.teamrank (
    teamid integer NOT NULL,
    t20irank integer DEFAULT 0 NOT NULL,
    odirank integer DEFAULT 0 NOT NULL,
    testrank integer DEFAULT 0 NOT NULL,
    CONSTRAINT teamrank_pk CHECK (((odirank > 0) AND (t20irank > 0) AND (testrank > 0)))
);


ALTER TABLE public.teamrank OWNER TO postgres;

--
-- Name: team_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.team_view AS
 SELECT team.teamname,
    team.totalwins,
    team.totallosses,
    team.draws,
    teamrank.odirank,
    teamrank.t20irank,
    teamrank.testrank,
    captain.playername AS captain,
    wicketkeeper.playername AS keeper,
    coach.coachname AS coach
   FROM ((((public.team
     JOIN public.teamrank USING (teamid))
     JOIN public.coach USING (coachid))
     JOIN public.player captain ON ((captain.playerid = team.captainid)))
     JOIN public.player wicketkeeper ON ((wicketkeeper.playerid = team.wicketkeeperid)));


ALTER VIEW public.team_view OWNER TO postgres;

--
-- Name: teamrank_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.teamrank_view AS
 SELECT team.teamname,
    teamrank.t20irank,
    teamrank.odirank,
    teamrank.testrank
   FROM (public.teamrank
     JOIN public.team USING (teamid));


ALTER VIEW public.teamrank_view OWNER TO postgres;

--
-- Name: tournament; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tournament (
    name character varying(256) NOT NULL,
    startdate timestamp without time zone NOT NULL,
    enddate timestamp without time zone NOT NULL,
    winning_team integer,
    winningpic character varying(256),
    tournamentlogo character varying(255),
    tournamentid integer NOT NULL
);


ALTER TABLE public.tournament OWNER TO postgres;

--
-- Name: tournament_tournamentid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tournament_tournamentid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tournament_tournamentid_seq OWNER TO postgres;

--
-- Name: tournament_tournamentid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tournament_tournamentid_seq OWNED BY public.tournament.tournamentid;


--
-- Name: tournament_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.tournament_view AS
 SELECT tournament.name AS tournamentname,
    team.teamname,
    tournament.startdate,
    tournament.enddate
   FROM (public.tournament
     JOIN public.team ON ((team.teamid = tournament.winning_team)));


ALTER VIEW public.tournament_view OWNER TO postgres;

--
-- Name: umpire_umpireid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.umpire ALTER COLUMN umpireid ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.umpire_umpireid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999
    CACHE 1
);


--
-- Name: umpire_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.umpire_view AS
 SELECT umpire.umpirename,
    umpire.nomatches
   FROM public.umpire;


ALTER VIEW public.umpire_view OWNER TO postgres;

--
-- Name: users_userid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_userid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_userid_seq OWNER TO postgres;

--
-- Name: users_userid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_userid_seq OWNED BY public.users.userid;


--
-- Name: wicketkeeper; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.wicketkeeper (
    totalcatches integer NOT NULL,
    totalstumps integer NOT NULL,
    playerid integer NOT NULL
);


ALTER TABLE public.wicketkeeper OWNER TO postgres;

--
-- Name: wicketkeeper_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.wicketkeeper_view AS
 SELECT player.playername,
    wicketkeeper.totalcatches,
    wicketkeeper.totalstumps
   FROM (public.wicketkeeper
     JOIN public.player USING (playerid));


ALTER VIEW public.wicketkeeper_view OWNER TO postgres;

--
-- Name: coach coachid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coach ALTER COLUMN coachid SET DEFAULT nextval('public.coach_coachid_seq'::regclass);


--
-- Name: tournament tournamentid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tournament ALTER COLUMN tournamentid SET DEFAULT nextval('public.tournament_tournamentid_seq'::regclass);


--
-- Name: users userid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN userid SET DEFAULT nextval('public.users_userid_seq'::regclass);


--
-- Data for Name: batsman; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.batsman (playerid, nosixes, nofours, noruns, bathand, ballsfaced, totalinningsbatted) FROM stdin;
681	0	0	0	Right	0	0
682	0	0	0	Right	0	0
683	0	0	0	Right	0	0
525	0	0	0	Right	0	0
685	0	0	0	Right	0	0
523	0	0	0	Left	0	0
520	0	0	0	Right	0	0
687	0	0	0	Left	0	0
688	0	0	0	Right	0	0
691	0	0	0	Right	0	0
522	0	0	0	Right	0	0
521	0	0	0	Left	0	0
533	0	0	0	Left	0	0
692	0	0	0	Right	0	0
693	0	0	0	Right	0	0
697	0	0	0	Right	0	0
696	0	0	0	Right	0	0
698	0	0	0	Right	0	0
538	0	0	0	Right	0	0
540	0	0	0	Right	0	0
543	0	0	0	Right	0	0
544	0	0	0	Right	0	0
547	0	0	0	Right	0	0
550	0	0	0	Right	0	0
551	0	0	0	Right	0	0
555	0	0	0	Right	0	0
558	0	0	0	Right	0	0
561	0	0	0	Right	0	0
564	0	0	0	Right	0	0
565	0	0	0	Right	0	0
567	0	0	0	Right	0	0
568	0	0	0	Right	0	0
572	0	0	0	Right	0	0
574	0	0	0	Right	0	0
577	0	0	0	Right	0	0
580	0	0	0	Right	0	0
581	0	0	0	Right	0	0
584	0	0	0	Right	0	0
593	0	0	0	Right	0	0
600	0	0	0	Right	0	0
607	0	0	0	Right	0	0
613	0	0	0	Right	0	0
618	0	0	0	Right	0	0
629	0	0	0	Right	0	0
641	0	0	0	Right	0	0
655	0	0	0	Right	0	0
662	0	0	0	Right	0	0
548	0	0	0	Right	0	0
552	0	0	0	Right	0	0
553	0	0	0	Right	0	0
554	0	0	0	Right	0	0
560	0	0	0	Left	0	0
557	0	0	0	Right	0	0
569	0	0	0	Right	0	0
570	0	0	0	Right	0	0
578	0	0	0	Left	0	0
588	0	0	0	Left	0	0
590	0	0	0	Right	0	0
598	0	0	0	Left	0	0
635	0	0	0	Left	0	0
587	0	0	0	Right	0	0
597	0	0	0	Right	0	0
616	0	0	0	Right	0	0
633	0	0	0	Right	0	0
646	0	0	0	Right	0	0
576	0	0	0	Left	0	0
594	0	0	0	Right	0	0
620	0	0	0	Right	0	0
622	0	0	0	Right	0	0
661	0	0	0	Right	0	0
380	0	0	0	Right	0	0
396	0	0	0	Right	0	0
403	0	0	0	Left	0	0
474	0	0	0	Left	0	0
510	0	0	0	Right	0	0
438	1	0	12	Right	6	1
585	0	0	0	Right	0	0
596	0	0	0	Right	0	0
599	0	0	0	Right	0	0
626	0	0	0	Right	0	0
639	0	0	0	Right	0	0
653	0	0	0	Right	0	0
659	0	0	0	Right	0	0
675	0	0	0	Right	0	0
609	0	0	0	Right	0	0
632	0	0	0	Right	0	0
666	0	0	0	Left	0	0
387	0	0	0	Left	0	0
390	0	0	0	Right	0	0
425	0	0	0	Right	0	0
427	0	0	0	Right	0	0
454	0	0	0	Right	0	0
463	0	0	0	Left	0	0
517	0	0	0	Right	0	0
445	1	1	23	Right	23	1
499	0	0	12	Left	12	1
611	0	0	0	Right	0	0
617	0	0	0	Right	0	0
663	0	0	0	Right	0	0
670	0	0	0	Right	0	0
589	0	0	0	Left	0	0
605	0	0	0	Right	0	0
623	0	0	0	Right	0	0
642	0	0	0	Right	0	0
648	0	0	0	Left	0	0
383	0	0	0	Right	0	0
393	0	0	0	Left	0	0
409	0	0	0	Right	0	0
417	0	0	0	Right	0	0
426	0	0	0	Left	0	0
462	0	0	0	Right	0	0
471	0	0	0	Right	0	0
507	0	0	0	Right	0	0
435	3	2	55	Right	34	1
498	0	0	23	Right	21	1
602	0	0	0	Right	0	0
619	0	0	0	Right	0	0
625	0	0	0	Right	0	0
644	0	0	0	Right	0	0
651	0	0	0	Right	0	0
673	0	0	0	Right	0	0
614	0	0	0	Right	0	0
608	0	0	0	Left	0	0
677	0	0	0	Right	0	0
384	0	0	0	Left	0	0
433	0	0	0	Left	0	0
442	4	4	50	Left	33	1
487	7	4	100	Right	78	1
610	0	0	0	Right	0	0
628	0	0	0	Right	0	0
652	0	0	0	Right	0	0
660	0	0	0	Right	0	0
636	0	0	0	Left	0	0
679	0	0	0	Right	0	0
404	0	0	0	Right	0	0
422	0	0	0	Right	0	0
450	0	0	0	Right	0	0
459	0	0	0	Right	0	0
656	0	0	0	Right	0	0
664	0	0	0	Right	0	0
634	0	0	0	Left	0	0
678	0	0	0	Right	0	0
399	0	0	0	Left	0	0
406	0	0	0	Right	0	0
415	0	0	0	Right	0	0
470	0	0	0	Right	0	0
479	0	0	0	Right	0	0
506	0	0	0	Left	0	0
443	10	3	150	Right	90	1
497	3	3	55	Right	45	1
650	0	0	0	Right	0	0
680	0	0	0	Right	0	0
379	0	0	0	Left	0	0
511	0	0	0	Left	0	0
439	0	0	0	Right	1	1
502	0	0	0	Left	0	1
493	2	0	50	Right	44	1
413	0	0	0	Right	0	0
421	0	0	0	Right	0	0
440	0	0	0	Right	0	0
458	0	0	0	Right	0	0
485	0	0	0	Right	0	0
503	0	0	0	Right	0	0
408	0	0	0	Left	0	0
455	0	0	0	Right	0	0
464	0	0	0	Right	0	0
473	0	0	0	Left	0	0
482	0	0	0	Right	0	0
491	0	0	0	Right	0	0
500	0	0	0	Left	0	0
509	0	0	0	Right	0	0
\.


--
-- Data for Name: bowler; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bowler (playerid, nowickets, bowlhand, bowltype, oversbowled, maidenovers, runsconceded, totalinningsbowled, dotballs, noballsbowled) FROM stdin;
684	0	Left	Leg-Spin	0	0	0	0	0	0
524	0	right	medium	0	0	0	0	0	0
529	0	right	fast	0	0	0	0	0	0
686	0	Left	Leg-Spin	0	0	0	0	0	0
591	0	Left	Leg-Spin	0	0	0	0	0	0
601	0	Left	Leg-Spin	0	0	0	0	0	0
606	0	Left	Leg-Spin	0	0	0	0	0	0
612	0	Left	Leg-Spin	0	0	0	0	0	0
627	0	Left	Leg-Spin	0	0	0	0	0	0
640	0	Left	Leg-Spin	0	0	0	0	0	0
654	0	Left	Leg-Spin	0	0	0	0	0	0
668	0	Left	Leg-Spin	0	0	0	0	0	0
676	0	Left	Leg-Spin	0	0	0	0	0	0
576	0	right	medium	0	0	0	0	0	0
594	0	right	off-spin	0	0	0	0	0	0
622	0	right	medium	0	0	0	0	0	0
620	0	right	fast	0	0	0	0	0	0
661	0	left	fast	0	0	0	0	0	0
689	0	Left	Leg-Spin	0	0	0	0	0	0
690	0	Left	Leg-Spin	0	0	0	0	0	0
687	0	right	medium	0	0	0	0	0	0
688	0	right	medium	0	0	0	0	0	0
377	0	left	medium	0	0	0	0	0	0
386	0	right	medium	0	0	0	0	0	0
385	0	right	fast	0	0	0	0	0	0
388	0	right	medium	0	0	0	0	0	0
381	0	right	medium	0	0	0	0	0	0
394	0	left	medium	0	0	0	0	0	0
378	0	right	medium	0	0	0	0	0	0
397	0	left	fast	0	0	0	0	0	0
400	0	right	medium	0	0	0	0	0	0
382	0	right	medium	0	0	0	0	0	0
691	0	right	leg-spin	0	0	0	0	0	0
401	0	left	medium	0	0	0	0	0	0
420	0	right	fast	0	0	0	0	0	0
430	0	right	fast	0	0	0	0	0	0
457	0	right	medium	0	0	0	0	0	0
466	0	right	medium	0	0	0	0	0	0
475	0	right	fast	0	0	0	0	0	0
484	0	right	medium	0	0	0	0	0	0
516	0	right	medium	0	0	0	0	0	0
444	0	right	medium	10	0	0	1	0	0
489	4	left	fast	10	0	31	1	0	0
526	0	right	medium	0	0	0	0	0	0
530	0	right	fast	0	0	0	0	0	0
592	0	Left	Leg-Spin	0	0	0	0	0	0
631	0	Left	Leg-Spin	0	0	0	0	0	0
638	0	Left	Leg-Spin	0	0	0	0	0	0
658	0	Left	Leg-Spin	0	0	0	0	0	0
665	0	Left	Leg-Spin	0	0	0	0	0	0
614	0	right	fast	0	0	0	0	0	0
608	0	right	medium	0	0	0	0	0	0
677	0	right	off-spin	0	0	0	0	0	0
694	0	Left	Leg-Spin	0	0	0	0	0	0
449	0	left	medium	0	0	0	0	0	0
476	0	right	medium	0	0	0	0	0	0
512	0	right	medium	0	0	0	0	0	0
494	2	right	medium	5	0	0	1	0	0
532	0	right	fast	0	0	0	0	0	0
630	0	Left	Leg-Spin	0	0	0	0	0	0
637	0	Left	Leg-Spin	0	0	0	0	0	0
657	0	Left	Leg-Spin	0	0	0	0	0	0
589	0	left	fast	0	0	0	0	0	0
605	0	right	medium	0	0	0	0	0	0
623	0	right	leg-spin	0	0	0	0	0	0
642	0	right	leg-spin	0	0	0	0	0	0
648	0	right	medium	0	0	0	0	0	0
695	0	Left	Leg-Spin	0	0	0	0	0	0
405	0	right	fast	0	0	0	0	0	0
414	0	right	medium	0	0	0	0	0	0
423	0	right	fast	0	0	0	0	0	0
469	0	right	medium	0	0	0	0	0	0
496	0	right	fast	0	0	0	0	0	0
505	0	right	fast	0	0	0	0	0	0
514	0	right	fast	0	0	0	0	0	0
604	0	Left	Leg-Spin	0	0	0	0	0	0
615	0	Left	Leg-Spin	0	0	0	0	0	0
621	0	Left	Leg-Spin	0	0	0	0	0	0
645	0	Left	Leg-Spin	0	0	0	0	0	0
609	0	right	fast	0	0	0	0	0	0
632	0	right	medium	0	0	0	0	0	0
666	0	right	fast	0	0	0	0	0	0
697	0	right	off-spin	0	0	0	0	0	0
407	0	right	medium	0	0	0	0	0	0
416	0	left	medium	0	0	0	0	0	0
472	0	left	medium	0	0	0	0	0	0
534	0	left	medium	0	0	0	0	0	0
643	0	Left	Leg-Spin	0	0	0	0	0	0
667	0	Left	Leg-Spin	0	0	0	0	0	0
636	0	left	medium	0	0	0	0	0	0
679	0	right	fast	0	0	0	0	0	0
696	0	right	fast	0	0	0	0	0	0
483	0	right	medium	0	0	0	0	0	0
519	0	Right	fast	0	0	0	0	0	0
501	2	right	medium	10	0	0	1	0	0
492	0	right	medium	10	0	0	1	0	0
447	3	right	fast	10	0	0	1	0	0
634	0	right	fast	0	0	0	0	0	0
678	0	right	leg-spin	0	0	0	0	0	0
698	0	right	medium	0	0	0	0	0	0
412	0	left	medium	0	0	0	0	0	0
486	0	right	medium	0	0	0	0	0	0
504	0	right	medium	0	0	0	0	0	0
649	0	Left	Leg-Spin	0	0	0	0	0	0
671	0	Left	Leg-Spin	0	0	0	0	0	0
428	0	right	medium	0	0	0	0	0	0
437	0	right	fast	0	0	0	0	0	0
446	0	right	fast	0	0	0	0	0	0
518	0	right	medium	0	0	0	0	0	0
672	0	Left	Leg-Spin	0	0	0	0	0	0
674	0	Left	Leg-Spin	0	0	0	0	0	0
424	0	left	medium	0	0	0	0	0	0
434	0	left	medium	0	0	0	0	0	0
461	0	right	medium	0	0	0	0	0	0
515	0	left	medium	0	0	0	0	0	0
539	0	Left	Leg-Spin	0	0	0	0	0	0
541	0	Left	Leg-Spin	0	0	0	0	0	0
542	0	Left	Leg-Spin	0	0	0	0	0	0
545	0	Left	Leg-Spin	0	0	0	0	0	0
546	0	Left	Leg-Spin	0	0	0	0	0	0
549	0	Left	Leg-Spin	0	0	0	0	0	0
556	0	Left	Leg-Spin	0	0	0	0	0	0
559	0	Left	Leg-Spin	0	0	0	0	0	0
562	0	Left	Leg-Spin	0	0	0	0	0	0
563	0	Left	Leg-Spin	0	0	0	0	0	0
566	0	Left	Leg-Spin	0	0	0	0	0	0
571	0	Left	Leg-Spin	0	0	0	0	0	0
573	0	Left	Leg-Spin	0	0	0	0	0	0
575	0	Left	Leg-Spin	0	0	0	0	0	0
579	0	Left	Leg-Spin	0	0	0	0	0	0
582	0	Left	Leg-Spin	0	0	0	0	0	0
583	0	Left	Leg-Spin	0	0	0	0	0	0
586	0	Left	Leg-Spin	0	0	0	0	0	0
595	0	Left	Leg-Spin	0	0	0	0	0	0
603	0	Left	Leg-Spin	0	0	0	0	0	0
624	0	Left	Leg-Spin	0	0	0	0	0	0
647	0	Left	Leg-Spin	0	0	0	0	0	0
669	0	Left	Leg-Spin	0	0	0	0	0	0
552	0	right	leg-spin	0	0	0	0	0	0
548	0	right	fast	0	0	0	0	0	0
560	0	right	medium	0	0	0	0	0	0
553	0	right	fast	0	0	0	0	0	0
554	0	right	off-spin	0	0	0	0	0	0
557	0	right	fast	0	0	0	0	0	0
569	0	right	off-spin	0	0	0	0	0	0
578	0	right	off-spin	0	0	0	0	0	0
570	0	right	off-spin	0	0	0	0	0	0
588	0	right	fast	0	0	0	0	0	0
590	0	right	fast	0	0	0	0	0	0
598	0	right	medium	0	0	0	0	0	0
635	0	right	medium	0	0	0	0	0	0
\.


--
-- Data for Name: captain; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.captain (playerid, matchesascaptain, totalwins) FROM stdin;
443	4	4
487	4	0
385	0	0
379	0	0
403	0	0
417	0	0
454	0	0
470	0	0
503	0	0
520	0	0
\.


--
-- Data for Name: coach; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.coach (coachname, picture, coachid) FROM stdin;
Grant Bradburn	http://localhost:3000/1704095288176_bradburn.jpg	9
Jonathan Trott	http://localhost:3000/1704095323987_trott.jpg	10
Andrew McDonald	http://localhost:3000/1704095343772_mcdonald.jpg	11
Rahul Dravid	http://localhost:3000/1704095578341_rahuldravid.webp	12
Matthew Mott	http://localhost:3000/1704095615230_mott.jpg	13
Chandika Hathurusingha	http://localhost:3000/1704256245190_chandika.jpg	15
Ryan Cook	http://localhost:3000/1704256408594_cook.webp	16
Gary Stead	http://localhost:3000/1704256437837_stead.jpg	17
Rob Walter	http://localhost:3000/1704256471461_walter.webp	18
Chris Silverwood	http://localhost:3000/1704256503680_chris.jpg	19
\.


--
-- Data for Name: country; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.country (countryid, country) FROM stdin;
24	Pakistan
7	Australia
8	Bangladesh
9	England
10	India
11	New Zealand
12	South Africa
13	Sri Lanka
14	West Indies
15	Zimbabwe
16	Afghanistan
17	Ireland
18	Netherlands
\.


--
-- Data for Name: location; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.location (locationid, location) FROM stdin;
1	Melbourne Cricket Ground
2	Lord's
3	Narendra Modi Stadium
24	Gaddafi Stadium
25	Mumbai Stadium
26	Ahmedabad
27	Std1
28	Narendra Modi Stadium, Ahmedabad
29	Rajiv Gandhi International Stadium, Hyderabad
\.


--
-- Data for Name: match; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.match (matchid, date, tournamentid, team1id, team2id, winnerteam, umpire, locationid, matchtype) FROM stdin;
\.


--
-- Data for Name: player; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.player (playerid, playername, dob, teamid, totalt20i, totalodi, totaltest, playertype, playerstatus, playerpicpath, countryid) FROM stdin;
520	Kusal Mendis	1995-02-02	34	0	0	0	batsman	active	http://localhost:3000/1704259084714_mendis.webp	13
525	Sadeera Samarawickrama	1995-06-30	34	0	0	0	batsman	active	https:	13
526	Maheesh Theekshana	2000-08-01	34	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/1/11/Flag_of_Sri_Lanka.svg/23px-Flag_of_Sri_Lanka.svg.png	13
530	Lahiru Kumara	1997-02-13	34	0	0	0	Bowler	active	https:	13
523	Kusal Perera	1990-08-17	34	0	0	0	batsman	active	http://localhost:3000/1704258991461_kusal.webp	13
649	Haris Rauf	1993-11-07	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/36/1_53_Haris_Rauf.jpg/220px-1_53_Haris_Rauf.jpg	24
671	Sisanda Magala	1991-01-07	\N	0	0	0	Bowler	active	https:	12
524	Kasun Rajitha	1993-06-01	34	0	0	0	Bowler	active	https:	13
529	Matheesha Pathirana	2002-12-18	34	0	0	0	Bowler	active	https:	13
522	Pathum Nissanka	1998-05-18	34	0	0	0	Batsman	active	http://localhost:3000/1704259020391_pathum.webp	13
521	Charith Asalanka	1997-06-29	34	0	0	0	Batsman	active	http://localhost:3000/1704259044912_charith.jpg	13
650	Mohammad Rizwan	1992-06-01	\N	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/a/af/M_Rizwan.jpg/220px-M_Rizwan.jpg	24
672	Anrich Nortje	1993-11-16	\N	0	0	0	Bowler	active	https:	12
674	Noor Ahmad	2005-01-03	\N	0	0	0	Bowler	active	https:	16
680	Riaz Hassan	2002-11-07	\N	0	0	0	Batsman	active	https:	16
681	Kusal Mendis	1995-02-02	\N	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/1/11/Flag_of_Sri_Lanka.svg/23px-Flag_of_Sri_Lanka.svg.png	13
682	Pathum Nissanka	1998-05-18	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/1/11/Flag_of_Sri_Lanka.svg/23px-Flag_of_Sri_Lanka.svg.png	13
683	Kusal Perera	1990-08-17	\N	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/1/11/Flag_of_Sri_Lanka.svg/23px-Flag_of_Sri_Lanka.svg.png	13
684	Kasun Rajitha	1993-06-01	\N	0	0	0	Bowler	active	https:	13
685	Sadeera Samarawickrama	1995-06-30	\N	0	0	0	batsman	active	https:	13
686	Maheesh Theekshana	2000-08-01	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/1/11/Flag_of_Sri_Lanka.svg/23px-Flag_of_Sri_Lanka.svg.png	13
687	Dunith Wellalage	2003-01-09	\N	0	0	0	allrounder	active	https:	13
688	Dasun Shanaka	1991-09-09	\N	0	0	0	allrounder	active	https:	13
689	Matheesha Pathirana	2002-12-18	\N	0	0	0	Bowler	active	https:	13
690	Lahiru Kumara	1997-02-13	\N	0	0	0	Bowler	active	https:	13
532	Dushmantha Chameera	1992-01-11	\N	0	0	0	Bowler	active	https:	13
691	Dushan Hemantha	1994-05-24	\N	0	0	0	allrounder	active	https:	13
533	Dhananjaya de Silva	1991-09-06	\N	0	0	0	Batsman	active	https:	13
692	Dhananjaya de Silva	1991-09-06	\N	0	0	0	Batsman	active	https:	13
534	Dilshan Madushanka	2000-09-18	\N	0	0	0	Bowler	active	https:	13
693	Charith Asalanka	1997-06-29	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/1/11/Flag_of_Sri_Lanka.svg/23px-Flag_of_Sri_Lanka.svg.png	13
694	Dushmantha Chameera	1992-01-11	\N	0	0	0	Bowler	active	https:	13
695	Dilshan Madushanka	2000-09-18	\N	0	0	0	Bowler	active	https:	13
696	Chamika Karunaratne	1996-05-29	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Chamika_Karunaratne.jpg/220px-Chamika_Karunaratne.jpg	13
385	Pat Cummins	1993-05-08	27	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/6/69/Pat_Cummins_fielding_Ashes_2021_%28cropped%29.jpg/220px-Pat_Cummins_fielding_Ashes_2021_%28cropped%29.jpg	7
390	Josh Inglis	1995-06-10	27	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Flag_of_Australia_%28converted%29.svg/23px-Flag_of_Australia_%28converted%29.svg.png	7
386	Sean Abbott	1992-02-29	27	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/en/thumb/b/bd/Sean_Abbott_playing_for_the_Sydney_Sixers.jpg/220px-Sean_Abbott_playing_for_the_Sydney_Sixers.jpg	7
387	Alex Carey	1991-08-27	27	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/35/Alex_Carey_wicket-keeping_Ashes_2021_%28cropped_2%29.jpg/220px-Alex_Carey_wicket-keeping_Ashes_2021_%28cropped_2%29.jpg	7
388	Josh Hazlewood	1991-01-08	27	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/7/77/2018.01.21.17.06.41-Hazelwood_%2839139885264%29.jpg/220px-2018.01.21.17.06.41-Hazelwood_%2839139885264%29.jpg	7
393	Travis Head	1993-12-29	27	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Travis_Head_bowling_at_Perth_Stadium%2C_First_Test_Australia_versus_West_Indies%2C_2_December_2022_03_%28cropped%29.jpg/220px-Travis_Head_bowling_at_Perth_Stadium%2C_First_Test_Australia_versus_We	7
396	Steve Smith	1989-06-02	27	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/4/40/Steve_Smith_%2848094026552%29.jpg/220px-Steve_Smith_%2848094026552%29.jpg	7
378	Abdul Rahman	2001-11-22	\N	0	0	0	Bowler	active	https:	16
380	Rahmat Shah	1993-07-06	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Rahmat_Shah.jpg/220px-Rahmat_Shah.jpg	16
394	Fazalhaq Farooqi	2000-09-22	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Fazalhaq_Farooqi.jpg/220px-Fazalhaq_Farooqi.jpg	16
397	Mitchell Starc	1990-01-30	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/4/45/Mitchell_Starc_fielding_2021_%28cropped%29.jpg/220px-Mitchell_Starc_fielding_2021_%28cropped%29.jpg	7
399	David Warner	1986-10-27	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/2/2c/DAVID_WARNER_%2811704782453%29.jpg/220px-DAVID_WARNER_%2811704782453%29.jpg	7
400	Adam Zampa	1992-03-31	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/5/51/Adam_Zampa_2023.jpg/220px-Adam_Zampa_2023.jpg	7
379	Hashmatullah Shahidi	1994-11-04	28	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/38/Hashmatullah_Shahidi.jpg/220px-Hashmatullah_Shahidi.jpg	16
383	Ibrahim Zadran	2001-12-12	28	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/2/2b/Ibrahim_Zadran.jpg/220px-Ibrahim_Zadran.jpg	16
382	Mujeeb Ur Rahman	2001-03-28	28	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/e/e1/Mujeeb_Ur_Rahman_celebrating.jpg/220px-Mujeeb_Ur_Rahman_celebrating.jpg	16
381	Naveen-ul-Haq	1999-09-23	28	0	0	0	Bowler	active	https:	16
377	Noor Ahmad	2005-01-03	28	0	0	0	Bowler	active	https:	16
384	Najibullah Zadran	1993-02-18	28	0	0	0	Batsman	active	https:	16
403	Najmul Hossain Shanto	1998-08-25	29	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/7/75/Najmul_Hossain_Shanto.jpg/220px-Najmul_Hossain_Shanto.jpg	8
408	Tanzid Hasan Tamim	2000-12-01	29	0	0	0	Batsman	active	https:	8
404	Anamul Haque	1992-12-16	29	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Flag_of_Bangladesh.svg/23px-Flag_of_Bangladesh.svg.png	8
401	Nasum Ahmed	1994-12-05	29	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/0/00/Nasum_Ahmed_on_2022.png/220px-Nasum_Ahmed_on_2022.png	8
538	Hashmatullah Shahidi	1994-11-04	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/38/Hashmatullah_Shahidi.jpg/220px-Hashmatullah_Shahidi.jpg	16
539	Abdul Rahman	2001-11-22	\N	0	0	0	Bowler	active	https:	16
540	Rahmat Shah	1993-07-06	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Rahmat_Shah.jpg/220px-Rahmat_Shah.jpg	16
541	Naveen-ul-Haq	1999-09-23	\N	0	0	0	Bowler	active	https:	16
542	Mujeeb Ur Rahman	2001-03-28	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/e/e1/Mujeeb_Ur_Rahman_celebrating.jpg/220px-Mujeeb_Ur_Rahman_celebrating.jpg	16
543	Ibrahim Zadran	2001-12-12	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/2/2b/Ibrahim_Zadran.jpg/220px-Ibrahim_Zadran.jpg	16
544	Najibullah Zadran	1993-02-18	\N	0	0	0	Batsman	active	https:	16
545	Pat Cummins	1993-05-08	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/6/69/Pat_Cummins_fielding_Ashes_2021_%28cropped%29.jpg/220px-Pat_Cummins_fielding_Ashes_2021_%28cropped%29.jpg	7
546	Sean Abbott	1992-02-29	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/en/thumb/b/bd/Sean_Abbott_playing_for_the_Sydney_Sixers.jpg/220px-Sean_Abbott_playing_for_the_Sydney_Sixers.jpg	7
547	Alex Carey	1991-08-27	\N	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/35/Alex_Carey_wicket-keeping_Ashes_2021_%28cropped_2%29.jpg/220px-Alex_Carey_wicket-keeping_Ashes_2021_%28cropped_2%29.jpg	7
405	Taskin Ahmed	1995-04-05	29	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Taskin_Ahmed_at_Chef%27s_Table.png/220px-Taskin_Ahmed_at_Chef%27s_Table.png	8
423	Brydon Carse	1995-07-31	30	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/a/ad/1_24_Brydon_Carse.jpg/220px-1_24_Brydon_Carse.jpg	9
469	Ryan Klein	1997-06-15	31	0	0	0	Bowler	active	https:	18
505	Gerald Coetzee	2000-10-02	32	0	0	0	Bowler	active	https:	12
514	Kagiso Rabada	1995-05-25	32	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/0/08/Rabada.jpg/220px-Rabada.jpg	12
548	Cameron Green	1999-06-03	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/b/b4/Cameron_Green_fielding_Boxing_Day_2022_%28cropped%29.jpg/220px-Cameron_Green_fielding_Boxing_Day_2022_%28cropped%29.jpg	7
549	Josh Hazlewood	1991-01-08	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/7/77/2018.01.21.17.06.41-Hazelwood_%2839139885264%29.jpg/220px-2018.01.21.17.06.41-Hazelwood_%2839139885264%29.jpg	7
550	Travis Head	1993-12-29	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Travis_Head_bowling_at_Perth_Stadium%2C_First_Test_Australia_versus_West_Indies%2C_2_December_2022_03_%28cropped%29.jpg/220px-Travis_Head_bowling_at_Perth_Stadium%2C_First_Test_Australia_versus_We	7
551	Josh Inglis	1995-06-10	\N	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Flag_of_Australia_%28converted%29.svg/23px-Flag_of_Australia_%28converted%29.svg.png	7
552	Marnus Labuschagne	1994-05-22	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Day_4_of_the_3rd_Test_of_the_2019_Ashes_at_Headingley_%2848631113862%29_%28Marnus_Labuschagne_cropped%29.jpg/220px-Day_4_of_the_3rd_Test_of_the_2019_Ashes_at_Headingley_%2848631113862%29_%28Marnus	7
496	Haris Rauf	1993-11-07	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/36/1_53_Haris_Rauf.jpg/220px-1_53_Haris_Rauf.jpg	24
442	Ishan Kishan	1998-07-18	26	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/d/d7/Ishan_Kishan.jpg/220px-Ishan_Kishan.jpg	10
553	Mitchell Marsh	1991-10-20	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/7/73/Mitchell_Marsh.jpg/220px-Mitchell_Marsh.jpg	7
554	Glenn Maxwell	1988-10-14	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/9/94/3-_Protest_Glenn_Maxwell_%28cropped%29.jpg/220px-3-_Protest_Glenn_Maxwell_%28cropped%29.jpg	7
555	Steve Smith	1989-06-02	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/4/40/Steve_Smith_%2848094026552%29.jpg/220px-Steve_Smith_%2848094026552%29.jpg	7
556	Mitchell Starc	1990-01-30	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/4/45/Mitchell_Starc_fielding_2021_%28cropped%29.jpg/220px-Mitchell_Starc_fielding_2021_%28cropped%29.jpg	7
557	Marcus Stoinis	1989-08-16	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/2/2b/2018.01.21.15.22.25-Stoinis_%2839081521620%29.jpg/220px-2018.01.21.15.22.25-Stoinis_%2839081521620%29.jpg	7
558	David Warner	1986-10-27	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/2/2c/DAVID_WARNER_%2811704782453%29.jpg/220px-DAVID_WARNER_%2811704782453%29.jpg	7
559	Adam Zampa	1992-03-31	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/5/51/Adam_Zampa_2023.jpg/220px-Adam_Zampa_2023.jpg	7
560	Ashton Agar	1993-10-14	\N	0	0	0	allrounder	active	https:	7
561	Najmul Hossain Shanto	1998-08-25	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/7/75/Najmul_Hossain_Shanto.jpg/220px-Najmul_Hossain_Shanto.jpg	8
562	Nasum Ahmed	1994-12-05	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/0/00/Nasum_Ahmed_on_2022.png/220px-Nasum_Ahmed_on_2022.png	8
563	Taskin Ahmed	1995-04-05	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Taskin_Ahmed_at_Chef%27s_Table.png/220px-Taskin_Ahmed_at_Chef%27s_Table.png	8
487	Babar Azam	1994-10-15	24	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/4/43/Babar_azam_2023.jpg/220px-Babar_azam_2023.jpg	24
433	Rahmanullah Gurbaz	2001-11-28	28	0	0	0	batsman	active	https:	16
414	Hasan Mahmud	1999-10-12	29	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Flag_of_Bangladesh.svg/23px-Flag_of_Bangladesh.svg.png	8
564	Litton Das	1994-10-13	\N	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/6/69/Liton_Das_%283%29_%28cropped%29.jpg/220px-Liton_Das_%283%29_%28cropped%29.jpg	8
565	Anamul Haque	1992-12-16	\N	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Flag_of_Bangladesh.svg/23px-Flag_of_Bangladesh.svg.png	8
566	Tanzim Hasan Sakib	2002-10-20	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Flag_of_Bangladesh.svg/23px-Flag_of_Bangladesh.svg.png	8
567	Tanzid Hasan Tamim	2000-12-01	\N	0	0	0	Batsman	active	https:	8
568	Towhid Hridoy	2000-12-04	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Flag_of_Bangladesh.svg/23px-Flag_of_Bangladesh.svg.png	8
569	Mahedi Hasan	1994-12-12	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Flag_of_Bangladesh.svg/23px-Flag_of_Bangladesh.svg.png	8
570	Mehidy Hasan	1997-10-25	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/d/db/%E0%A6%AE%E0%A7%87%E0%A6%B9%E0%A7%87%E0%A6%A6%E0%A7%80_%E0%A6%B9%E0%A6%BE%E0%A6%B8%E0%A6%BE%E0%A6%A8_%E0%A6%AE%E0%A6%BF%E0%A6%B0%E0%A6%BE%E0%A6%9C_%28cropped%29.jpg/220px-%E0%A6%AE%E0%A7%87%E0%A6%	8
571	Shoriful Islam	2001-06-03	\N	0	0	0	Bowler	active	https:	8
515	Tabraiz Shamsi	1990-02-18	32	0	0	0	Bowler	active	https:	12
470	Kane Williamson	1990-08-08	33	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Kane_Williamson_in_2019.jpg/220px-Kane_Williamson_in_2019.jpg	11
479	Glenn Phillips	1996-12-06	33	0	0	0	Batsman	active	https:	11
572	Mahmudullah	1986-02-04	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Mahmudullah_Riyad_on_practice_session_%2816%29_%28cropped%29.jpg/220px-Mahmudullah_Riyad_on_practice_session_%2816%29_%28cropped%29.jpg	8
573	Hasan Mahmud	1999-10-12	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Flag_of_Bangladesh.svg/23px-Flag_of_Bangladesh.svg.png	8
574	Mushfiqur Rahim	1987-05-09	\N	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/e/e4/Mushfiqur_Rahim_2018_%28cropped%29.jpg/220px-Mushfiqur_Rahim_2018_%28cropped%29.jpg	8
575	Mustafizur Rahman	1995-09-06	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a3/Mustafizur_Rahman_%284%29_%28cropped%29.jpg/220px-Mustafizur_Rahman_%284%29_%28cropped%29.jpg	8
577	Jos Buttler	1990-09-08	\N	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/0/01/Jos_Buttler_in_2023.jpg/220px-Jos_Buttler_in_2023.jpg	9
578	Moeen Ali	1987-06-07	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/d/d1/2018.01.06.17.47.32-Moeen_Ali_%2838876905344%29_%28cropped%29.jpg/220px-2018.01.06.17.47.32-Moeen_Ali_%2838876905344%29_%28cropped%29.jpg	9
579	Gus Atkinson	1998-01-19	\N	0	0	0	Bowler	active	https:	9
497	Mohammad Rizwan	1992-06-01	24	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/a/af/M_Rizwan.jpg/220px-M_Rizwan.jpg	24
580	Jonny Bairstow	1989-09-26	\N	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/20150621-Jonny-Bairstow.jpg/220px-20150621-Jonny-Bairstow.jpg	9
581	Harry Brook	1999-02-22	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/4/49/Harry_Brook_%2851225504151%29_%28cropped%29.jpg/220px-Harry_Brook_%2851225504151%29_%28cropped%29.jpg	9
443	Virat Kohli	1988-11-05	26	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/e/ef/Virat_Kohli_during_the_India_vs_Aus_4th_Test_match_at_Narendra_Modi_Stadium_on_09_March_2023.jpg/220px-Virat_Kohli_during_the_India_vs_Aus_4th_Test_match_at_Narendra_Modi_Stadium_on_09_March_2023.	10
415	Mushfiqur Rahim	1987-05-09	29	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/e/e4/Mushfiqur_Rahim_2018_%28cropped%29.jpg/220px-Mushfiqur_Rahim_2018_%28cropped%29.jpg	8
406	Litton Das	1994-10-13	29	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/6/69/Liton_Das_%283%29_%28cropped%29.jpg/220px-Liton_Das_%283%29_%28cropped%29.jpg	8
424	Sam Curran	1998-06-03	30	0	0	0	Bowler	active	https:	9
434	Reece Topley	1994-02-21	30	0	0	0	Bowler	active	https:	9
461	Aryan Dutt	2003-05-12	31	0	0	0	Bowler	active	https:	18
506	Quinton de Kock	1992-12-17	32	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/6/67/QUINTON_DE_KOCK_%2815681398316%29.jpg/220px-QUINTON_DE_KOCK_%2815681398316%29.jpg	12
582	Brydon Carse	1995-07-31	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/a/ad/1_24_Brydon_Carse.jpg/220px-1_24_Brydon_Carse.jpg	9
583	Sam Curran	1998-06-03	\N	0	0	0	Bowler	active	https:	9
584	Dawid Malan	1987-09-03	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/4/46/3_03_Malan_continues.jpg/220px-3_03_Malan_continues.jpg	9
586	Adil Rashid	1988-02-17	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a3/1_13_Adil_Rashid_%28cropped%29.jpg/220px-1_13_Adil_Rashid_%28cropped%29.jpg	9
588	Ben Stokes	1991-06-04	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/BEN_STOKES_%2811704837023%29_%28cropped%29.jpg/220px-BEN_STOKES_%2811704837023%29_%28cropped%29.jpg	9
590	Chris Woakes	1989-03-02	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/Chris_Woakes_2022.jpg/220px-Chris_Woakes_2022.jpg	9
593	Rohit Sharma	1987-04-30	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/c/cc/Rohit_Gurunath_Sharma.jpg/220px-Rohit_Gurunath_Sharma.jpg	10
595	Jasprit Bumrah	1993-12-06	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/1/1c/Jasprit_Bumrah_%284%29.jpg/220px-Jasprit_Bumrah_%284%29.jpg	10
598	Ravindra Jadeja	1988-12-06	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/b/b1/Ravindra_Jadeja_in_2018.jpg/220px-Ravindra_Jadeja_in_2018.jpg	10
600	Virat Kohli	1988-11-05	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/e/ef/Virat_Kohli_during_the_India_vs_Aus_4th_Test_match_at_Narendra_Modi_Stadium_on_09_March_2023.jpg/220px-Virat_Kohli_during_the_India_vs_Aus_4th_Test_match_at_Narendra_Modi_Stadium_on_09_March_2023.	10
603	Mohammed Shami	1990-09-03	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/7/71/Mohammed_Shami.jpg/220px-Mohammed_Shami.jpg	10
607	Suryakumar Yadav	1990-09-14	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/b/b7/Surya_Kumar_Yadav_in_BGT_2023.jpg/220px-Surya_Kumar_Yadav_in_BGT_2023.jpg	10
613	Wesley Barresi	1984-05-03	\N	0	0	0	Batsman	active	https:	18
618	Max O'Dowd	1994-03-04	\N	0	0	0	Batsman	active	https:	18
624	Ryan Klein	1997-06-15	\N	0	0	0	Bowler	active	https:	18
629	Devon Conway	1991-07-08	\N	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Flag_of_New_Zealand.svg/23px-Flag_of_New_Zealand.svg.png	11
635	Rachin Ravindra	1999-11-18	\N	0	0	0	allrounder	active	https:	11
641	Babar Azam	1994-10-15	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/4/43/Babar_azam_2023.jpg/220px-Babar_azam_2023.jpg	24
517	Rassie van der Dussen	1989-02-07	32	0	0	0	Batsman	active	http://localhost:3000/1704133235991_pak.png	12
445	K. L. Rahul	1992-04-18	26	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/6/69/KL_Rahul_at_Femina_Miss_India_2018_Grand_Finale_%28cropped%29.jpg	10
472	Trent Boult	1989-07-22	33	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/2/23/2018.02.03.22.23.14-AUSvNZL_T20_AUS_innings%2C_SCG_%2839533156665%29.jpg/220px-2018.02.03.22.23.14-AUSvNZL_T20_AUS_innings%2C_SCG_%2839533156665%29.jpg	11
576	Shakib Al Hasan	1987-03-24	\N	0	0	0	allrounder	active	https:	8
587	Joe Root	1990-12-30	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f7/Joe_Root_HIP1487_%28cropped%29.jpg/220px-Joe_Root_HIP1487_%28cropped%29.jpg	9
591	Mark Wood	1990-01-11	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/c/c0/Mark_wood_bowling_boxing_day_test.jpg/220px-Mark_wood_bowling_boxing_day_test.jpg	9
499	Saud Shakeel	1995-09-05	24	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/e/e9/1_37_Saud_Shakeel.jpg/220px-1_37_Saud_Shakeel.jpg	24
407	Tanzim Hasan Sakib	2002-10-20	29	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Flag_of_Bangladesh.svg/23px-Flag_of_Bangladesh.svg.png	8
416	Mustafizur Rahman	1995-09-06	29	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a3/Mustafizur_Rahman_%284%29_%28cropped%29.jpg/220px-Mustafizur_Rahman_%284%29_%28cropped%29.jpg	8
425	Liam Livingstone	1993-08-04	30	0	0	0	Batsman	active	https:	9
427	Joe Root	1990-12-30	30	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f7/Joe_Root_HIP1487_%28cropped%29.jpg/220px-Joe_Root_HIP1487_%28cropped%29.jpg	9
594	Ravichandran Ashwin	1986-09-17	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f4/Ravichandran_Ashwin_%282%29.jpg/220px-Ravichandran_Ashwin_%282%29.jpg	10
454	Scott Edwards	1996-08-23	31	0	0	0	batsman	active	https:	18
463	Max O'Dowd	1994-03-04	31	0	0	0	Batsman	active	https:	18
597	Shreyas Iyer	1994-12-06	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/9/96/Shreyas_Iyer_2021.jpg/220px-Shreyas_Iyer_2021.jpg	10
601	Prasidh Krishna	1996-02-19	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/en/thumb/4/41/Flag_of_India.svg/23px-Flag_of_India.svg.png	10
606	Kuldeep Yadav	1994-12-11	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/en/thumb/4/41/Flag_of_India.svg/23px-Flag_of_India.svg.png	10
612	Shariz Ahmad	2003-04-21	\N	0	0	0	Bowler	active	https:	18
616	Sybrand Engelbrecht	1988-09-15	\N	0	0	0	Batsman	active	https:	18
620	Logan van Beek	1990-09-07	\N	0	0	0	allrounder	active	https:	18
622	Roelof van der Merwe	1984-12-31	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/35/Roelof_van_der_Merwe.jpg/220px-Roelof_van_der_Merwe.jpg	18
627	Trent Boult	1989-07-22	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/2/23/2018.02.03.22.23.14-AUSvNZL_T20_AUS_innings%2C_SCG_%2839533156665%29.jpg/220px-2018.02.03.22.23.14-AUSvNZL_T20_AUS_innings%2C_SCG_%2839533156665%29.jpg	11
633	Glenn Phillips	1996-12-06	\N	0	0	0	Batsman	active	https:	11
640	Matt Henry	1991-12-14	\N	0	0	0	Bowler	active	https:	11
646	Salman Ali Agha	1993-11-23	\N	0	0	0	Batsman	active	https:	24
654	Mohammad Wasim Jr.	2001-08-25	\N	0	0	0	Bowler	active	https:	24
661	Marco Jansen	2000-05-01	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/4/41/Marco_Jansen_2022.jpg/220px-Marco_Jansen_2022.jpg	12
668	Tabraiz Shamsi	1990-02-18	\N	0	0	0	Bowler	active	https:	12
676	Fazalhaq Farooqi	2000-09-22	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Fazalhaq_Farooqi.jpg/220px-Fazalhaq_Farooqi.jpg	16
697	Dimuth Karunaratne	1988-04-21	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/6/6c/2_07_Dimuth_Karunaratne.jpg/220px-2_07_Dimuth_Karunaratne.jpg	13
489	Shaheen Afridi	2000-04-06	24	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/7/78/Shaheen_Afridi_%282%29.jpg/220px-Shaheen_Afridi_%282%29.jpg	24
516	Lizaad Williams	1993-10-01	32	0	0	0	Bowler	active	https:	12
435	Rohit Sharma	1987-04-30	26	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/c/cc/Rohit_Gurunath_Sharma.jpg/220px-Rohit_Gurunath_Sharma.jpg	10
444	Prasidh Krishna	1996-02-19	26	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/en/thumb/4/41/Flag_of_India.svg/23px-Flag_of_India.svg.png	10
507	Reeza Hendricks	1989-08-14	32	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/37/REEZA_HENDRICKS_%2815519916117%29.jpg/220px-REEZA_HENDRICKS_%2815519916117%29.jpg	12
471	Tom Latham	1992-04-02	33	0	0	0	batsman	active	https:	11
498	Abdullah Shafique	1999-11-23	24	0	0	0	Batsman	active	https:	24
409	Towhid Hridoy	2000-12-04	29	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Flag_of_Bangladesh.svg/23px-Flag_of_Bangladesh.svg.png	8
417	Jos Buttler	1990-09-08	30	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/0/01/Jos_Buttler_in_2023.jpg/220px-Jos_Buttler_in_2023.jpg	9
426	Dawid Malan	1987-09-03	30	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/4/46/3_03_Malan_continues.jpg/220px-3_03_Malan_continues.jpg	9
462	Teja Nidamanuru	1994-08-22	31	0	0	0	Batsman	active	https:	18
585	Liam Livingstone	1993-08-04	\N	0	0	0	Batsman	active	https:	9
596	Shubman Gill	1999-09-08	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/Shubman_Gill.jpg/220px-Shubman_Gill.jpg	10
599	Ishan Kishan	1998-07-18	\N	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/d/d7/Ishan_Kishan.jpg/220px-Ishan_Kishan.jpg	10
604	Mohammed Siraj	1994-03-13	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/a/ac/Mohammed_Siraj.jpg/220px-Mohammed_Siraj.jpg	10
609	Hardik Pandya	1993-10-11	\N	0	0	0	allrounder	active	https:	10
615	Aryan Dutt	2003-05-12	\N	0	0	0	Bowler	active	https:	18
621	Paul van Meekeren	1993-01-15	\N	0	0	0	Bowler	active	https:	18
626	Tom Latham	1992-04-02	\N	0	0	0	batsman	active	https:	11
632	Daryl Mitchell	1991-05-20	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Flag_of_New_Zealand.svg/23px-Flag_of_New_Zealand.svg.png	11
639	Will Young	1992-11-22	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/4/4b/1_52_Young_faces_Rauf_%28cropped%29.jpg/220px-1_52_Young_faces_Rauf_%28cropped%29.jpg	11
645	Hasan Ali	1994-02-07	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/39/Hasan_ali_%28cropped%29.jpg/220px-Hasan_ali_%28cropped%29.jpg	24
653	Imam-ul-Haq	1995-12-12	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/0/02/Imam-ul-Haq%2C_Pakistan_vs_Sri_Lanka%2C_1st_ODI%2C_2017.jpg/220px-Imam-ul-Haq%2C_Pakistan_vs_Sri_Lanka%2C_1st_ODI%2C_2017.jpg	24
659	Quinton de Kock	1992-12-17	\N	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/6/67/QUINTON_DE_KOCK_%2815681398316%29.jpg/220px-QUINTON_DE_KOCK_%2815681398316%29.jpg	12
666	Andile Phehlukwayo	1996-03-03	\N	0	0	0	allrounder	active	https:	12
675	Ikram Alikhil	2000-11-28	\N	0	0	0	batsman	active	https:	16
698	Angelo Mathews	1987-06-02	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a2/Angelo_Mathews_%285338334462%29.jpg/220px-Angelo_Mathews_%285338334462%29.jpg	13
501	Mohammad Wasim Jr.	2001-08-25	24	0	0	0	Bowler	active	https:	24
492	Hasan Ali	1994-02-07	24	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/39/Hasan_ali_%28cropped%29.jpg/220px-Hasan_ali_%28cropped%29.jpg	24
510	Aiden Markram	1994-10-04	32	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/c/ca/Aiden_Markram_%28cropped%29.jpg/220px-Aiden_Markram_%28cropped%29.jpg	12
519	Anrich Nortj	1993-11-16	32	0	0	0	Bowler	active	http://localhost:3000/1704133339241_pak.png	12
483	Ish Sodhi	1992-10-31	33	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/5/52/2018.02.03.20.52.20-AUSvNZL_T20_NZL_innings%2C_SCG_%2838618201470%29_%28Sodhi_cropped%29.jpg/220px-2018.02.03.20.52.20-AUSvNZL_T20_NZL_innings%2C_SCG_%2838618201470%29_%28Sodhi_cropped%29.jpg	11
474	Devon Conway	1991-07-08	33	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Flag_of_New_Zealand.svg/23px-Flag_of_New_Zealand.svg.png	11
589	David Willey	1990-02-28	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/d/dc/David_Willey_%2851223172836%29_%28cropped%29.jpg/220px-David_Willey_%2851223172836%29_%28cropped%29.jpg	9
438	Shubman Gill	1999-09-08	26	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/Shubman_Gill.jpg/220px-Shubman_Gill.jpg	10
447	Mohammed Siraj	1994-03-13	26	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/a/ac/Mohammed_Siraj.jpg/220px-Mohammed_Siraj.jpg	10
605	Shardul Thakur	1991-12-16	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/en/thumb/4/41/Flag_of_India.svg/23px-Flag_of_India.svg.png	10
611	Colin Ackermann	1991-04-04	\N	0	0	0	Batsman	active	https:	18
617	Teja Nidamanuru	1994-08-22	\N	0	0	0	Batsman	active	https:	18
623	Saqib Zulfiqar	1997-03-28	\N	0	0	0	allrounder	active	https:	18
630	Lockie Ferguson	1991-06-13	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/1/1d/Lockie_Ferguson.jpg/220px-Lockie_Ferguson.jpg	11
637	Ish Sodhi	1992-10-31	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/5/52/2018.02.03.20.52.20-AUSvNZL_T20_NZL_innings%2C_SCG_%2838618201470%29_%28Sodhi_cropped%29.jpg/220px-2018.02.03.20.52.20-AUSvNZL_T20_NZL_innings%2C_SCG_%2838618201470%29_%28Sodhi_cropped%29.jpg	11
642	Shadab Khan	1998-10-04	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/b/ba/Shadab_Khan.png/220px-Shadab_Khan.png	24
648	Mohammad Nawaz	1994-03-21	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/32/Flag_of_Pakistan.svg/23px-Flag_of_Pakistan.svg.png	24
657	Keshav Maharaj	1990-02-07	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/New_face_6-_Keshav_Maharaj.jpg/220px-New_face_6-_Keshav_Maharaj.jpg	12
663	Aiden Markram	1994-10-04	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/c/ca/Aiden_Markram_%28cropped%29.jpg/220px-Aiden_Markram_%28cropped%29.jpg	12
670	Rassie van der Dussen	1989-02-07	\N	0	0	0	Batsman	active	https:	12
511	David Miller	1989-06-10	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/DAVID_MILLER_%2815704846295%29.jpg/220px-DAVID_MILLER_%2815704846295%29.jpg	12
493	Salman Ali Agha	1993-11-23	24	0	0	0	Batsman	active	https:	24
484	Tim Southee	1988-12-11	33	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a2/Tim_Southee_3.jpg/220px-Tim_Southee_3.jpg	11
439	Shreyas Iyer	1994-12-06	26	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/9/96/Shreyas_Iyer_2021.jpg/220px-Shreyas_Iyer_2021.jpg	10
475	Lockie Ferguson	1991-06-13	33	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/1/1d/Lockie_Ferguson.jpg/220px-Lockie_Ferguson.jpg	11
592	Reece Topley	1994-02-21	\N	0	0	0	Bowler	active	https:	9
602	K. L. Rahul	1992-04-18	\N	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/6/69/KL_Rahul_at_Femina_Miss_India_2018_Grand_Finale_%28cropped%29.jpg	10
608	Axar Patel	1994-01-20	\N	0	0	0	allrounder	active	https:	10
614	Bas de Leede	1999-11-15	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/1_02_Bas_de_Leede.jpg/220px-1_02_Bas_de_Leede.jpg	18
619	Vikramjit Singh	2003-01-09	\N	0	0	0	Batsman	active	https:	18
625	Kane Williamson	1990-08-08	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Kane_Williamson_in_2019.jpg/220px-Kane_Williamson_in_2019.jpg	11
631	Kyle Jamieson	1994-12-30	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/c/c8/Kyle_Jamieson_from_Back_Side.jpg/220px-Kyle_Jamieson_from_Back_Side.jpg	11
638	Tim Southee	1988-12-11	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a2/Tim_Southee_3.jpg/220px-Tim_Southee_3.jpg	11
502	Fakhar Zaman	1990-04-10	24	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Fakhar_Zaman%2C_Pakistan_vs_Sri_Lanka%2C_1st_ODI%2C_2017.jpg/220px-Fakhar_Zaman%2C_Pakistan_vs_Sri_Lanka%2C_1st_ODI%2C_2017.jpg	24
430	Mark Wood	1990-01-11	30	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/c/c0/Mark_wood_bowling_boxing_day_test.jpg/220px-Mark_wood_bowling_boxing_day_test.jpg	9
420	Gus Atkinson	1998-01-19	30	0	0	0	Bowler	active	https:	9
466	Paul van Meekeren	1993-01-15	31	0	0	0	Bowler	active	https:	18
457	Shariz Ahmad	2003-04-21	31	0	0	0	Bowler	active	https:	18
644	Ifitkhar Ahmed	1990-09-03	\N	0	0	0	Batsman	active	https:	24
651	Abdullah Shafique	1999-11-23	\N	0	0	0	Batsman	active	https:	24
658	Gerald Coetzee	2000-10-02	\N	0	0	0	Bowler	active	https:	12
665	Lungi Ngidi	1996-03-29	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f0/Lungi_Ngidi.jpg/220px-Lungi_Ngidi.jpg	12
673	Rahmanullah Gurbaz	2001-11-28	\N	0	0	0	batsman	active	https:	16
677	Mohammad Nabi	1985-01-01	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/4/49/Mohammad_Nabi-Australia.jpg/220px-Mohammad_Nabi-Australia.jpg	16
412	Shoriful Islam	2001-06-03	\N	0	0	0	Bowler	active	https:	8
422	Harry Brook	1999-02-22	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/4/49/Harry_Brook_%2851225504151%29_%28cropped%29.jpg/220px-Harry_Brook_%2851225504151%29_%28cropped%29.jpg	9
450	Suryakumar Yadav	1990-09-14	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/b/b7/Surya_Kumar_Yadav_in_BGT_2023.jpg/220px-Surya_Kumar_Yadav_in_BGT_2023.jpg	10
486	Matt Henry	1991-12-14	\N	0	0	0	Bowler	active	https:	11
504	Keshav Maharaj	1990-02-07	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/New_face_6-_Keshav_Maharaj.jpg/220px-New_face_6-_Keshav_Maharaj.jpg	12
459	Sybrand Engelbrecht	1988-09-15	31	0	0	0	Batsman	active	https:	18
610	Scott Edwards	1996-08-23	\N	0	0	0	batsman	active	https:	18
628	Mark Chapman	1994-06-27	\N	0	0	0	Batsman	active	https:	11
636	Mitchell Santner	1992-02-05	\N	0	0	0	allrounder	active	https:	11
643	Shaheen Afridi	2000-04-06	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/7/78/Shaheen_Afridi_%282%29.jpg/220px-Shaheen_Afridi_%282%29.jpg	24
652	Saud Shakeel	1995-09-05	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/e/e9/1_37_Saud_Shakeel.jpg/220px-1_37_Saud_Shakeel.jpg	24
660	Reeza Hendricks	1989-08-14	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/37/REEZA_HENDRICKS_%2815519916117%29.jpg/220px-REEZA_HENDRICKS_%2815519916117%29.jpg	12
667	Kagiso Rabada	1995-05-25	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/0/08/Rabada.jpg/220px-Rabada.jpg	12
679	Azmatullah Omarzai	2000-03-24	\N	0	0	0	allrounder	active	https:	16
413	Mahmudullah	1986-02-04	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Mahmudullah_Riyad_on_practice_session_%2816%29_%28cropped%29.jpg/220px-Mahmudullah_Riyad_on_practice_session_%2816%29_%28cropped%29.jpg	8
421	Jonny Bairstow	1989-09-26	\N	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/20150621-Jonny-Bairstow.jpg/220px-20150621-Jonny-Bairstow.jpg	9
449	Kuldeep Yadav	1994-12-11	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/en/thumb/4/41/Flag_of_India.svg/23px-Flag_of_India.svg.png	10
458	Wesley Barresi	1984-05-03	\N	0	0	0	Batsman	active	https:	18
476	Kyle Jamieson	1994-12-30	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/c/c8/Kyle_Jamieson_from_Back_Side.jpg/220px-Kyle_Jamieson_from_Back_Side.jpg	11
485	Will Young	1992-11-22	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/4/4b/1_52_Young_faces_Rauf_%28cropped%29.jpg/220px-1_52_Young_faces_Rauf_%28cropped%29.jpg	11
512	Lungi Ngidi	1996-03-29	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f0/Lungi_Ngidi.jpg/220px-Lungi_Ngidi.jpg	12
494	Usama Mir	1995-12-23	24	0	0	0	Bowler	active	https:	24
440	Ikram Alikhil	2000-11-28	28	0	0	0	batsman	active	https:	16
503	Temba Bavuma	1990-05-17	32	0	0	0	Batsman	active	https:	12
634	James Neesham	1990-09-17	\N	0	0	0	allrounder	active	https:	11
656	Temba Bavuma	1990-05-17	\N	0	0	0	Batsman	active	https:	12
664	David Miller	1989-06-10	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/DAVID_MILLER_%2815704846295%29.jpg/220px-DAVID_MILLER_%2815704846295%29.jpg	12
678	Rashid Khan	1998-09-20	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/7/71/Rashid_Khan.jpg/220px-Rashid_Khan.jpg	16
428	Adil Rashid	1988-02-17	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a3/1_13_Adil_Rashid_%28cropped%29.jpg/220px-1_13_Adil_Rashid_%28cropped%29.jpg	9
437	Jasprit Bumrah	1993-12-06	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/1/1c/Jasprit_Bumrah_%284%29.jpg/220px-Jasprit_Bumrah_%284%29.jpg	10
446	Mohammed Shami	1990-09-03	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/7/71/Mohammed_Shami.jpg/220px-Mohammed_Shami.jpg	10
455	Colin Ackermann	1991-04-04	\N	0	0	0	Batsman	active	https:	18
464	Vikramjit Singh	2003-01-09	\N	0	0	0	Batsman	active	https:	18
473	Mark Chapman	1994-06-27	\N	0	0	0	Batsman	active	https:	11
491	Ifitkhar Ahmed	1990-09-03	\N	0	0	0	Batsman	active	https:	24
500	Imam-ul-Haq	1995-12-12	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/0/02/Imam-ul-Haq%2C_Pakistan_vs_Sri_Lanka%2C_1st_ODI%2C_2017.jpg/220px-Imam-ul-Haq%2C_Pakistan_vs_Sri_Lanka%2C_1st_ODI%2C_2017.jpg	24
509	Heinrich Klaasen	1991-07-30	\N	0	0	0	batsman	active	https:	12
518	Sisanda Magala	1991-01-07	\N	0	0	0	Bowler	active	https:	12
482	Riaz Hassan	2002-11-07	28	0	0	0	Batsman	active	https:	16
647	Usama Mir	1995-12-23	\N	0	0	0	Bowler	active	https:	24
655	Fakhar Zaman	1990-04-10	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Fakhar_Zaman%2C_Pakistan_vs_Sri_Lanka%2C_1st_ODI%2C_2017.jpg/220px-Fakhar_Zaman%2C_Pakistan_vs_Sri_Lanka%2C_1st_ODI%2C_2017.jpg	24
662	Heinrich Klaasen	1991-07-30	\N	0	0	0	batsman	active	https:	12
669	Lizaad Williams	1993-10-01	\N	0	0	0	Bowler	active	https:	12
\.


--
-- Data for Name: playerrank; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.playerrank (playerid, battingrank, bowlingrank, allrounderrank) FROM stdin;
681	228	225	225
487	70	83	83
682	229	226	226
683	230	227	227
684	231	228	228
685	232	229	229
686	233	230	230
687	234	231	231
688	235	232	232
689	236	233	233
690	237	234	234
692	238	235	235
694	239	236	236
697	240	237	237
503	100	98	98
504	101	99	99
505	102	100	100
506	103	101	101
507	104	102	102
698	241	238	238
509	106	104	104
486	84	82	82
510	107	105	105
502	110	97	97
484	82	80	80
485	83	81	81
482	80	78	78
483	81	79	79
479	77	75	75
473	71	70	70
474	71	70	70
475	72	71	71
476	73	72	72
489	86	85	85
491	88	87	87
492	89	88	88
493	90	89	89
499	97	94	94
498	96	93	93
377	1	1	1
385	2	2	2
386	2	2	2
380	3	3	3
387	3	3	3
381	3	3	3
388	4	4	4
383	4	4	4
384	4	4	4
390	5	5	5
379	5	5	5
378	5	5	5
393	6	6	6
394	7	7	7
382	5	5	5
396	8	8	8
397	8	8	8
399	9	9	9
400	10	10	10
401	10	10	10
403	11	11	11
404	12	12	12
405	13	13	13
406	13	13	13
407	14	14	14
408	14	14	14
409	15	15	15
412	17	17	17
413	17	17	17
414	18	18	18
415	19	19	19
416	20	20	20
417	21	21	21
420	23	23	23
421	24	24	24
422	24	24	24
423	25	25	25
424	26	26	26
425	26	26	26
426	27	27	27
427	28	28	28
428	29	29	29
430	30	30	30
433	33	33	33
434	33	33	33
435	34	34	34
437	36	36	36
438	37	37	37
439	38	38	38
440	39	39	39
442	40	40	40
443	41	41	41
444	42	42	42
445	43	43	43
446	44	44	44
447	44	44	44
449	46	46	46
450	47	47	47
454	51	51	51
455	52	52	52
457	54	54	54
458	55	55	55
459	56	56	56
461	58	58	58
462	59	59	59
463	60	60	60
464	61	61	61
466	63	63	63
469	66	66	66
470	67	67	67
471	68	68	68
472	69	69	69
494	91	90	90
691	238	235	235
496	92	91	91
497	93	92	92
693	238	235	235
652	209	206	206
653	209	206	206
654	210	207	207
655	211	208	208
657	212	209	209
656	212	209	209
658	212	209	209
659	213	210	210
660	214	211	211
649	213	210	210
661	214	211	211
500	98	95	95
501	99	96	96
511	109	106	106
512	109	106	106
662	215	212	212
514	111	108	108
515	112	109	109
516	112	109	109
517	113	110	110
518	114	111	111
519	115	112	112
520	116	113	113
521	116	113	113
522	117	114	114
523	117	114	114
524	118	115	115
525	118	115	115
526	119	116	116
695	239	236	236
696	240	237	237
529	120	117	117
530	121	118	118
532	122	119	119
533	122	119	119
534	123	120	120
538	124	121	121
539	125	122	122
540	126	123	123
541	127	124	124
542	128	125	125
543	129	126	126
544	130	127	127
545	131	128	128
546	132	129	129
547	133	130	130
548	134	131	131
549	135	132	132
550	136	133	133
551	137	134	134
552	138	135	135
553	139	136	136
554	140	137	137
555	141	138	138
556	142	139	139
557	143	140	140
558	144	141	141
559	145	142	142
560	146	143	143
561	147	144	144
562	148	145	145
563	149	146	146
564	150	147	147
565	151	148	148
566	152	149	149
567	153	150	150
568	154	151	151
569	155	152	152
570	156	153	153
571	157	154	154
572	158	155	155
573	159	156	156
574	160	157	157
575	161	158	158
577	162	159	159
578	163	160	160
579	164	161	161
580	165	162	162
581	166	163	163
582	167	164	164
576	166	163	163
583	168	165	165
584	169	166	166
586	170	167	167
587	171	168	168
588	171	168	168
590	172	169	169
585	172	169	169
591	173	170	170
593	173	170	170
594	174	171	171
595	174	171	171
596	175	172	172
597	176	173	173
598	176	173	173
592	176	173	173
589	176	173	173
599	177	174	174
600	177	174	174
601	178	175	175
602	178	175	175
603	179	176	176
604	180	177	177
605	180	177	177
606	181	178	178
607	182	179	179
608	183	180	180
609	183	180	180
612	184	181	181
611	184	181	181
613	185	182	182
614	186	183	183
615	186	183	183
616	186	183	183
617	187	184	184
618	187	184	184
620	188	185	185
619	188	185	185
610	188	185	185
621	189	186	186
622	190	187	187
623	191	188	188
624	191	188	188
625	192	189	189
626	192	189	189
627	193	190	190
629	194	191	191
628	194	191	191
630	195	192	192
631	195	192	192
632	196	193	193
633	196	193	193
635	197	194	194
636	198	195	195
637	198	195	195
638	199	196	196
639	199	196	196
640	200	197	197
641	201	198	198
642	202	199	199
644	203	200	200
634	201	198	198
643	203	200	200
645	204	201	201
646	205	202	202
647	206	203	203
648	207	204	204
651	208	205	205
650	214	211	211
663	215	212	212
665	216	213	213
664	216	213	213
666	216	213	213
667	217	214	214
668	218	215	215
669	219	216	216
670	220	217	217
671	221	218	218
672	221	218	218
673	222	219	219
674	223	220	220
675	223	220	220
676	224	221	221
677	225	222	222
678	226	223	223
679	227	224	224
680	227	224	224
\.


--
-- Data for Name: scorecard; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.scorecard (matchid, playerid, noruns, nosixes, nofours, noballsfaced, nowickets, oversbowled, maidenovers, runsconceded, extras, noballs) FROM stdin;
\.


--
-- Data for Name: team; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.team (teamid, teamname, coachid, captainid, teampicpath, totalwins, totallosses, draws, wicketkeeperid) FROM stdin;
30	England	13	417	http://localhost:3000/1704256896219_eng.png	\N	\N	\N	417
31	Netherlands	16	454	http://localhost:3000/1704256951686_ned.png	\N	\N	\N	454
32	South Africa	18	503	http://localhost:3000/1704257056571_sa.jpg	\N	\N	\N	506
33	New Zealand	17	470	http://localhost:3000/1704257182437_nz.png	\N	\N	\N	471
34	Sri Lanka	15	520	http://localhost:3000/1704260138724_sri.png	\N	\N	\N	520
26	India	12	443	http://localhost:3000/1704133826892_india.png	\N	\N	\N	445
27	Australia	11	385	http://localhost:3000/1704252659457_aus.jpeg	\N	\N	\N	390
24	Pakistan	9	487	http://localhost:3000/1704130636982_pak.png	\N	\N	\N	497
28	Afghanistan	10	379	http://localhost:3000/1704256678381_afg.png	\N	\N	\N	433
29	Bangladesh	19	403	http://localhost:3000/1704256790030_bangladesh.png	\N	\N	\N	415
\.


--
-- Data for Name: teamrank; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.teamrank (teamid, t20irank, odirank, testrank) FROM stdin;
24	1	1	1
26	2	2	2
27	3	3	3
28	4	4	4
29	5	5	5
30	6	6	6
31	7	7	7
32	8	8	8
33	9	9	9
34	10	10	10
\.


--
-- Data for Name: tournament; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tournament (name, startdate, enddate, winning_team, winningpic, tournamentlogo, tournamentid) FROM stdin;
World Cup 2023	2023-10-05 00:00:00	2023-12-11 00:00:00	27	http://localhost:3000/1704252772019_win.jpeg	http://localhost:3000/1704252706526_aus.jpeg	37
World Cup 2022	2022-10-16 00:00:00	2022-11-13 00:00:00	30	http://localhost:3000/1704260502866_2022.webp	http://localhost:3000/1704260523152_2022logo.png	38
World Cup 2021	2021-10-17 00:00:00	2021-11-14 00:00:00	27	http://localhost:3000/1704260606760_2021.webp	http://localhost:3000/1704260582111_2021logo.svg	39
World Cup 2019	2019-05-30 00:00:00	2019-07-14 00:00:00	30	http://localhost:3000/1704260749443_2019.webp	http://localhost:3000/1704260753504_2019logo.webp	40
\.


--
-- Data for Name: umpire; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.umpire (umpirename, nomatches, umpirepicpath, countryid, umpireid) FROM stdin;
Richard Illingworth	0	http://localhost:3000/1704258338191_richard.webp	9	7
Richard Kettleborough	0	http://localhost:3000/1704258403923_kettle.webp	9	8
Nitin Menon	0	http://localhost:3000/1704258438196_menon.webp	10	9
Ahsan Raza	0	http://localhost:3000/1704258463169_ahsan.webp	24	10
Paul Reiffel	0	http://localhost:3000/1704258487608_paul.webp	7	11
Rod Tucker	0	http://localhost:3000/1704258518788_rod.webp	7	12
Joel Wilson	0	http://localhost:3000/1704258572543_joel.webp	14	14
Chris Brown	0	http://localhost:3000/1704258658584_brown.jpg	11	15
Sharfuddoula	0	http://localhost:3000/1704258685558_sharf.jpg	8	16
Alex Wharf	0	http://localhost:3000/1704258721237_alex.webp	9	17
Paul Wilson	0	http://localhost:3000/1704258752018_wilson.webp	7	18
Kumar Dharmasena	0	http://localhost:3000/1704258020393_kumar.webp	13	2
Marais Erasmus	0	http://localhost:3000/1704258077524_marais.webp	12	3
Chris Gaffaney	0	http://localhost:3000/1704258120432_chris gaffaney.jpg	11	4
Michael Gough	0	http://localhost:3000/1704258231452_gough.jpg	9	5
Adrian Holdstock	0	http://localhost:3000/1704258276338_adrian.jpg	12	6
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (userid, username, userpicpath, userrole, password, datejoined, hashed_password) FROM stdin;
26	abddulrehman	http://localhost:3000/1703943986874_profile.jpg	Admin	12345678	2023-12-30	\N
32	qwerty	http://localhost:3000/1703953654489_screenShot.jpg	tournamentmanager	12345678	2023-12-30	\N
35	check2	http://localhost:3000/1703960047154_unsplash.png	datamanager	12345678	2023-12-30	\N
36	abbas	http://localhost:3000/1704001436796_screenShot.jpg	playermanager	12345678	2023-12-31	\N
37	arman	http://localhost:3000/1704023733584_unsplash.png	teammanager	12345678	2023-12-31	\N
41	abddulrehmann	http://localhost:3000/1703943986874_profile.jpg	admin	12345678	2023-12-31	$2b$10$nrQZdj85RolKxQSOW/f5NeRVcciGMkzVmSPwiNQmrLUNF6jKpdYRS
42	abddulrehhmann	http://localhost:3000/1703943986874_profile.jpg	admin	$2b$10$JIg7jxS3sm7cUwMtv0odZeIVriuso.jcW08U3PhiiKwX2H6dA6bF.	2023-12-31	$2b$10$JIg7jxS3sm7cUwMtv0odZeIVriuso.jcW08U3PhiiKwX2H6dA6bF.
43	faakhir	http://localhost:3000/1704036997285_screenShot.jpg	admin	$2b$10$IN2vXPR8aSNelyGCrz4BEOzT.OQrJu60USPe1kOf3382P56mQc0gW	2023-12-31	$2b$10$IN2vXPR8aSNelyGCrz4BEOzT.OQrJu60USPe1kOf3382P56mQc0gW
44	ibad	http://localhost:3000/1704037074430_screenShot.jpg	playermanager	$2b$10$24fprNsJkx0SxEnukoX0zelOZWXsTtiZd7Lrt2YujQzb6pRQN4n4K	2023-12-31	$2b$10$24fprNsJkx0SxEnukoX0zelOZWXsTtiZd7Lrt2YujQzb6pRQN4n4K
45	insertion	http://localhost:3000/1704078683108_unsplash.png	datamanager	$2b$10$hDtqMcXAFDHWhYSAFkNcHedOZ64P3ZLjButcaDWcqF2yxzeDLbiWe	2024-01-01	$2b$10$hDtqMcXAFDHWhYSAFkNcHedOZ64P3ZLjButcaDWcqF2yxzeDLbiWe
\.


--
-- Data for Name: wicketkeeper; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.wicketkeeper (totalcatches, totalstumps, playerid) FROM stdin;
0	0	440
0	0	442
0	0	454
0	0	471
0	0	474
0	0	506
0	0	509
0	0	390
0	0	421
0	0	387
0	0	433
0	0	415
0	0	406
0	0	417
0	0	404
4	4	445
2	4	497
0	0	523
0	0	525
0	0	520
\.


--
-- Name: coach_coachid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.coach_coachid_seq', 19, true);


--
-- Name: country_countryid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.country_countryid_seq', 18, true);


--
-- Name: location_locationid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.location_locationid_seq', 29, true);


--
-- Name: match_matchid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.match_matchid_seq', 41, true);


--
-- Name: player_playerid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.player_playerid_seq', 698, true);


--
-- Name: team_teamid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.team_teamid_seq', 34, true);


--
-- Name: tournament_tournamentid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tournament_tournamentid_seq', 40, true);


--
-- Name: umpire_umpireid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.umpire_umpireid_seq', 18, true);


--
-- Name: users_userid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_userid_seq', 45, true);


--
-- Name: coach coach_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coach
    ADD CONSTRAINT coach_pkey PRIMARY KEY (coachid);


--
-- Name: country country_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.country
    ADD CONSTRAINT country_pkey PRIMARY KEY (countryid);


--
-- Name: location location_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.location
    ADD CONSTRAINT location_pkey PRIMARY KEY (locationid);


--
-- Name: match match_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match
    ADD CONSTRAINT match_pkey PRIMARY KEY (matchid);


--
-- Name: batsman p__key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.batsman
    ADD CONSTRAINT p__key PRIMARY KEY (playerid);


--
-- Name: wicketkeeper p_k; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wicketkeeper
    ADD CONSTRAINT p_k PRIMARY KEY (playerid);


--
-- Name: bowler p_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bowler
    ADD CONSTRAINT p_key PRIMARY KEY (playerid);


--
-- Name: captain p_kk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.captain
    ADD CONSTRAINT p_kk PRIMARY KEY (playerid);


--
-- Name: player player_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player
    ADD CONSTRAINT player_pkey PRIMARY KEY (playerid);


--
-- Name: playerrank playerrank_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.playerrank
    ADD CONSTRAINT playerrank_pkey PRIMARY KEY (playerid);


--
-- Name: scorecard scorecard_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scorecard
    ADD CONSTRAINT scorecard_pkey PRIMARY KEY (matchid, playerid);


--
-- Name: team team_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT team_pkey PRIMARY KEY (teamid);


--
-- Name: teamrank teamrank_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teamrank
    ADD CONSTRAINT teamrank_pkey PRIMARY KEY (teamid);


--
-- Name: tournament tournament_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tournament
    ADD CONSTRAINT tournament_pkey PRIMARY KEY (tournamentid);


--
-- Name: umpire umpire_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.umpire
    ADD CONSTRAINT umpire_pkey PRIMARY KEY (umpireid);


--
-- Name: team unique_captainid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT unique_captainid UNIQUE (captainid);


--
-- Name: team unique_coachid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT unique_coachid UNIQUE (coachid);


--
-- Name: country unique_coounty; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.country
    ADD CONSTRAINT unique_coounty UNIQUE (country);


--
-- Name: team unique_wicketkeeperid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT unique_wicketkeeperid UNIQUE (wicketkeeperid);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (userid);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: match match_creation; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER match_creation BEFORE INSERT ON public.match FOR EACH STATEMENT EXECUTE FUNCTION public.match_creation();


--
-- Name: match match_delete_trig; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER match_delete_trig BEFORE DELETE ON public.match FOR EACH STATEMENT EXECUTE FUNCTION public.match_delete();


--
-- Name: player player_deletion; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER player_deletion BEFORE DELETE ON public.player FOR EACH ROW EXECUTE FUNCTION public.player_deletion();


--
-- Name: player player_insertion; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER player_insertion AFTER INSERT ON public.player FOR EACH ROW EXECUTE FUNCTION public.player_insertion();


--
-- Name: playerrank player_rank_insertion_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER player_rank_insertion_trigger BEFORE INSERT ON public.playerrank FOR EACH ROW EXECUTE FUNCTION public.player_rank_insertion();


--
-- Name: scorecard scorecard_insertion; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER scorecard_insertion AFTER INSERT ON public.scorecard FOR EACH ROW EXECUTE FUNCTION public.scorecard_insertion();


--
-- Name: users set_password_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER set_password_trigger AFTER INSERT ON public.users FOR EACH ROW EXECUTE FUNCTION public.set_password();


--
-- Name: team team_after_insertion; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER team_after_insertion AFTER INSERT ON public.team FOR EACH ROW EXECUTE FUNCTION public.team_after_insertion();


--
-- Name: team team_captainid_check; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER team_captainid_check BEFORE UPDATE ON public.team FOR EACH ROW EXECUTE FUNCTION public.team_captainid_check();


--
-- Name: team team_coachid_check; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER team_coachid_check BEFORE UPDATE ON public.team FOR EACH ROW EXECUTE FUNCTION public.team_coachid_check();


--
-- Name: team team_deletion; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER team_deletion BEFORE DELETE ON public.team FOR EACH ROW EXECUTE FUNCTION public.team_deletion();


--
-- Name: team team_insertion; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER team_insertion BEFORE INSERT ON public.team FOR EACH ROW EXECUTE FUNCTION public.team_insertion();


--
-- Name: teamrank team_rank_insertion_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER team_rank_insertion_trigger BEFORE INSERT ON public.teamrank FOR EACH ROW EXECUTE FUNCTION public.team_rank_insertion();


--
-- Name: teamrank team_rank_updation; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER team_rank_updation AFTER UPDATE ON public.teamrank FOR EACH ROW EXECUTE FUNCTION public.team_rank_updation();


--
-- Name: team team_wicketkeeperid_check; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER team_wicketkeeperid_check BEFORE UPDATE ON public.team FOR EACH ROW EXECUTE FUNCTION public.team_wicketkeeperid_check();


--
-- Name: tournament tournament_deletion; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tournament_deletion BEFORE DELETE ON public.tournament FOR EACH ROW EXECUTE FUNCTION public.tournament_deletion();


--
-- Name: match umpire_match_increase; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER umpire_match_increase AFTER INSERT ON public.match FOR EACH ROW EXECUTE FUNCTION public.match_insertion();


--
-- Name: users user_creation_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER user_creation_trigger BEFORE INSERT ON public.users FOR EACH ROW EXECUTE FUNCTION public.user_creation();


--
-- Name: users user_deletion_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER user_deletion_trigger BEFORE DELETE ON public.users FOR EACH ROW EXECUTE FUNCTION public.user_deletion();


--
-- Name: batsman batsman_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.batsman
    ADD CONSTRAINT batsman_fk FOREIGN KEY (playerid) REFERENCES public.player(playerid) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: bowler bowler_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bowler
    ADD CONSTRAINT bowler_fk FOREIGN KEY (playerid) REFERENCES public.player(playerid) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: captain captain_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.captain
    ADD CONSTRAINT captain_fk FOREIGN KEY (playerid) REFERENCES public.player(playerid) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: player country_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player
    ADD CONSTRAINT country_fk FOREIGN KEY (countryid) REFERENCES public.country(countryid) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: umpire country_key; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.umpire
    ADD CONSTRAINT country_key FOREIGN KEY (countryid) REFERENCES public.country(countryid);


--
-- Name: team cptn_key; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT cptn_key FOREIGN KEY (captainid) REFERENCES public.captain(playerid);


--
-- Name: wicketkeeper f_k; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wicketkeeper
    ADD CONSTRAINT f_k FOREIGN KEY (playerid) REFERENCES public.player(playerid) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: match match_fk1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match
    ADD CONSTRAINT match_fk1 FOREIGN KEY (team1id) REFERENCES public.team(teamid) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: match match_fk2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match
    ADD CONSTRAINT match_fk2 FOREIGN KEY (team2id) REFERENCES public.team(teamid) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: match match_fk3; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match
    ADD CONSTRAINT match_fk3 FOREIGN KEY (tournamentid) REFERENCES public.tournament(tournamentid) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: match match_fk4; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match
    ADD CONSTRAINT match_fk4 FOREIGN KEY (winnerteam) REFERENCES public.team(teamid) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: match match_fk5; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match
    ADD CONSTRAINT match_fk5 FOREIGN KEY (locationid) REFERENCES public.location(locationid);


--
-- Name: match match_fk6; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match
    ADD CONSTRAINT match_fk6 FOREIGN KEY (umpire) REFERENCES public.umpire(umpireid) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: tournament my_const; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tournament
    ADD CONSTRAINT my_const FOREIGN KEY (winning_team) REFERENCES public.team(teamid) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: player player_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player
    ADD CONSTRAINT player_fk FOREIGN KEY (teamid) REFERENCES public.team(teamid) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: playerrank playerrank_fk1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.playerrank
    ADD CONSTRAINT playerrank_fk1 FOREIGN KEY (playerid) REFERENCES public.player(playerid) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: scorecard scorecard_fk1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scorecard
    ADD CONSTRAINT scorecard_fk1 FOREIGN KEY (matchid) REFERENCES public.match(matchid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: scorecard scorecard_fk2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scorecard
    ADD CONSTRAINT scorecard_fk2 FOREIGN KEY (playerid) REFERENCES public.player(playerid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: team team_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT team_fk FOREIGN KEY (coachid) REFERENCES public.coach(coachid) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: teamrank teamrank_fk1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teamrank
    ADD CONSTRAINT teamrank_fk1 FOREIGN KEY (teamid) REFERENCES public.team(teamid);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO abdrehman6224;
GRANT USAGE ON SCHEMA public TO abdrehman;
GRANT USAGE ON SCHEMA public TO abddulrehman;
GRANT USAGE ON SCHEMA public TO qwerty;
GRANT USAGE ON SCHEMA public TO check2;
GRANT USAGE ON SCHEMA public TO abbas;
GRANT USAGE ON SCHEMA public TO arman;
GRANT USAGE ON SCHEMA public TO abddulrehmann;
GRANT USAGE ON SCHEMA public TO abddulrehhmann;
GRANT USAGE ON SCHEMA public TO faakhir;
GRANT USAGE ON SCHEMA public TO ibad;
GRANT USAGE ON SCHEMA public TO insertion;


--
-- Name: TABLE batsman; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.batsman TO playermanager;
GRANT ALL ON TABLE public.batsman TO admin;
GRANT INSERT ON TABLE public.batsman TO datamanager;


--
-- Name: TABLE bowler; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.bowler TO playermanager;
GRANT ALL ON TABLE public.bowler TO admin;
GRANT INSERT ON TABLE public.bowler TO datamanager;


--
-- Name: TABLE player; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.player TO playermanager;
GRANT ALL ON TABLE public.player TO admin;
GRANT INSERT ON TABLE public.player TO datamanager;


--
-- Name: TABLE allrounder_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.allrounder_view TO playermanager;
GRANT SELECT ON TABLE public.allrounder_view TO admin;


--
-- Name: TABLE batsman_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.batsman_view TO playermanager;
GRANT SELECT ON TABLE public.batsman_view TO admin;


--
-- Name: TABLE bowler_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.bowler_view TO playermanager;
GRANT SELECT ON TABLE public.bowler_view TO admin;


--
-- Name: TABLE captain; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.captain TO teammanager;
GRANT ALL ON TABLE public.captain TO admin;
GRANT INSERT ON TABLE public.captain TO datamanager;


--
-- Name: TABLE captain_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.captain_view TO teammanager;
GRANT SELECT ON TABLE public.captain_view TO admin;


--
-- Name: TABLE coach; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.coach TO teammanager;
GRANT ALL ON TABLE public.coach TO admin;
GRANT INSERT ON TABLE public.coach TO datamanager;


--
-- Name: SEQUENCE coach_coachid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public.coach_coachid_seq TO abddulrehman;
GRANT ALL ON SEQUENCE public.coach_coachid_seq TO admin;
GRANT ALL ON SEQUENCE public.coach_coachid_seq TO playermanager;
GRANT ALL ON SEQUENCE public.coach_coachid_seq TO teammanager;
GRANT ALL ON SEQUENCE public.coach_coachid_seq TO tournamentmanager;
GRANT SELECT ON SEQUENCE public.coach_coachid_seq TO qwerty;
GRANT ALL ON SEQUENCE public.coach_coachid_seq TO datamanager;
GRANT SELECT ON SEQUENCE public.coach_coachid_seq TO check2;
GRANT SELECT ON SEQUENCE public.coach_coachid_seq TO abbas;
GRANT SELECT ON SEQUENCE public.coach_coachid_seq TO arman;
GRANT SELECT ON SEQUENCE public.coach_coachid_seq TO abddulrehmann;
GRANT SELECT ON SEQUENCE public.coach_coachid_seq TO abddulrehhmann;
GRANT SELECT ON SEQUENCE public.coach_coachid_seq TO faakhir;
GRANT SELECT ON SEQUENCE public.coach_coachid_seq TO ibad;
GRANT SELECT ON SEQUENCE public.coach_coachid_seq TO insertion;


--
-- Name: TABLE team; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.team TO admin;
GRANT INSERT ON TABLE public.team TO datamanager;
GRANT ALL ON TABLE public.team TO teammanager;


--
-- Name: TABLE coach_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.coach_view TO teammanager;
GRANT SELECT ON TABLE public.coach_view TO admin;


--
-- Name: TABLE country; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.country TO admin;
GRANT INSERT ON TABLE public.country TO datamanager;


--
-- Name: SEQUENCE country_countryid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public.country_countryid_seq TO abddulrehman;
GRANT ALL ON SEQUENCE public.country_countryid_seq TO admin;
GRANT ALL ON SEQUENCE public.country_countryid_seq TO playermanager;
GRANT ALL ON SEQUENCE public.country_countryid_seq TO teammanager;
GRANT ALL ON SEQUENCE public.country_countryid_seq TO tournamentmanager;
GRANT USAGE,UPDATE ON SEQUENCE public.country_countryid_seq TO d;
GRANT SELECT ON SEQUENCE public.country_countryid_seq TO qwerty;
GRANT ALL ON SEQUENCE public.country_countryid_seq TO datamanager;
GRANT SELECT ON SEQUENCE public.country_countryid_seq TO check2;
GRANT SELECT ON SEQUENCE public.country_countryid_seq TO abbas;
GRANT SELECT ON SEQUENCE public.country_countryid_seq TO arman;
GRANT SELECT ON SEQUENCE public.country_countryid_seq TO abddulrehmann;
GRANT SELECT ON SEQUENCE public.country_countryid_seq TO abddulrehhmann;
GRANT SELECT ON SEQUENCE public.country_countryid_seq TO faakhir;
GRANT SELECT ON SEQUENCE public.country_countryid_seq TO ibad;
GRANT SELECT ON SEQUENCE public.country_countryid_seq TO insertion;


--
-- Name: TABLE users; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.users TO admin;
GRANT INSERT ON TABLE public.users TO datamanager;


--
-- Name: TABLE location; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.location TO admin;
GRANT INSERT ON TABLE public.location TO datamanager;


--
-- Name: SEQUENCE location_locationid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public.location_locationid_seq TO abddulrehman;
GRANT ALL ON SEQUENCE public.location_locationid_seq TO admin;
GRANT ALL ON SEQUENCE public.location_locationid_seq TO playermanager;
GRANT ALL ON SEQUENCE public.location_locationid_seq TO teammanager;
GRANT ALL ON SEQUENCE public.location_locationid_seq TO tournamentmanager;
GRANT USAGE,UPDATE ON SEQUENCE public.location_locationid_seq TO d;
GRANT SELECT ON SEQUENCE public.location_locationid_seq TO qwerty;
GRANT ALL ON SEQUENCE public.location_locationid_seq TO datamanager;
GRANT SELECT ON SEQUENCE public.location_locationid_seq TO check2;
GRANT SELECT ON SEQUENCE public.location_locationid_seq TO abbas;
GRANT SELECT ON SEQUENCE public.location_locationid_seq TO arman;
GRANT SELECT ON SEQUENCE public.location_locationid_seq TO abddulrehmann;
GRANT SELECT ON SEQUENCE public.location_locationid_seq TO abddulrehhmann;
GRANT SELECT ON SEQUENCE public.location_locationid_seq TO faakhir;
GRANT SELECT ON SEQUENCE public.location_locationid_seq TO ibad;
GRANT SELECT ON SEQUENCE public.location_locationid_seq TO insertion;


--
-- Name: TABLE match; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.match TO admin;
GRANT ALL ON TABLE public.match TO tournamentmanager;
GRANT INSERT ON TABLE public.match TO datamanager;


--
-- Name: SEQUENCE match_matchid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public.match_matchid_seq TO abddulrehman;
GRANT ALL ON SEQUENCE public.match_matchid_seq TO admin;
GRANT ALL ON SEQUENCE public.match_matchid_seq TO playermanager;
GRANT ALL ON SEQUENCE public.match_matchid_seq TO teammanager;
GRANT ALL ON SEQUENCE public.match_matchid_seq TO tournamentmanager;
GRANT USAGE,UPDATE ON SEQUENCE public.match_matchid_seq TO d;
GRANT SELECT ON SEQUENCE public.match_matchid_seq TO qwerty;
GRANT ALL ON SEQUENCE public.match_matchid_seq TO datamanager;
GRANT SELECT ON SEQUENCE public.match_matchid_seq TO check2;
GRANT SELECT ON SEQUENCE public.match_matchid_seq TO abbas;
GRANT SELECT ON SEQUENCE public.match_matchid_seq TO arman;
GRANT SELECT ON SEQUENCE public.match_matchid_seq TO abddulrehmann;
GRANT SELECT ON SEQUENCE public.match_matchid_seq TO abddulrehhmann;
GRANT SELECT ON SEQUENCE public.match_matchid_seq TO faakhir;
GRANT SELECT ON SEQUENCE public.match_matchid_seq TO ibad;
GRANT SELECT ON SEQUENCE public.match_matchid_seq TO insertion;


--
-- Name: TABLE umpire; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.umpire TO admin;
GRANT ALL ON TABLE public.umpire TO tournamentmanager;
GRANT INSERT ON TABLE public.umpire TO datamanager;


--
-- Name: TABLE match_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.match_view TO tournamentmanager;
GRANT SELECT ON TABLE public.match_view TO admin;


--
-- Name: SEQUENCE player_playerid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public.player_playerid_seq TO abddulrehman;
GRANT ALL ON SEQUENCE public.player_playerid_seq TO admin;
GRANT ALL ON SEQUENCE public.player_playerid_seq TO playermanager;
GRANT ALL ON SEQUENCE public.player_playerid_seq TO teammanager;
GRANT ALL ON SEQUENCE public.player_playerid_seq TO tournamentmanager;
GRANT USAGE,UPDATE ON SEQUENCE public.player_playerid_seq TO d;
GRANT SELECT ON SEQUENCE public.player_playerid_seq TO qwerty;
GRANT ALL ON SEQUENCE public.player_playerid_seq TO datamanager;
GRANT SELECT ON SEQUENCE public.player_playerid_seq TO check2;
GRANT SELECT ON SEQUENCE public.player_playerid_seq TO abbas;
GRANT SELECT ON SEQUENCE public.player_playerid_seq TO arman;
GRANT SELECT ON SEQUENCE public.player_playerid_seq TO abddulrehmann;
GRANT SELECT ON SEQUENCE public.player_playerid_seq TO abddulrehhmann;
GRANT SELECT ON SEQUENCE public.player_playerid_seq TO faakhir;
GRANT SELECT ON SEQUENCE public.player_playerid_seq TO ibad;
GRANT SELECT ON SEQUENCE public.player_playerid_seq TO insertion;


--
-- Name: TABLE playerrank; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.playerrank TO admin;
GRANT INSERT ON TABLE public.playerrank TO datamanager;


--
-- Name: TABLE player_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.player_view TO playermanager;
GRANT SELECT ON TABLE public.player_view TO admin;


--
-- Name: TABLE playerrank_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.playerrank_view TO playermanager;
GRANT SELECT ON TABLE public.playerrank_view TO admin;


--
-- Name: TABLE scorecard; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.scorecard TO admin;
GRANT INSERT ON TABLE public.scorecard TO datamanager;


--
-- Name: TABLE scorecard_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.scorecard_view TO playermanager;
GRANT SELECT ON TABLE public.scorecard_view TO tournamentmanager;
GRANT SELECT ON TABLE public.scorecard_view TO admin;


--
-- Name: SEQUENCE team_teamid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public.team_teamid_seq TO abddulrehman;
GRANT ALL ON SEQUENCE public.team_teamid_seq TO admin;
GRANT ALL ON SEQUENCE public.team_teamid_seq TO playermanager;
GRANT ALL ON SEQUENCE public.team_teamid_seq TO teammanager;
GRANT ALL ON SEQUENCE public.team_teamid_seq TO tournamentmanager;
GRANT USAGE,UPDATE ON SEQUENCE public.team_teamid_seq TO d;
GRANT SELECT ON SEQUENCE public.team_teamid_seq TO qwerty;
GRANT ALL ON SEQUENCE public.team_teamid_seq TO datamanager;
GRANT SELECT ON SEQUENCE public.team_teamid_seq TO check2;
GRANT SELECT ON SEQUENCE public.team_teamid_seq TO abbas;
GRANT SELECT ON SEQUENCE public.team_teamid_seq TO arman;
GRANT SELECT ON SEQUENCE public.team_teamid_seq TO abddulrehmann;
GRANT SELECT ON SEQUENCE public.team_teamid_seq TO abddulrehhmann;
GRANT SELECT ON SEQUENCE public.team_teamid_seq TO faakhir;
GRANT SELECT ON SEQUENCE public.team_teamid_seq TO ibad;
GRANT SELECT ON SEQUENCE public.team_teamid_seq TO insertion;


--
-- Name: TABLE teamrank; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.teamrank TO admin;
GRANT INSERT ON TABLE public.teamrank TO datamanager;


--
-- Name: TABLE team_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.team_view TO teammanager;
GRANT SELECT ON TABLE public.team_view TO admin;


--
-- Name: TABLE teamrank_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.teamrank_view TO teammanager;
GRANT SELECT ON TABLE public.teamrank_view TO admin;


--
-- Name: TABLE tournament; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.tournament TO admin;
GRANT ALL ON TABLE public.tournament TO tournamentmanager;
GRANT INSERT ON TABLE public.tournament TO datamanager;


--
-- Name: SEQUENCE tournament_tournamentid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public.tournament_tournamentid_seq TO abddulrehman;
GRANT ALL ON SEQUENCE public.tournament_tournamentid_seq TO admin;
GRANT ALL ON SEQUENCE public.tournament_tournamentid_seq TO playermanager;
GRANT ALL ON SEQUENCE public.tournament_tournamentid_seq TO teammanager;
GRANT ALL ON SEQUENCE public.tournament_tournamentid_seq TO tournamentmanager;
GRANT SELECT ON SEQUENCE public.tournament_tournamentid_seq TO qwerty;
GRANT ALL ON SEQUENCE public.tournament_tournamentid_seq TO datamanager;
GRANT SELECT ON SEQUENCE public.tournament_tournamentid_seq TO check2;
GRANT SELECT ON SEQUENCE public.tournament_tournamentid_seq TO abbas;
GRANT SELECT ON SEQUENCE public.tournament_tournamentid_seq TO arman;
GRANT SELECT ON SEQUENCE public.tournament_tournamentid_seq TO abddulrehmann;
GRANT SELECT ON SEQUENCE public.tournament_tournamentid_seq TO abddulrehhmann;
GRANT SELECT ON SEQUENCE public.tournament_tournamentid_seq TO faakhir;
GRANT SELECT ON SEQUENCE public.tournament_tournamentid_seq TO ibad;
GRANT SELECT ON SEQUENCE public.tournament_tournamentid_seq TO insertion;


--
-- Name: TABLE tournament_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.tournament_view TO tournamentmanager;
GRANT SELECT ON TABLE public.tournament_view TO admin;


--
-- Name: SEQUENCE umpire_umpireid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public.umpire_umpireid_seq TO insertion;


--
-- Name: TABLE umpire_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.umpire_view TO tournamentmanager;
GRANT SELECT ON TABLE public.umpire_view TO admin;


--
-- Name: SEQUENCE users_userid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public.users_userid_seq TO abddulrehman;
GRANT ALL ON SEQUENCE public.users_userid_seq TO admin;
GRANT ALL ON SEQUENCE public.users_userid_seq TO playermanager;
GRANT ALL ON SEQUENCE public.users_userid_seq TO teammanager;
GRANT ALL ON SEQUENCE public.users_userid_seq TO tournamentmanager;
GRANT SELECT ON SEQUENCE public.users_userid_seq TO qwerty;
GRANT ALL ON SEQUENCE public.users_userid_seq TO datamanager;
GRANT SELECT ON SEQUENCE public.users_userid_seq TO check2;
GRANT SELECT ON SEQUENCE public.users_userid_seq TO abbas;
GRANT SELECT ON SEQUENCE public.users_userid_seq TO arman;
GRANT SELECT ON SEQUENCE public.users_userid_seq TO abddulrehmann;
GRANT SELECT ON SEQUENCE public.users_userid_seq TO abddulrehhmann;
GRANT SELECT ON SEQUENCE public.users_userid_seq TO faakhir;
GRANT SELECT ON SEQUENCE public.users_userid_seq TO ibad;
GRANT SELECT ON SEQUENCE public.users_userid_seq TO insertion;


--
-- Name: TABLE wicketkeeper; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.wicketkeeper TO teammanager;
GRANT ALL ON TABLE public.wicketkeeper TO admin;
GRANT INSERT ON TABLE public.wicketkeeper TO datamanager;


--
-- Name: TABLE wicketkeeper_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.wicketkeeper_view TO teammanager;
GRANT SELECT ON TABLE public.wicketkeeper_view TO admin;


--
-- PostgreSQL database dump complete
--

