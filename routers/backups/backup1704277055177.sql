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
700	0	0	0	Right	0	0
688	0	0	0	Right	0	0
520	30	70	610	Right	385	5
523	8	115	687	Left	692	33
525	9	106	1129	Right	1175	30
687	0	5	60	Left	89	14
691	0	5	20	Right	20	10
521	39	68	1025	Left	1251	31
522	15	220	1658	Right	1844	43
533	19	62	670	Left	882	38
697	0	0	0	Right	5	5
696	0	3	45	Right	63	8
698	3	12	161	Right	257	26
553	113	217	2255	Right	2107	48
552	6	114	1351	Right	1984	39
554	90	168	1643	Right	1088	50
635	91	288	3030	Left	2800	49
598	15	35	591	Left	568	50
560	0	0	0	Left	0	0
570	0	0	0	Right	0	0
548	0	18	181	Right	229	11
569	0	9	149	Right	330	13
557	16	34	365	Right	321	34
588	37	73	966	Left	1163	23
590	10	75	670	Right	796	41
578	2	37	402	Left	540	37
576	0	0	0	Left	0	0
594	0	0	0	Right	0	2
620	12	38	524	Right	646	48
622	11	13	233	Right	300	47
661	44	45	773	Right	702	43
396	0	0	0	Right	0	0
403	4	88	764	Left	969	32
666	12	4	156	Left	148	5
438	54	194	1647	Right	1556	43
474	23	263	1900	Left	1763	41
632	99	221	2535	Right	2288	42
380	10	120	1354	Right	1712	35
609	4	0	44	Right	32	18
510	31	102	1023	Right	921	35
387	0	0	0	Left	0	0
390	0	0	0	Right	0	0
454	0	0	0	Right	0	0
463	0	0	0	Left	0	0
445	1	1	23	Right	23	1
425	0	27	278	Right	433	37
427	6	63	815	Right	964	36
589	23	27	305	Left	282	35
499	5	156	1248	Left	1267	37
648	17	25	433	Left	517	27
642	20	34	601	Right	593	29
623	0	6	75	Right	183	11
605	0	0	0	Right	0	8
517	23	112	1382	Right	1700	35
417	0	0	0	Right	0	0
471	0	0	0	Right	0	0
435	3	2	55	Right	34	1
507	15	50	485	Right	470	10
608	0	0	0	Left	0	0
409	23	28	723	Right	945	29
426	26	153	1263	Left	1340	34
393	45	136	1185	Left	947	30
498	45	176	1657	Right	1709	36
614	12	77	732	Right	1017	44
462	43	53	750	Right	779	34
383	24	185	1821	Right	2382	42
677	3	10	152	Right	204	42
487	7	4	100	Right	78	1
433	24	91	783	Left	715	23
636	15	18	323	Left	278	48
384	0	0	14	Left	42	4
442	12	24	238	Left	225	9
679	38	87	1140	Right	1133	48
404	0	0	0	Right	0	0
634	15	15	290	Left	227	15
422	26	107	870	Right	766	31
450	5	59	509	Right	494	32
459	15	118	1426	Right	2136	38
678	24	33	486	Right	497	42
415	0	0	0	Right	0	0
470	0	0	0	Right	0	0
497	3	3	55	Right	45	1
406	23	153	1361	Right	1723	43
399	96	190	2063	Left	1884	43
479	68	102	1363	Right	1228	49
443	45	230	2740	Right	2953	43
506	27	69	722	Left	588	5
379	0	0	0	Left	0	0
493	2	0	50	Right	44	1
502	90	73	1111	Left	901	21
439	106	169	2388	Right	2148	51
511	60	81	1118	Left	1078	35
440	0	0	0	Right	0	0
503	0	0	0	Right	0	0
413	70	142	1654	Right	1798	39
421	12	80	652	Right	759	35
458	5	39	327	Right	465	15
485	28	108	960	Right	1152	31
482	0	0	0	Right	0	0
491	0	0	0	Right	0	0
408	12	64	444	Left	450	25
509	24	80	798	Right	696	30
500	0	135	950	Left	1042	32
473	3	31	256	Left	211	19
464	6	63	530	Right	797	30
455	0	105	826	Right	983	53
\.


--
-- Data for Name: bowler; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bowler (playerid, nowickets, bowlhand, bowltype, oversbowled, maidenovers, runsconceded, totalinningsbowled, dotballs, noballsbowled) FROM stdin;
661	83	left	fast	326	15	2123	43	0	25
687	9	right	medium	135	0	899	14	0	0
529	9	right	fast	85	0	830	9	0	0
524	22	right	medium	109	1	699	29	0	0
576	0	right	medium	0	0	0	0	0	0
688	0	right	medium	0	0	0	0	0	0
377	25	left	medium	171	4	808	18	0	5
386	4	right	medium	20	0	122	2	0	2
594	2	right	off-spin	20	2	68	2	0	0
397	34	left	fast	203	2	1246	53	0	0
388	42	right	medium	239	20	1149	47	0	0
400	64	right	medium	241	3	1274	49	0	0
620	22	right	fast	138	3	830	48	0	3
622	12	right	medium	102	0	517	47	0	1
381	37	right	medium	235	5	1599	36	0	9
394	29	left	medium	189	10	1071	28	0	0
382	22	right	medium	231	7	1332	40	0	0
385	0	right	fast	0	0	0	0	0	0
378	0	right	medium	0	0	0	0	0	0
484	12	right	medium	61	0	416	18	0	0
526	19	right	medium	208	0	1207	29	0	0
489	103	left	fast	432	16	2509	48	0	0
614	81	right	fast	324	0	2351	44	0	9
466	31	right	medium	158	4	840	52	0	5
475	48	right	fast	244	13	1373	32	0	10
677	24	right	off-spin	167	10	680	42	0	0
444	0	right	medium	10	0	0	1	0	0
516	10	right	medium	40	5	280	5	0	0
608	0	right	medium	0	0	0	0	0	0
530	15	right	fast	55	0	410	10	0	0
457	0	right	medium	10	0	65	5	0	0
691	0	right	leg-spin	80	0	470	10	0	5
430	29	right	fast	270	5	1826	36	0	0
401	0	left	medium	110	0	775	14	0	0
420	18	right	fast	112	0	685	14	0	0
476	0	right	medium	0	0	0	0	0	0
494	24	right	medium	198	0	1404	23	0	5
532	4	right	fast	73	5	446	23	0	0
589	25	left	fast	95	10	469	35	0	1
648	10	right	medium	199	0	1201	27	0	0
642	10	right	leg-spin	180	0	1128	29	0	0
623	5	right	leg-spin	27	0	215	11	0	5
449	69	left	medium	425	9	1885	50	0	0
605	5	right	medium	45	0	275	8	0	2
512	47	right	medium	279	29	1657	38	0	5
423	0	right	fast	0	0	0	0	0	0
414	15	right	medium	70	0	660	10	0	10
666	1	right	fast	7	0	36	5	0	0
405	22	right	fast	253	15	1394	32	0	0
496	86	right	fast	410	5	2810	47	0	0
632	0	right	medium	5	0	60	42	0	0
469	0	right	medium	28	4	164	4	0	0
609	22	right	fast	70	0	494	18	0	0
514	43	right	fast	219	25	1086	44	0	20
505	91	right	fast	287	4	1821	37	0	9
697	0	right	off-spin	0	0	0	5	0	0
407	15	right	medium	50	0	400	5	0	0
416	11	left	medium	139	7	878	41	0	0
472	33	left	medium	237	15	1221	45	0	0
636	42	left	medium	216	8	1005	48	0	0
679	15	right	fast	80	3	602	48	0	1
534	103	left	medium	369	20	2481	43	0	14
519	0	Right	fast	0	0	0	0	0	0
696	0	right	fast	15	0	75	8	0	0
634	3	right	fast	33	0	338	15	0	0
483	0	right	medium	20	0	220	5	0	0
501	30	right	medium	114	6	571	12	0	0
492	47	right	medium	288	11	1752	34	0	10
678	51	right	leg-spin	403	9	1798	42	0	0
447	55	right	fast	290	24	1532	42	0	0
412	45	left	medium	299	14	1941	38	0	0
698	18	right	medium	60	6	299	26	0	0
486	58	right	medium	277	17	1631	36	0	15
504	51	right	medium	258	2	1111	51	0	0
518	0	right	medium	0	0	0	0	0	0
672	0	Left	Leg-Spin	0	0	0	0	0	0
428	72	right	medium	389	5	2062	45	0	0
446	78	right	fast	157	12	851	36	0	0
437	57	right	fast	282	29	1170	43	0	0
548	0	right	fast	6	0	33	11	0	0
424	12	left	medium	96	16	794	17	0	10
434	16	left	medium	40	4	172	14	0	0
569	26	right	off-spin	103	0	636	13	0	0
557	11	right	fast	42	0	336	34	0	0
588	0	right	fast	0	0	0	23	0	0
560	0	right	medium	0	0	0	0	0	0
590	47	right	fast	275	5	1549	41	0	0
578	15	right	off-spin	111	0	674	37	0	0
570	0	right	off-spin	0	0	0	0	0	0
515	21	left	medium	85	0	448	22	0	3
553	10	right	fast	59	0	427	48	0	4
552	0	right	leg-spin	0	0	0	39	0	0
554	8	right	off-spin	122	1	633	50	0	1
635	24	right	medium	321	0	1990	49	0	4
461	49	right	medium	378	28	2064	44	0	5
598	75	right	medium	413	18	1769	50	0	8
\.


--
-- Data for Name: captain; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.captain (playerid, matchesascaptain, totalwins) FROM stdin;
520	93	24
470	111	58
403	92	19
417	97	28
385	117	96
487	105	45
454	99	22
443	117	107
379	91	42
503	104	72
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
30	Bharat Ratna Shri Atal Bihari Vajpayee Ekana Cricket Stadium, Lucknow
31	MA Chidambaram Stadium, Chennai
32	Arun Jaitley Stadium, Delhi
33	Himachal Pradesh Cricket Association Stadium, Dharamsala
34	MA Chidambaram Stadium, Chennai
35	Maharashtra Cricket Association Stadium, Pune
36	Bharat Ratna Shri Atal Bihari Vajpayee Ekana Cricket Stadium, Lucknow
37	M.Chinnaswamy Stadium, Bengaluru
38	Wankhede Stadium, Mumbai
39	Bharat Ratna Shri Atal Bihari Vajpayee Ekana Cricket Stadium, Lucknow
40	Himachal Pradesh Cricket Association Stadium, Dharamsala
41	MA Chidambaram Stadium, Chennai
42	Wankhede Stadium, Mumbai
43	Arun Jaitley Stadium, Delhi
44	M.Chinnaswamy Stadium, Bengaluru
45	MA Chidambaram Stadium, Chennai
46	Himachal Pradesh Cricket Association Stadium, Dharamsala
47	Eden Gardens, Kolkata
48	Maharashtra Cricket Association Stadium, Pune
49	Maharashtra Cricket Association Stadium, Pune
50	Bharat Ratna Shri Atal Bihari Vajpayee Ekana Cricket Stadium, Lucknow
51	Eden Gardens, Kolkata
52	Wankhede Stadium, Mumbai
53	M.Chinnaswamy Stadium, Bengaluru
54	Bharat Ratna Shri Atal Bihari Vajpayee Ekana Cricket Stadium, Lucknow
55	Arun Jaitley Stadium, Delhi
56	Eden Gardens, Kolkata
57	Wankhede Stadium, Mumbai
58	M.Chinnaswamy Stadium, Bengaluru
59	Maharashtra Cricket Association Stadium, Pune
60	Wankhede Stadium, Mumbai
61	Eden Gardens, Kolkata
62	Maharashtra Cricket Association Stadium, Pune
63	Eden Gardens, Kolkata
64	M.Chinnaswamy Stadium, Bengaluru
\.


--
-- Data for Name: match; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.match (matchid, date, tournamentid, team1id, team2id, winnerteam, umpire, locationid, matchtype) FROM stdin;
502	2023-10-15 00:00:00	37	30	28	28	6	32	ODI
503	2023-10-20 00:00:00	37	27	24	27	12	37	ODI
504	2023-10-05 00:00:00	37	30	33	33	6	28	ODI
505	2023-10-23 00:00:00	37	24	28	28	15	31	ODI
506	2023-10-19 00:00:00	37	26	29	26	17	35	ODI
507	2023-10-14 00:00:00	37	26	24	26	14	28	ODI
508	2023-10-17 00:00:00	37	32	31	31	6	33	ODI
511	2023-10-19 00:00:00	37	30	32	32	6	38	ODI
509	2023-10-21 00:00:00	37	31	34	34	7	30	ODI
510	2023-10-13 00:00:00	37	33	29	33	3	31	ODI
512	2023-10-24 00:00:00	37	32	29	32	15	38	ODI
513	2023-10-22 00:00:00	37	26	33	26	9	33	ODI
514	2023-10-18 00:00:00	37	33	28	33	17	31	ODI
515	2023-10-25 00:00:00	37	27	31	27	9	32	ODI
516	2023-10-26 00:00:00	37	30	34	34	7	37	ODI
517	2023-10-12 00:00:00	37	27	32	32	8	30	ODI
518	2023-10-16 00:00:00	37	27	34	27	14	30	ODI
519	2023-10-07 00:00:00	37	29	28	29	14	33	ODI
520	2023-10-28 00:00:00	37	27	33	27	7	33	ODI
521	2023-10-27 00:00:00	37	24	32	32	17	31	ODI
522	2023-10-08 00:00:00	37	26	27	26	12	31	ODI
523	2023-10-20 00:00:00	37	31	29	31	8	47	ODI
524	2023-10-29 00:00:00	37	26	30	26	9	30	ODI
525	2023-10-30 00:00:00	37	28	34	28	12	35	ODI
526	2023-10-31 00:00:00	37	24	29	24	8	47	ODI
527	2023-11-03 00:00:00	37	31	28	28	18	30	ODI
528	2023-11-01 00:00:00	37	33	32	32	9	35	ODI
529	2023-11-02 00:00:00	37	26	34	26	15	38	ODI
530	2023-11-04 00:00:00	37	33	24	24	2	37	ODI
531	2023-11-17 00:00:00	37	30	27	27	4	28	ODI
532	2023-11-05 00:00:00	37	26	32	26	5	47	ODI
533	2023-10-10 00:00:00	37	30	29	30	4	33	ODI
534	2023-11-06 00:00:00	37	29	34	29	8	32	ODI
535	2023-11-07 00:00:00	37	27	28	27	7	38	ODI
536	2023-11-08 00:00:00	37	30	31	30	8	35	ODI
537	2023-11-09 00:00:00	37	33	34	33	14	37	ODI
538	2023-11-10 00:00:00	37	32	28	32	3	28	ODI
539	2023-11-11 00:00:00	37	27	29	27	16	35	ODI
540	2023-11-22 00:00:00	37	30	24	30	3	47	ODI
541	2023-11-12 00:00:00	37	26	31	26	3	37	ODI
542	2023-11-15 00:00:00	37	26	33	26	8	38	ODI
543	2023-11-16 00:00:00	37	32	27	27	17	47	ODI
544	2023-11-19 00:00:00	37	26	27	27	10	28	ODI
545	2023-10-12 00:00:00	37	24	34	24	16	29	ODI
546	2023-10-06 00:00:00	37	24	31	24	18	29	ODI
547	2023-10-09 00:00:00	37	33	31	33	9	29	ODI
548	2023-10-11 00:00:00	37	26	28	26	16	32	ODI
549	2023-10-18 00:00:00	37	32	34	32	10	32	ODI
550	2024-01-03 00:00:00	39	34	33	34	18	1	ODI
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
700	adsaf	2008-01-03	\N	0	0	0	Batsman	active	http://localhost:3000/1704271417050_win.jpeg	24
524	Kasun Rajitha	1993-06-01	34	0	0	0	Bowler	active	https:	13
529	Matheesha Pathirana	2002-12-18	34	0	0	0	Bowler	active	https:	13
522	Pathum Nissanka	1998-05-18	34	0	0	0	Batsman	active	http://localhost:3000/1704259020391_pathum.webp	13
521	Charith Asalanka	1997-06-29	34	0	0	0	Batsman	active	http://localhost:3000/1704259044912_charith.jpg	13
672	Anrich Nortje	1993-11-16	\N	0	0	0	Bowler	active	https:	12
688	Dasun Shanaka	1991-09-09	34	0	0	0	allrounder	active	https:	13
687	Dunith Wellalage	2003-01-09	34	0	0	0	allrounder	active	https:	13
532	Dushmantha Chameera	1992-01-11	\N	0	0	0	Bowler	active	https:	13
691	Dushan Hemantha	1994-05-24	\N	0	0	0	allrounder	active	https:	13
533	Dhananjaya de Silva	1991-09-06	\N	0	0	0	Batsman	active	https:	13
534	Dilshan Madushanka	2000-09-18	\N	0	0	0	Bowler	active	https:	13
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
405	Taskin Ahmed	1995-04-05	29	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Taskin_Ahmed_at_Chef%27s_Table.png/220px-Taskin_Ahmed_at_Chef%27s_Table.png	8
423	Brydon Carse	1995-07-31	30	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/a/ad/1_24_Brydon_Carse.jpg/220px-1_24_Brydon_Carse.jpg	9
469	Ryan Klein	1997-06-15	31	0	0	0	Bowler	active	https:	18
505	Gerald Coetzee	2000-10-02	32	0	0	0	Bowler	active	https:	12
514	Kagiso Rabada	1995-05-25	32	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/0/08/Rabada.jpg/220px-Rabada.jpg	12
548	Cameron Green	1999-06-03	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/b/b4/Cameron_Green_fielding_Boxing_Day_2022_%28cropped%29.jpg/220px-Cameron_Green_fielding_Boxing_Day_2022_%28cropped%29.jpg	7
552	Marnus Labuschagne	1994-05-22	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Day_4_of_the_3rd_Test_of_the_2019_Ashes_at_Headingley_%2848631113862%29_%28Marnus_Labuschagne_cropped%29.jpg/220px-Day_4_of_the_3rd_Test_of_the_2019_Ashes_at_Headingley_%2848631113862%29_%28Marnus	7
496	Haris Rauf	1993-11-07	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/36/1_53_Haris_Rauf.jpg/220px-1_53_Haris_Rauf.jpg	24
442	Ishan Kishan	1998-07-18	26	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/d/d7/Ishan_Kishan.jpg/220px-Ishan_Kishan.jpg	10
553	Mitchell Marsh	1991-10-20	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/7/73/Mitchell_Marsh.jpg/220px-Mitchell_Marsh.jpg	7
554	Glenn Maxwell	1988-10-14	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/9/94/3-_Protest_Glenn_Maxwell_%28cropped%29.jpg/220px-3-_Protest_Glenn_Maxwell_%28cropped%29.jpg	7
557	Marcus Stoinis	1989-08-16	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/2/2b/2018.01.21.15.22.25-Stoinis_%2839081521620%29.jpg/220px-2018.01.21.15.22.25-Stoinis_%2839081521620%29.jpg	7
560	Ashton Agar	1993-10-14	\N	0	0	0	allrounder	active	https:	7
487	Babar Azam	1994-10-15	24	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/4/43/Babar_azam_2023.jpg/220px-Babar_azam_2023.jpg	24
433	Rahmanullah Gurbaz	2001-11-28	28	0	0	0	batsman	active	https:	16
414	Hasan Mahmud	1999-10-12	29	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Flag_of_Bangladesh.svg/23px-Flag_of_Bangladesh.svg.png	8
569	Mahedi Hasan	1994-12-12	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Flag_of_Bangladesh.svg/23px-Flag_of_Bangladesh.svg.png	8
570	Mehidy Hasan	1997-10-25	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/d/db/%E0%A6%AE%E0%A7%87%E0%A6%B9%E0%A7%87%E0%A6%A6%E0%A7%80_%E0%A6%B9%E0%A6%BE%E0%A6%B8%E0%A6%BE%E0%A6%A8_%E0%A6%AE%E0%A6%BF%E0%A6%B0%E0%A6%BE%E0%A6%9C_%28cropped%29.jpg/220px-%E0%A6%AE%E0%A7%87%E0%A6%	8
635	Rachin Ravindra	1999-11-18	33	0	0	0	allrounder	active	https:	11
515	Tabraiz Shamsi	1990-02-18	32	0	0	0	Bowler	active	https:	12
470	Kane Williamson	1990-08-08	33	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Kane_Williamson_in_2019.jpg/220px-Kane_Williamson_in_2019.jpg	11
479	Glenn Phillips	1996-12-06	33	0	0	0	Batsman	active	https:	11
578	Moeen Ali	1987-06-07	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/d/d1/2018.01.06.17.47.32-Moeen_Ali_%2838876905344%29_%28cropped%29.jpg/220px-2018.01.06.17.47.32-Moeen_Ali_%2838876905344%29_%28cropped%29.jpg	9
497	Mohammad Rizwan	1992-06-01	24	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/a/af/M_Rizwan.jpg/220px-M_Rizwan.jpg	24
443	Virat Kohli	1988-11-05	26	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/e/ef/Virat_Kohli_during_the_India_vs_Aus_4th_Test_match_at_Narendra_Modi_Stadium_on_09_March_2023.jpg/220px-Virat_Kohli_during_the_India_vs_Aus_4th_Test_match_at_Narendra_Modi_Stadium_on_09_March_2023.	10
415	Mushfiqur Rahim	1987-05-09	29	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/e/e4/Mushfiqur_Rahim_2018_%28cropped%29.jpg/220px-Mushfiqur_Rahim_2018_%28cropped%29.jpg	8
406	Litton Das	1994-10-13	29	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/6/69/Liton_Das_%283%29_%28cropped%29.jpg/220px-Liton_Das_%283%29_%28cropped%29.jpg	8
424	Sam Curran	1998-06-03	30	0	0	0	Bowler	active	https:	9
434	Reece Topley	1994-02-21	30	0	0	0	Bowler	active	https:	9
461	Aryan Dutt	2003-05-12	31	0	0	0	Bowler	active	https:	18
506	Quinton de Kock	1992-12-17	32	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/6/67/QUINTON_DE_KOCK_%2815681398316%29.jpg/220px-QUINTON_DE_KOCK_%2815681398316%29.jpg	12
588	Ben Stokes	1991-06-04	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/BEN_STOKES_%2811704837023%29_%28cropped%29.jpg/220px-BEN_STOKES_%2811704837023%29_%28cropped%29.jpg	9
590	Chris Woakes	1989-03-02	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/Chris_Woakes_2022.jpg/220px-Chris_Woakes_2022.jpg	9
598	Ravindra Jadeja	1988-12-06	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/b/b1/Ravindra_Jadeja_in_2018.jpg/220px-Ravindra_Jadeja_in_2018.jpg	10
517	Rassie van der Dussen	1989-02-07	32	0	0	0	Batsman	active	http://localhost:3000/1704133235991_pak.png	12
445	K. L. Rahul	1992-04-18	26	0	0	0	batsman	active	https://upload.wikimedia.org/wikipedia/commons/6/69/KL_Rahul_at_Femina_Miss_India_2018_Grand_Finale_%28cropped%29.jpg	10
472	Trent Boult	1989-07-22	33	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/2/23/2018.02.03.22.23.14-AUSvNZL_T20_AUS_innings%2C_SCG_%2839533156665%29.jpg/220px-2018.02.03.22.23.14-AUSvNZL_T20_AUS_innings%2C_SCG_%2839533156665%29.jpg	11
576	Shakib Al Hasan	1987-03-24	\N	0	0	0	allrounder	active	https:	8
499	Saud Shakeel	1995-09-05	24	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/e/e9/1_37_Saud_Shakeel.jpg/220px-1_37_Saud_Shakeel.jpg	24
407	Tanzim Hasan Sakib	2002-10-20	29	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Flag_of_Bangladesh.svg/23px-Flag_of_Bangladesh.svg.png	8
416	Mustafizur Rahman	1995-09-06	29	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a3/Mustafizur_Rahman_%284%29_%28cropped%29.jpg/220px-Mustafizur_Rahman_%284%29_%28cropped%29.jpg	8
425	Liam Livingstone	1993-08-04	30	0	0	0	Batsman	active	https:	9
427	Joe Root	1990-12-30	30	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f7/Joe_Root_HIP1487_%28cropped%29.jpg/220px-Joe_Root_HIP1487_%28cropped%29.jpg	9
594	Ravichandran Ashwin	1986-09-17	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f4/Ravichandran_Ashwin_%282%29.jpg/220px-Ravichandran_Ashwin_%282%29.jpg	10
454	Scott Edwards	1996-08-23	31	0	0	0	batsman	active	https:	18
463	Max O'Dowd	1994-03-04	31	0	0	0	Batsman	active	https:	18
620	Logan van Beek	1990-09-07	\N	0	0	0	allrounder	active	https:	18
622	Roelof van der Merwe	1984-12-31	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/35/Roelof_van_der_Merwe.jpg/220px-Roelof_van_der_Merwe.jpg	18
661	Marco Jansen	2000-05-01	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/4/41/Marco_Jansen_2022.jpg/220px-Marco_Jansen_2022.jpg	12
697	Dimuth Karunaratne	1988-04-21	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/6/6c/2_07_Dimuth_Karunaratne.jpg/220px-2_07_Dimuth_Karunaratne.jpg	13
632	Daryl Mitchell	1991-05-20	33	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Flag_of_New_Zealand.svg/23px-Flag_of_New_Zealand.svg.png	11
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
609	Hardik Pandya	1993-10-11	\N	0	0	0	allrounder	active	https:	10
666	Andile Phehlukwayo	1996-03-03	\N	0	0	0	allrounder	active	https:	12
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
623	Saqib Zulfiqar	1997-03-28	\N	0	0	0	allrounder	active	https:	18
642	Shadab Khan	1998-10-04	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/b/ba/Shadab_Khan.png/220px-Shadab_Khan.png	24
648	Mohammad Nawaz	1994-03-21	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/3/32/Flag_of_Pakistan.svg/23px-Flag_of_Pakistan.svg.png	24
511	David Miller	1989-06-10	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/DAVID_MILLER_%2815704846295%29.jpg/220px-DAVID_MILLER_%2815704846295%29.jpg	12
493	Salman Ali Agha	1993-11-23	24	0	0	0	Batsman	active	https:	24
484	Tim Southee	1988-12-11	33	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a2/Tim_Southee_3.jpg/220px-Tim_Southee_3.jpg	11
439	Shreyas Iyer	1994-12-06	26	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/9/96/Shreyas_Iyer_2021.jpg/220px-Shreyas_Iyer_2021.jpg	10
475	Lockie Ferguson	1991-06-13	33	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/1/1d/Lockie_Ferguson.jpg/220px-Lockie_Ferguson.jpg	11
608	Axar Patel	1994-01-20	\N	0	0	0	allrounder	active	https:	10
614	Bas de Leede	1999-11-15	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/1_02_Bas_de_Leede.jpg/220px-1_02_Bas_de_Leede.jpg	18
502	Fakhar Zaman	1990-04-10	24	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Fakhar_Zaman%2C_Pakistan_vs_Sri_Lanka%2C_1st_ODI%2C_2017.jpg/220px-Fakhar_Zaman%2C_Pakistan_vs_Sri_Lanka%2C_1st_ODI%2C_2017.jpg	24
430	Mark Wood	1990-01-11	30	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/c/c0/Mark_wood_bowling_boxing_day_test.jpg/220px-Mark_wood_bowling_boxing_day_test.jpg	9
420	Gus Atkinson	1998-01-19	30	0	0	0	Bowler	active	https:	9
466	Paul van Meekeren	1993-01-15	31	0	0	0	Bowler	active	https:	18
457	Shariz Ahmad	2003-04-21	31	0	0	0	Bowler	active	https:	18
677	Mohammad Nabi	1985-01-01	\N	0	0	0	allrounder	active	https://upload.wikimedia.org/wikipedia/commons/thumb/4/49/Mohammad_Nabi-Australia.jpg/220px-Mohammad_Nabi-Australia.jpg	16
412	Shoriful Islam	2001-06-03	\N	0	0	0	Bowler	active	https:	8
422	Harry Brook	1999-02-22	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/4/49/Harry_Brook_%2851225504151%29_%28cropped%29.jpg/220px-Harry_Brook_%2851225504151%29_%28cropped%29.jpg	9
486	Matt Henry	1991-12-14	33	0	0	0	Bowler	active	https:	11
450	Suryakumar Yadav	1990-09-14	\N	0	0	0	Batsman	active	https://upload.wikimedia.org/wikipedia/commons/thumb/b/b7/Surya_Kumar_Yadav_in_BGT_2023.jpg/220px-Surya_Kumar_Yadav_in_BGT_2023.jpg	10
504	Keshav Maharaj	1990-02-07	\N	0	0	0	Bowler	active	https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/New_face_6-_Keshav_Maharaj.jpg/220px-New_face_6-_Keshav_Maharaj.jpg	12
459	Sybrand Engelbrecht	1988-09-15	31	0	0	0	Batsman	active	https:	18
636	Mitchell Santner	1992-02-05	\N	0	0	0	allrounder	active	https:	11
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
\.


--
-- Data for Name: playerrank; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.playerrank (playerid, battingrank, bowlingrank, allrounderrank) FROM stdin;
487	70	83	83
687	234	231	231
688	235	232	232
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
700	242	239	239
661	214	211	211
500	98	95	95
501	99	96	96
511	109	106	106
512	109	106	106
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
696	240	237	237
529	120	117	117
530	121	118	118
532	122	119	119
533	122	119	119
534	123	120	120
548	134	131	131
552	138	135	135
553	139	136	136
554	140	137	137
557	143	140	140
560	146	143	143
569	155	152	152
570	156	153	153
578	163	160	160
576	166	163	163
588	171	168	168
590	172	169	169
594	174	171	171
598	176	173	173
589	176	173	173
605	180	177	177
608	183	180	180
609	183	180	180
614	186	183	183
620	188	185	185
622	190	187	187
623	191	188	188
632	196	193	193
635	197	194	194
636	198	195	195
642	202	199	199
634	201	198	198
648	207	204	204
666	216	213	213
672	221	218	218
677	225	222	222
678	226	223	223
679	227	224	224
\.


--
-- Data for Name: scorecard; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.scorecard (matchid, playerid, noruns, nosixes, nofours, noballsfaced, nowickets, oversbowled, maidenovers, runsconceded, extras, noballs) FROM stdin;
502	433	80	4	8	57	0	0	0	0	0	0
502	383	28	0	3	48	0	0	0	0	0	0
502	380	3	0	0	8	0	0	0	0	0	0
502	679	19	1	1	24	0	0	0	0	0	0
502	678	23	0	3	22	3	9	1	37	0	0
502	426	32	0	4	39	0	0	0	0	0	0
502	382	28	1	3	16	0	0	0	0	0	0
502	427	11	0	2	17	0	0	0	0	0	0
502	421	2	0	0	4	0	0	0	0	0	0
502	381	5	0	1	6	1	6	1	44	1	1
502	394	2	0	0	4	1	7	0	50	2	0
502	677	9	0	1	15	0	0	0	0	0	0
502	422	66	1	7	61	0	0	0	0	0	0
502	425	10	0	1	14	0	0	0	0	0	0
502	424	10	0	0	23	0	4	0	46	2	2
502	590	9	0	1	26	0	4	0	41	7	0
502	428	20	0	2	13	3	10	1	42	1	0
502	430	18	0	3	22	2	9	0	50	0	0
502	434	15	0	3	7	0	0	0	0	0	0
502	425	0	0	0	0	1	10	0	33	0	0
502	427	0	0	0	0	1	4	0	19	0	0
502	382	0	0	0	0	3	10	1	51	5	0
502	677	0	0	0	0	2	6	0	16	1	0
502	679	0	0	0	0	0	2	0	13	0	0
503	399	163	9	14	124	0	0	0	0	0	0
503	553	121	9	10	108	0	0	0	0	0	0
503	554	0	0	0	1	0	0	0	0	0	0
503	557	21	1	1	24	0	0	0	0	0	0
503	552	8	0	1	12	0	0	0	0	0	0
503	397	2	0	0	3	0	0	0	0	0	0
503	388	0	0	0	1	0	0	0	0	0	0
503	400	1	0	0	1	0	0	0	0	0	0
503	498	64	2	7	61	0	0	0	0	0	0
503	500	70	0	10	71	0	0	0	0	0	0
503	499	30	0	5	31	0	0	0	0	0	0
503	648	14	1	0	16	0	7	0	43	0	0
503	494	0	0	0	3	1	9	0	82	2	0
503	489	10	0	2	8	5	10	1	54	3	0
503	492	8	0	2	8	0	8	0	57	4	0
503	496	0	0	0	1	3	8	0	83	3	0
503	397	0	0	0	0	1	8	0	65	6	0
503	388	0	0	0	0	1	10	1	37	1	0
503	400	0	0	0	0	4	10	0	53	1	0
503	554	0	0	0	0	0	5	0	40	0	0
503	557	0	0	0	0	2	5	0	40	3	0
506	408	51	3	5	43	0	0	0	0	0	0
506	406	66	0	7	82	0	0	0	0	0	0
506	409	16	0	0	35	0	0	0	0	0	0
506	413	46	3	3	36	0	1	0	6	0	0
506	401	14	0	2	18	0	9	0	60	0	0
506	416	1	0	0	7	0	0	0	0	0	0
506	412	7	1	0	3	0	8	0	54	0	0
506	438	53	2	5	55	0	0	0	0	0	0
506	443	103	4	6	97	0	0	0	0	0	0
506	439	19	0	2	25	0	0	0	0	0	0
506	437	0	0	0	0	2	10	1	41	1	0
506	447	0	0	0	0	2	10	0	60	3	0
506	609	0	0	0	0	0	0	0	8	0	0
506	443	0	0	0	0	0	0	0	2	0	0
506	605	0	0	0	0	1	9	0	59	0	0
506	449	0	0	0	0	1	10	0	47	1	0
506	598	0	0	0	0	2	10	0	38	0	0
506	414	0	0	0	0	1	8	0	65	3	2
506	416	0	0	0	0	0	5	0	29	0	0
504	421	33	1	4	35	0	0	0	0	0	0
504	426	14	0	2	24	0	0	0	0	0	0
504	427	77	1	4	86	0	0	0	0	0	0
504	422	25	1	4	16	0	0	0	0	0	0
504	578	11	0	1	17	0	0	0	0	0	0
504	425	20	0	3	22	0	0	0	0	0	0
504	424	14	0	0	19	1	6	2	47	2	0
504	590	11	0	1	12	0	6	0	45	0	0
504	428	15	1	0	13	0	7	0	47	0	0
504	430	13	0	0	14	0	5	0	55	1	0
504	474	152	3	19	121	0	0	0	0	0	0
504	485	0	0	0	1	0	0	0	0	0	0
504	635	123	5	11	96	1	10	0	76	0	0
504	472	0	0	0	0	1	10	1	48	1	0
504	486	0	0	0	0	3	10	1	48	0	0
504	636	0	0	0	0	2	10	0	37	1	0
504	634	0	0	0	0	0	7	0	56	4	0
504	479	0	0	0	0	2	3	0	17	0	0
504	578	0	0	0	0	0	9	0	60	0	0
504	425	0	0	0	0	0	3	0	24	0	0
511	507	85	3	9	75	0	0	0	0	0	0
511	517	60	0	8	61	0	0	0	0	0	0
511	509	109	4	12	67	0	0	0	0	0	0
511	511	5	0	1	6	0	0	0	0	0	0
511	661	75	6	3	42	2	5	0	35	1	0
511	505	3	0	0	3	3	4	0	35	1	0
511	504	1	0	0	1	0	0	0	0	0	0
511	421	10	1	1	12	0	0	0	0	0	0
511	426	6	0	1	11	0	0	0	0	0	0
511	427	2	0	0	6	0	0	0	0	0	0
511	588	5	0	1	8	0	0	0	0	0	0
511	422	17	1	2	25	0	0	0	0	0	0
511	589	12	1	1	12	0	0	0	0	0	0
511	428	10	0	1	14	2	10	0	61	0	0
505	498	58	2	5	75	0	0	0	0	0	0
505	500	17	0	2	22	0	0	0	0	0	0
505	677	0	0	0	0	1	10	0	31	0	0
510	409	13	0	0	25	0	0	0	0	0	0
510	472	0	0	0	0	2	10	0	45	2	0
509	461	9	0	1	6	3	10	0	44	2	0
509	466	0	0	0	0	1	8	1	39	6	0
514	677	7	0	1	9	0	0	0	0	0	0
514	475	0	0	0	0	3	7	1	19	1	0
507	489	2	0	0	10	2	6	0	36	1	0
507	598	0	0	0	0	2	9	0	38	0	0
512	517	1	0	0	7	0	0	0	0	0	0
512	412	6	0	1	4	1	9	0	76	0	0
513	479	23	1	0	26	0	2	0	12	0	0
513	472	0	0	0	1	0	0	0	0	0	0
513	472	0	0	0	0	1	10	0	60	1	0
516	590	0	0	0	4	0	6	0	30	2	0
516	530	0	0	0	0	3	7	0	35	0	0
508	462	20	0	3	25	0	0	0	0	0	0
508	514	0	0	0	0	2	9	1	56	3	0
515	548	8	0	1	11	0	0	0	0	0	0
515	466	0	0	0	1	0	0	0	0	0	0
518	523	78	0	12	82	0	0	0	0	0	0
518	552	40	0	2	60	0	0	0	0	0	0
522	399	41	0	6	52	0	0	0	0	0	0
522	443	85	0	6	116	0	0	0	0	0	0
522	388	0	0	0	0	3	9	1	38	1	0
519	382	1	0	0	4	0	0	0	0	0	0
519	382	0	0	0	0	0	7	0	30	0	0
517	553	7	0	0	15	0	1	0	6	0	0
517	397	0	0	0	0	2	9	1	53	1	0
524	443	0	0	0	9	0	0	0	0	0	0
524	427	0	0	0	1	0	0	0	0	0	0
524	425	0	0	0	0	0	4	1	29	0	0
521	648	24	2	1	24	0	6	0	40	0	0
521	505	10	0	0	13	2	7	0	42	1	0
525	696	15	0	1	21	0	0	0	0	0	0
525	380	62	0	7	74	0	0	0	0	0	0
525	698	0	0	0	0	0	3	0	18	0	0
520	474	28	0	6	17	0	0	0	0	0	0
520	475	0	0	0	1	0	3	0	38	0	0
523	458	41	0	8	41	0	0	0	0	0	0
523	403	9	0	2	18	0	0	0	0	0	0
523	416	20	1	2	35	0	0	0	0	0	0
523	405	11	0	1	35	2	9	1	43	1	0
526	409	7	1	0	3	0	0	0	0	0	0
526	501	0	0	0	0	3	8	1	31	0	0
527	622	11	0	0	33	0	0	0	0	0	0
527	678	0	0	0	0	0	10	0	31	3	0
528	632	24	0	4	30	0	0	0	0	0	0
528	636	0	0	0	0	0	10	0	58	2	0
529	439	82	6	3	56	0	0	0	0	0	0
529	691	0	0	0	1	0	8	0	52	1	1
529	446	0	0	0	0	5	5	1	18	0	0
530	492	0	0	0	0	1	10	0	82	3	1
531	548	47	0	5	52	0	0	0	0	0	0
531	590	32	1	4	33	4	9	0	54	0	0
531	393	0	0	0	0	0	5	0	28	0	0
532	511	11	0	2	11	0	0	0	0	0	0
533	430	6	0	1	5	1	10	0	29	1	0
533	412	12	0	2	14	3	10	0	75	1	0
534	525	41	0	4	42	0	0	0	0	0	0
534	524	0	0	0	2	0	0	0	0	0	0
534	526	0	0	0	0	2	9	0	44	3	0
535	678	35	3	2	18	2	10	0	44	3	0
535	400	0	0	0	0	1	10	0	58	3	0
535	677	0	0	0	0	0	2	0	20	0	0
536	428	1	0	0	1	3	8	0	54	1	0
536	466	0	0	0	0	1	10	0	57	5	0
536	589	0	0	0	0	2	7	2	19	0	0
537	532	1	0	0	20	0	0	0	0	0	0
537	526	0	0	0	0	1	7	0	43	0	0
538	677	2	0	0	3	0	0	0	0	0	0
538	505	0	0	0	0	4	10	1	44	2	0
539	409	74	2	5	79	0	0	0	0	0	0
539	569	2	0	0	3	0	9	0	38	1	0
540	427	60	0	4	72	0	0	0	0	0	0
540	502	1	0	0	9	0	0	0	0	0	0
540	578	0	0	0	0	2	10	0	60	0	0
541	620	16	0	2	15	0	0	0	0	0	0
541	598	0	0	0	0	2	9	0	49	1	0
542	473	2	0	0	5	0	0	0	0	0	0
542	446	0	0	0	0	7	9	0	57	6	0
543	661	0	0	0	1	0	4	0	35	4	0
543	514	10	1	0	12	0	0	0	0	0	0
543	554	0	0	0	0	0	10	0	35	0	0
544	447	9	0	1	8	0	0	0	0	0	0
544	388	0	0	0	0	2	10	0	60	1	0
545	521	1	0	0	3	0	0	0	0	0	0
545	529	1	0	0	3	1	9	0	90	18	0
545	521	0	0	0	0	0	1	0	10	0	0
546	455	17	0	3	21	0	0	0	0	0	0
546	455	0	0	0	0	2	8	1	39	0	0
547	479	4	0	1	4	0	2	0	11	0	0
547	469	8	0	0	15	0	7	1	41	3	0
548	380	16	0	3	22	0	0	0	0	0	0
511	430	43	5	2	17	0	7	0	76	1	0
505	499	25	0	3	34	0	0	0	0	0	0
505	679	0	0	0	0	1	5	0	50	3	0
510	413	41	2	2	49	0	0	0	0	0	0
510	486	0	0	0	0	2	10	0	58	1	1
509	614	6	0	0	21	0	3	0	29	2	0
509	525	91	0	7	107	0	0	0	0	0	0
514	485	54	3	4	64	0	0	0	0	0	0
514	632	1	0	0	7	0	0	0	0	0	0
514	678	8	1	0	13	1	10	0	43	2	0
514	382	0	0	0	0	1	10	0	57	1	0
507	499	6	0	0	10	0	0	0	0	0	0
507	496	2	0	0	6	0	6	0	43	0	0
507	605	0	0	0	0	0	2	0	12	0	0
512	413	111	4	11	111	0	3	0	20	1	0
512	504	0	0	0	0	1	10	0	32	1	0
513	486	0	0	0	1	1	9	0	55	0	0
513	447	0	0	0	0	1	10	1	45	4	0
516	425	1	0	0	6	0	0	0	0	0	0
516	589	14	1	1	17	0	0	0	0	0	0
516	428	2	0	0	7	0	4	0	39	0	0
516	589	0	0	0	0	2	5	0	30	1	0
508	622	29	1	3	19	0	0	0	0	0	0
508	504	0	0	0	0	1	9	0	38	0	0
515	397	0	0	0	1	0	0	0	0	0	0
515	462	14	0	2	18	0	0	0	0	0	0
515	620	0	0	0	3	0	0	0	0	0	0
515	388	0	0	0	0	1	6	0	27	2	0
518	530	4	0	1	8	0	4	0	47	0	0
518	400	0	0	0	0	4	8	1	47	2	0
518	526	0	0	0	0	0	7	0	49	0	0
522	548	8	0	0	20	0	0	0	0	0	0
522	449	0	0	0	0	2	10	0	42	0	0
519	383	22	1	3	25	0	0	0	0	0	0
519	380	18	0	1	25	0	0	0	0	0	0
519	403	59	1	3	83	0	0	0	0	0	0
517	509	29	0	3	27	0	0	0	0	0	0
517	557	5	0	1	4	0	0	0	0	0	0
517	504	0	0	0	0	2	10	0	30	2	0
524	449	9	0	1	13	2	8	0	24	0	0
524	428	13	0	2	20	2	10	0	35	0	0
521	499	52	0	7	52	0	0	0	0	0	0
521	511	29	2	2	33	0	0	0	0	0	0
521	494	0	0	0	0	2	8	0	45	1	0
525	534	0	0	0	4	2	9	0	48	3	0
525	677	0	0	0	0	0	6	0	33	0	0
520	388	0	0	0	0	0	0	0	0	0	0
520	472	10	1	0	8	0	0	0	0	0	0
520	636	0	0	0	0	2	10	0	80	1	0
523	457	6	0	0	8	0	2	0	13	0	0
523	620	0	0	0	0	1	9	1	30	4	0
526	416	3	0	0	7	0	0	0	0	0	0
527	459	58	0	6	86	0	0	0	0	0	0
527	383	20	0	2	34	0	0	0	0	0	0
527	466	0	0	0	0	0	5	0	35	2	1
528	517	133	5	9	118	0	0	0	0	0	0
528	509	15	1	1	7	0	0	0	0	0	0
528	634	0	0	0	8	0	0	0	0	0	0
528	504	0	0	0	0	4	9	0	46	0	0
529	525	0	0	0	4	0	0	0	0	0	0
529	524	14	0	2	17	0	0	0	0	0	0
530	474	35	0	6	39	0	0	0	0	0	0
530	632	29	1	4	18	0	0	0	1	0	0
531	552	71	0	7	83	0	0	0	0	0	0
531	421	0	0	0	1	0	0	0	0	0	0
531	425	0	0	0	0	1	6	0	42	0	0
532	450	22	0	5	14	0	0	0	0	0	0
532	509	1	0	0	11	0	0	0	0	0	0
532	504	0	0	0	0	1	10	0	30	1	0
532	437	0	0	0	0	0	5	0	14	1	0
532	449	0	0	0	0	2	5	1	7	0	0
533	427	82	1	8	68	0	0	0	0	0	0
533	424	11	0	1	15	1	7	0	47	2	0
533	428	11	0	1	7	1	10	0	42	0	0
534	534	0	0	0	1	3	10	1	69	4	0
534	524	0	0	0	0	0	4	0	47	0	0
535	399	18	0	3	29	0	0	0	0	0	0
535	393	0	0	0	0	0	3	0	15	0	0
536	578	4	0	0	15	0	0	0	0	0	0
536	466	4	0	1	3	0	0	0	0	0	0
537	521	8	0	1	8	0	0	0	0	0	0
537	479	17	0	3	10	0	1	0	3	0	0
538	380	26	0	2	46	0	0	0	0	0	0
538	512	0	0	0	0	2	8	0	69	6	0
539	406	36	0	5	45	0	0	0	0	0	0
539	401	7	0	0	11	0	10	0	85	1	0
539	393	0	0	0	0	0	6	0	33	0	0
540	589	15	1	2	5	0	0	0	0	0	0
540	589	0	0	0	0	3	10	0	56	2	0
541	614	12	0	1	21	2	10	0	82	8	0
541	622	0	0	0	0	1	10	0	53	0	0
541	446	0	0	0	0	0	6	0	41	1	0
542	632	134	7	9	119	0	0	0	0	0	0
542	484	0	0	0	0	3	10	0	100	1	0
542	636	0	0	0	0	0	10	1	51	0	0
543	515	1	0	0	5	0	0	0	0	0	0
543	393	0	0	0	0	2	5	0	21	1	0
511	420	35	0	7	21	2	9	0	60	1	0
505	642	40	1	1	38	0	8	0	49	0	0
505	678	0	0	0	0	0	10	0	41	0	0
510	405	17	2	0	19	0	8	0	56	3	0
510	475	0	0	0	0	3	10	0	49	4	2
509	462	9	0	0	16	0	0	0	0	0	0
509	521	44	1	2	66	0	0	0	0	0	0
509	533	30	2	1	37	0	4	0	13	3	0
509	691	4	0	1	3	0	8	0	42	0	0
514	479	71	4	4	80	0	3	0	13	1	0
514	433	11	1	0	21	0	0	0	0	0	0
514	394	0	0	0	2	0	7	1	39	2	0
514	486	0	0	0	0	1	5	2	16	0	0
507	443	16	0	3	18	0	0	0	0	0	0
512	661	1	0	0	1	2	8	0	39	5	0
512	416	0	0	0	0	0	9	0	76	2	0
513	635	75	1	6	87	0	9	0	46	1	0
513	446	1	0	0	1	0	0	0	0	0	0
516	588	43	0	6	73	0	0	0	0	0	0
516	524	0	0	0	0	2	7	0	36	1	0
516	533	0	0	0	0	0	1	0	10	0	0
508	620	10	0	1	27	0	0	0	0	0	0
508	505	22	1	2	23	1	8	0	57	2	0
508	622	0	0	0	0	2	9	0	34	0	0
515	455	10	0	2	11	0	0	0	0	0	0
515	397	0	0	0	0	1	4	0	22	2	0
518	533	7	0	1	13	0	3	0	13	0	0
518	397	0	0	0	0	2	10	0	43	4	0
522	552	27	0	1	41	0	0	0	0	0	0
522	437	0	0	0	0	2	10	0	35	4	0
522	400	0	0	0	0	0	8	0	53	0	0
519	408	5	0	1	13	0	0	0	0	0	0
519	406	13	0	2	18	0	0	0	0	0	0
517	517	26	0	2	30	0	0	0	0	0	0
517	554	3	0	0	17	0	0	0	0	0	0
517	514	0	0	0	0	3	8	1	33	2	1
524	437	16	0	1	25	0	0	0	0	0	0
524	589	16	2	0	17	0	0	0	0	0	0
521	500	12	0	2	18	0	0	0	0	0	0
521	509	12	1	0	10	0	0	0	0	0	0
521	515	0	0	0	0	4	10	0	60	3	2
525	524	5	0	0	7	0	0	0	0	0	0
525	678	0	0	0	0	1	10	0	50	6	0
525	526	0	0	0	0	0	10	0	55	4	0
520	485	32	1	4	37	0	0	0	0	0	0
520	472	0	0	0	0	3	10	0	77	3	0
523	455	15	0	1	33	0	0	0	0	0	0
523	614	17	0	2	32	2	7	0	25	0	0
523	412	0	0	0	0	2	10	0	51	3	0
526	405	6	0	0	13	0	6	1	36	0	0
527	455	29	0	4	35	0	0	0	0	0	0
527	382	0	0	0	0	1	10	0	40	5	0
528	474	2	0	0	6	0	0	0	0	0	0
528	486	0	0	0	9	0	5	0	31	1	0
529	438	92	2	11	92	0	0	0	0	0	0
529	521	1	0	0	24	0	0	0	0	0	0
529	437	0	0	0	0	1	5	1	8	3	0
530	502	126	11	8	81	0	0	0	0	0	0
530	636	0	0	0	0	0	5	0	35	0	0
531	427	13	0	2	17	0	0	0	0	0	0
531	578	0	0	0	0	0	4	0	28	0	0
532	598	29	1	3	15	5	9	1	33	0	0
532	510	9	0	2	6	0	0	0	0	0	0
532	515	0	0	0	0	1	10	0	72	8	1
532	447	0	0	0	0	1	4	1	11	0	0
533	421	52	0	8	59	0	0	0	0	0	0
533	422	20	0	3	15	0	0	0	0	0	0
533	569	14	0	1	32	4	8	0	71	0	0
534	523	4	0	1	5	0	0	0	0	0	0
534	532	4	0	0	9	0	0	0	0	0	0
534	412	0	0	0	0	2	9	0	52	1	0
535	677	12	1	0	10	0	0	0	0	0	0
535	388	0	0	0	0	2	9	0	39	1	0
535	377	0	0	0	0	0	10	1	53	5	0
536	420	2	0	0	1	0	7	0	41	1	0
536	622	0	0	0	0	0	3	0	22	0	0
537	533	19	1	2	24	0	2	0	22	0	0
537	484	0	0	0	0	1	8	0	52	0	0
538	679	97	3	7	107	0	0	0	0	0	0
538	510	0	0	0	0	0	4	0	25	0	0
538	504	0	0	0	0	2	10	1	25	2	0
539	405	0	0	0	1	1	10	0	61	1	0
540	588	84	2	11	76	0	0	0	0	0	0
540	499	29	0	4	37	0	0	0	0	0	0
541	439	128	5	10	94	0	0	0	0	0	0
541	461	5	0	0	11	0	7	0	52	1	0
542	438	80	3	8	66	0	0	0	0	0	0
542	636	9	0	0	10	0	0	0	0	0	0
542	598	0	0	0	0	0	10	0	63	1	1
543	399	29	4	1	18	0	0	0	0	0	0
543	510	0	0	0	0	1	8	1	23	1	0
544	553	15	1	1	15	0	2	0	5	0	0
544	437	0	0	0	0	2	9	2	43	0	0
545	489	0	0	0	0	1	9	0	66	4	0
546	502	12	0	3	15	0	0	0	0	0	0
546	492	0	0	0	1	2	7	1	33	4	0
546	466	7	0	1	12	0	0	0	0	0	0
511	434	0	0	0	0	0	0	0	0	0	0
505	489	3	0	0	3	1	10	0	58	2	0
505	377	0	0	0	0	3	10	0	49	7	1
510	416	4	0	0	10	0	0	0	0	0	0
510	636	0	0	0	0	1	10	1	31	0	0
509	466	4	0	0	5	0	0	0	0	0	0
509	622	0	0	0	0	0	9	0	42	1	0
514	381	0	0	0	1	2	8	0	48	0	0
507	500	36	0	6	38	0	0	0	0	0	0
507	447	0	0	0	0	2	8	0	50	0	0
512	408	12	0	1	17	0	0	0	0	0	0
512	516	0	0	0	0	2	8	1	56	6	0
513	473	6	0	0	8	0	0	0	0	0	0
513	443	95	2	8	104	0	0	0	0	0	0
516	421	30	0	3	31	0	0	0	0	0	0
516	523	4	0	1	5	0	0	0	0	0	0
508	464	2	0	0	16	0	0	0	0	0	0
508	510	1	0	0	3	0	0	0	0	0	0
508	455	0	0	0	0	1	3	0	16	0	0
515	552	62	2	7	47	0	0	0	0	0	0
515	622	0	0	0	1	0	0	0	0	0	0
515	400	0	0	0	0	4	3	0	8	0	0
518	399	11	1	0	6	0	0	0	0	0	0
518	696	0	0	0	0	0	3	0	15	2	0
522	442	0	0	0	1	0	0	0	0	0	0
522	447	0	0	0	0	1	6	1	26	2	0
519	384	5	0	0	13	0	0	0	0	0	0
519	405	0	0	0	0	1	6	0	32	1	0
517	510	56	1	7	44	0	0	0	0	0	0
517	397	27	0	3	51	0	0	0	0	0	0
517	515	0	0	0	0	2	7	0	38	0	0
524	421	14	0	2	23	0	0	0	0	0	0
524	430	0	0	0	1	1	9	1	46	2	0
524	578	0	0	0	0	0	8	0	37	0	0
521	501	7	1	0	9	2	10	1	50	4	0
521	504	7	0	1	21	0	0	0	0	0	0
525	525	36	0	3	40	0	0	0	0	0	0
525	679	73	3	6	63	0	0	0	0	0	0
520	552	18	0	2	26	0	0	0	0	0	0
520	479	12	0	1	16	3	10	0	37	0	0
520	388	0	0	0	0	2	9	0	70	1	0
523	459	35	0	3	61	0	0	0	0	0	0
523	569	17	0	1	38	2	7	0	40	2	0
526	403	4	0	1	3	0	0	0	0	0	0
526	496	0	0	0	0	2	8	0	36	2	0
527	620	2	0	0	13	0	0	0	0	0	0
527	677	0	0	0	0	3	9	1	28	1	0
528	635	9	0	1	16	0	2	0	17	0	0
528	484	0	0	0	0	2	10	0	77	1	0
529	443	88	0	11	94	0	0	0	0	0	0
529	698	12	0	1	25	0	0	0	0	0	0
529	447	0	0	0	0	3	7	2	16	1	0
530	489	0	0	0	0	0	10	0	90	5	0
531	399	15	1	1	16	0	0	0	0	0	0
531	425	2	0	0	5	0	0	0	0	0	0
531	400	0	0	0	0	3	10	0	21	2	0
532	515	4	0	1	4	0	0	0	0	0	0
532	510	0	0	0	0	0	2	0	17	1	0
532	446	0	0	0	0	2	4	0	18	1	0
533	426	140	5	16	107	0	0	0	0	0	0
533	425	0	0	0	1	0	0	0	0	0	0
533	590	14	0	2	11	2	8	0	49	0	0
533	405	15	1	0	25	1	6	0	38	2	0
534	406	23	2	2	22	0	0	0	0	0	0
534	698	0	0	0	0	2	7	1	35	1	0
535	553	24	2	2	11	0	0	0	0	0	0
535	382	0	0	0	0	0	8	1	72	0	0
536	589	6	1	0	2	0	0	0	0	0	0
536	620	0	0	0	0	2	10	0	88	14	0
537	698	16	0	2	27	0	0	0	0	0	0
537	472	0	0	0	0	3	10	3	37	3	0
537	475	0	0	0	0	2	10	2	35	0	0
538	510	25	1	1	32	0	0	0	0	0	0
538	382	0	0	0	0	1	10	0	51	1	0
539	399	53	0	6	61	0	0	0	0	0	0
539	557	0	0	0	0	1	5	0	45	2	0
540	420	0	0	0	1	2	8	0	45	2	0
541	438	51	4	3	32	0	2	0	11	0	0
541	462	54	6	1	39	0	0	0	0	0	0
541	449	0	0	0	0	2	10	1	41	0	0
542	479	41	2	4	33	0	5	0	33	0	0
542	447	0	0	0	0	1	9	0	78	3	0
543	511	101	5	8	116	0	0	0	0	0	0
543	504	4	0	0	8	0	0	0	0	0	0
543	397	0	0	0	0	3	10	1	34	4	0
544	443	54	0	4	63	0	0	0	0	0	0
544	450	18	0	1	28	0	0	0	0	0	0
544	437	1	0	0	3	0	0	0	0	0	0
544	393	0	0	0	0	0	2	0	4	0	0
545	500	12	0	1	12	0	0	0	0	0	0
546	500	15	0	2	19	0	0	0	0	0	0
546	614	67	2	6	68	4	9	0	62	3	0
546	622	0	0	0	0	0	6	0	36	1	1
547	614	18	0	3	25	1	10	0	64	1	1
547	455	0	0	0	0	0	4	0	28	0	0
548	677	19	0	1	27	0	0	0	0	0	0
548	605	0	0	0	0	1	6	0	31	2	1
511	427	0	0	0	0	0	6	0	48	0	0
505	433	65	1	9	53	0	0	0	0	0	0
505	492	0	0	0	0	1	10	1	44	1	0
510	412	2	0	0	3	0	7	1	43	3	0
510	416	0	0	0	0	1	8	0	36	3	0
509	522	54	0	9	52	0	0	0	0	0	0
509	455	0	0	0	0	1	8	0	39	0	0
514	383	14	0	2	15	0	0	0	0	0	0
514	679	0	0	0	0	2	7	0	56	1	1
507	648	4	0	0	14	0	8	0	47	0	0
507	438	16	0	4	11	0	0	0	0	0	0
512	511	34	4	1	15	0	0	0	0	0	0
512	416	11	0	2	21	0	0	0	0	0	0
513	632	130	5	9	127	0	0	0	0	0	0
513	450	2	0	0	4	0	0	0	0	0	0
513	437	0	0	0	0	1	10	1	45	0	0
513	449	0	0	0	0	2	10	0	73	3	0
516	430	5	0	1	6	0	4	0	23	0	0
516	425	0	0	0	0	0	3	0	17	0	0
508	461	23	3	0	9	0	5	1	19	0	0
508	620	0	0	0	0	3	8	0	60	2	1
515	400	1	0	0	1	0	0	0	0	0	0
515	455	0	0	0	0	0	4	0	19	0	0
518	525	8	0	1	8	0	0	0	0	0	0
518	554	31	2	4	21	0	0	0	0	0	0
522	553	0	0	0	6	0	0	0	0	0	0
522	439	0	0	0	3	0	0	0	0	0	0
522	554	0	0	0	0	0	8	0	33	0	0
519	381	0	0	0	6	1	5	0	31	2	1
519	677	0	0	0	0	0	6	1	18	1	0
517	504	0	0	0	2	0	0	0	0	0	0
517	388	0	0	0	0	1	9	0	60	3	0
517	557	0	0	0	0	0	2	0	11	0	0
524	598	8	0	0	13	1	7	1	16	0	0
524	425	27	0	2	46	0	0	0	0	0	0
524	446	0	0	0	0	4	7	2	22	2	0
521	517	21	0	0	39	0	0	0	0	0	0
521	515	4	0	0	6	0	0	0	0	0	0
525	533	14	0	1	26	0	4	0	21	0	0
525	394	0	0	0	0	4	10	1	34	0	0
520	397	1	0	0	3	0	0	0	0	0	0
520	636	17	1	1	12	0	0	0	0	0	0
520	400	0	0	0	0	3	10	0	74	0	0
523	408	15	0	3	16	0	0	0	0	0	0
523	413	20	0	2	41	0	0	0	0	0	0
526	406	45	0	6	64	0	0	0	0	0	0
526	413	56	1	6	70	0	0	0	0	0	0
526	403	0	0	0	0	0	1	0	5	0	0
527	433	10	0	2	11	0	0	0	0	0	0
527	380	52	0	8	54	0	0	0	0	0	0
527	679	31	0	3	28	0	0	0	0	0	0
528	510	6	1	0	1	0	0	0	0	0	0
528	472	9	0	1	14	0	0	0	0	0	0
528	512	0	0	0	0	0	6	1	28	0	0
529	446	2	0	0	4	0	0	0	0	0	0
529	526	12	0	2	23	0	0	0	0	0	0
529	534	5	0	1	6	5	10	0	80	6	0
530	473	39	0	7	27	0	0	0	0	0	0
531	393	11	0	1	10	0	0	0	0	0	0
531	578	42	0	6	43	0	0	0	0	0	0
531	388	0	0	0	0	2	9	1	49	2	0
532	438	23	1	4	24	0	0	0	0	0	0
532	514	6	0	0	26	0	0	0	0	0	0
533	403	0	0	0	1	0	0	0	0	0	0
533	425	0	0	0	0	1	3	0	13	0	0
534	533	34	1	4	36	0	3	0	20	0	0
534	407	5	0	1	6	3	10	0	80	2	0
535	380	30	0	1	44	0	0	0	0	0	0
535	557	6	0	1	7	0	0	0	0	0	0
535	679	0	0	0	0	2	7	1	52	1	0
536	426	87	2	10	74	0	0	0	0	0	0
536	458	37	1	3	62	0	0	0	0	0	0
536	459	33	1	3	49	0	0	0	0	0	0
536	462	41	3	2	34	0	0	0	0	0	0
536	578	0	0	0	0	3	8	0	42	0	0
537	474	45	0	9	42	0	0	0	0	0	0
537	532	0	0	0	0	1	4	1	20	0	0
538	511	24	1	1	33	0	0	0	0	0	0
538	679	0	0	0	0	0	1	0	8	0	0
539	388	0	0	0	0	0	7	1	21	0	0
539	416	0	0	0	0	1	9	1	76	1	0
540	426	31	0	5	39	0	0	0	0	0	0
540	421	59	1	7	61	0	0	0	0	0	0
540	498	0	0	0	2	0	0	0	0	0	0
541	443	51	1	5	56	0	0	0	0	0	0
541	622	16	2	1	8	0	0	0	0	0	0
541	443	0	0	0	0	1	3	0	13	0	0
542	635	13	0	3	22	0	7	0	60	2	0
542	437	0	0	0	0	1	10	1	64	10	0
543	393	62	2	9	48	0	0	0	0	0	0
543	514	0	0	0	0	1	6	0	41	2	1
544	399	7	0	1	3	0	0	0	0	0	0
544	554	0	0	0	0	1	6	0	35	0	0
544	400	0	0	0	0	1	10	0	44	2	0
545	498	113	3	10	103	0	0	0	0	0	0
545	526	0	0	0	0	1	10	0	59	5	0
546	464	52	1	4	67	0	2	0	16	0	0
511	589	0	0	0	0	0	9	1	61	4	1
505	383	87	0	10	113	0	0	0	0	0	0
505	496	0	0	0	0	0	8	1	53	3	0
510	403	7	0	1	8	0	0	0	0	0	0
510	479	16	1	1	11	1	2	0	13	1	1
509	622	7	0	0	7	0	0	0	0	0	0
509	620	0	0	0	0	0	10	0	57	0	0
514	380	36	0	1	62	0	0	0	0	0	0
514	472	0	0	0	0	2	7	1	18	2	0
507	492	12	0	2	19	1	6	0	34	0	0
507	449	0	0	0	0	2	10	0	35	0	0
512	403	0	0	0	1	0	0	0	0	0	0
512	514	0	0	0	0	2	10	1	42	1	1
513	598	39	1	3	44	0	10	0	48	0	0
516	427	3	0	0	10	0	0	0	0	0	0
516	534	0	0	0	0	0	5	0	37	0	0
508	614	2	0	0	7	2	8	0	36	4	0
508	511	43	1	4	52	0	0	0	0	0	0
508	512	7	0	0	24	2	9	1	57	11	1
515	554	106	8	9	44	0	0	0	0	0	0
515	461	1	0	0	8	1	7	0	59	0	0
518	522	61	0	8	67	0	0	0	0	0	0
518	534	0	0	0	6	3	9	2	38	1	0
518	554	0	0	0	0	1	9	0	36	1	0
522	397	28	1	2	35	0	0	0	0	0	0
522	598	0	0	0	0	3	10	2	28	0	0
519	679	22	0	4	20	0	0	0	0	0	0
519	416	0	0	0	0	1	7	1	28	0	0
517	661	26	1	3	22	2	7	0	54	8	1
517	399	13	0	2	27	0	0	0	0	0	0
517	554	0	0	0	0	2	10	1	34	2	0
524	439	4	0	0	16	0	0	0	0	0	0
524	588	0	0	0	10	0	0	0	0	0	0
524	437	0	0	0	0	3	6	1	32	2	0
521	489	2	0	0	4	3	10	0	45	3	0
521	510	0	0	0	0	0	4	0	20	0	0
525	698	23	1	1	26	0	0	0	0	0	0
525	381	0	0	0	0	0	6	0	47	2	0
520	400	0	0	0	3	0	0	0	0	0	0
520	486	9	0	1	8	1	6	0	67	4	2
523	464	3	0	0	9	0	0	0	0	0	0
523	406	3	0	0	12	0	0	0	0	0	0
526	408	0	0	0	5	0	0	0	0	0	0
526	489	0	0	0	0	3	9	1	23	2	0
527	623	3	0	0	15	1	3	0	25	1	1
527	679	0	0	0	0	0	3	0	11	0	0
528	485	33	0	5	37	0	0	0	0	0	0
528	472	0	0	0	0	1	10	1	49	2	0
528	514	0	0	0	0	1	6	2	16	0	0
529	522	0	0	0	1	0	0	0	0	0	0
529	698	0	0	0	0	0	3	0	11	0	0
530	636	26	2	0	17	0	0	0	0	0	0
530	483	0	0	0	0	0	4	0	44	1	0
531	588	64	3	2	90	0	0	0	0	0	0
531	397	0	0	0	0	2	10	0	66	4	0
532	512	0	0	0	3	1	8	0	63	2	0
533	409	39	0	2	61	0	0	0	0	0	0
534	522	41	0	8	36	0	0	0	0	0	0
534	403	90	0	12	101	0	0	0	0	0	0
535	433	21	0	2	25	0	0	0	0	0	0
535	552	14	0	2	28	0	0	0	0	0	0
535	397	3	0	0	7	0	0	0	0	0	0
535	397	0	0	0	0	1	9	0	70	5	0
536	588	108	6	6	84	0	0	0	0	0	0
536	622	0	0	0	4	0	0	0	0	0	0
537	523	51	2	9	28	0	0	0	0	0	0
537	473	7	0	1	6	0	0	0	0	0	0
538	433	25	1	3	22	0	0	0	0	0	0
538	678	14	0	0	30	2	10	1	37	1	0
538	377	26	0	4	32	0	9	0	49	3	0
538	382	8	1	0	5	0	0	0	0	0	0
538	381	2	0	0	4	0	6	0	52	1	0
538	517	76	1	6	95	0	0	0	0	0	0
538	666	0	0	0	0	1	7	0	36	0	0
539	393	10	0	2	11	0	0	0	0	0	0
540	428	0	0	0	1	2	10	0	55	1	0
540	642	4	0	1	7	0	10	0	57	0	0
541	450	2	0	0	1	0	2	0	17	0	0
541	466	3	0	0	4	0	0	0	0	0	0
541	437	0	0	0	0	2	9	1	33	1	0
542	450	1	0	0	2	0	0	0	0	0	0
542	475	6	1	0	3	0	8	0	65	1	0
543	510	10	0	2	20	0	0	0	0	0	0
543	552	18	0	2	31	0	0	0	0	0	0
543	388	0	0	0	0	2	8	3	12	0	0
543	400	0	0	0	0	0	7	0	55	0	0
544	449	10	0	0	18	0	10	0	56	0	0
544	446	0	0	0	0	1	7	1	47	9	0
545	499	31	0	2	30	0	0	0	0	0	0
546	499	68	1	9	52	0	0	0	0	0	0
546	462	5	0	1	9	0	0	0	0	0	0
547	474	32	1	5	40	0	0	0	0	0	0
547	462	21	1	2	26	0	0	0	0	0	0
547	472	0	0	0	0	0	8	0	34	2	0
548	381	9	0	1	8	0	5	0	31	0	0
548	394	0	0	0	0	0	6	0	50	1	0
549	521	79	4	8	65	0	0	0	0	0	0
511	512	0	0	0	0	2	5	1	26	3	0
505	380	77	2	5	84	0	0	0	0	0	0
505	494	0	0	0	0	0	8	0	55	3	1
510	474	45	0	3	59	0	0	0	0	0	0
509	464	4	0	1	13	0	0	0	0	0	0
509	523	5	0	1	8	0	0	0	0	0	0
514	474	20	0	3	18	0	0	0	0	0	0
514	679	27	0	2	32	0	0	0	0	0	0
514	636	0	0	0	0	3	7	0	39	1	0
507	439	53	2	3	62	0	0	0	0	0	0
512	506	174	7	15	140	0	0	0	0	0	0
512	401	19	0	3	19	0	5	0	27	0	0
513	474	0	0	0	9	0	0	0	0	0	0
513	475	1	0	0	5	2	8	0	63	2	0
513	446	0	0	0	0	5	10	0	54	0	0
516	578	15	0	1	15	0	0	0	0	0	0
516	698	0	0	0	0	2	5	1	14	0	0
508	459	19	1	1	37	0	0	0	0	0	0
508	661	9	0	0	25	2	8	1	27	6	0
508	466	0	0	0	0	2	9	0	40	0	0
515	464	25	0	6	25	0	4	0	27	1	0
515	620	0	0	0	0	4	10	0	74	5	0
518	521	25	1	0	39	0	0	0	0	0	0
518	557	20	1	2	10	0	0	0	0	0	0
522	388	1	0	0	1	0	0	0	0	0	0
522	609	11	1	0	8	1	3	0	28	0	0
522	548	0	0	0	0	0	2	0	11	0	0
519	394	0	0	0	3	1	5	0	19	2	0
519	679	0	0	0	0	1	2	0	9	0	0
517	552	46	0	3	74	0	0	0	0	0	0
517	512	0	0	0	0	1	8	2	18	1	0
524	446	1	0	0	5	0	0	0	0	0	0
524	590	10	0	1	20	2	9	1	33	1	0
521	498	9	0	1	17	0	0	0	0	0	0
521	510	91	3	7	93	0	0	0	0	0	0
521	504	0	0	0	0	0	9	0	56	0	0
525	532	1	0	0	4	0	0	0	0	0	0
525	679	0	0	0	0	1	7	0	37	1	0
525	532	0	0	0	0	0	9	0	51	0	0
520	393	109	7	10	67	0	0	0	0	0	0
520	553	36	0	2	51	0	2	0	18	1	0
520	632	54	1	6	51	0	0	0	0	0	0
520	397	0	0	0	0	0	9	0	89	17	0
523	466	0	0	0	2	0	0	0	0	0	0
523	455	0	0	0	0	1	7	1	25	0	0
526	498	68	2	9	69	0	0	0	0	0	0
526	494	0	0	0	0	1	10	0	66	1	0
527	461	10	0	0	22	0	8	0	49	3	0
527	377	0	0	0	0	2	9	0	31	3	0
528	479	60	4	4	50	0	7	0	52	2	0
528	634	0	0	0	0	1	5	0	69	0	0
529	450	12	0	2	9	0	0	0	0	0	0
529	437	1	0	0	1	0	0	0	0	0	0
529	532	0	0	0	0	1	10	2	71	0	0
530	479	41	2	4	25	0	5	1	42	0	0
530	501	0	0	0	0	3	10	0	60	7	0
531	557	35	2	3	32	0	0	0	0	0	0
531	589	15	0	3	14	0	0	0	0	0	0
531	557	0	0	0	0	1	4	0	34	0	0
532	661	14	0	1	30	1	9	0	94	12	1
533	406	76	2	7	66	0	0	0	0	0	0
533	416	0	0	0	0	0	10	0	70	0	0
534	521	108	5	6	105	0	0	0	0	0	0
534	413	22	1	3	23	0	0	0	0	0	0
535	383	129	3	8	143	0	0	0	0	0	0
535	554	201	10	21	128	0	0	0	0	0	0
535	381	0	0	0	0	2	9	0	47	1	0
536	421	15	0	2	17	0	0	0	0	0	0
536	427	28	0	1	35	0	0	0	0	0	0
536	620	2	0	0	2	0	0	0	0	0	0
537	522	2	0	0	8	0	0	0	0	0	0
537	635	42	3	3	34	2	7	0	21	0	0
537	698	0	0	0	0	2	4	0	29	1	0
538	666	39	3	1	37	0	0	0	0	0	0
538	380	0	0	0	0	0	1	0	12	0	0
539	413	32	3	1	28	0	0	0	0	0	0
539	400	0	0	0	0	2	10	0	32	0	0
540	590	4	0	1	4	1	5	0	27	0	0
540	496	35	3	3	23	3	10	0	64	11	0
541	459	45	0	4	80	0	0	0	0	0	0
541	466	0	0	0	0	1	10	0	90	3	1
542	439	105	8	4	70	0	0	0	0	0	0
542	472	2	0	0	2	0	0	0	0	0	0
543	517	6	0	0	31	0	0	0	0	0	0
543	505	19	0	2	39	2	9	0	47	2	1
543	397	16	0	2	38	0	0	0	0	0	0
544	438	4	0	0	7	0	0	0	0	0	0
544	552	58	0	4	110	0	0	0	0	0	0
545	522	51	1	7	61	0	0	0	0	0	0
545	648	0	0	0	0	1	9	0	62	0	0
545	534	0	0	0	0	2	9	0	60	3	1
546	489	13	0	2	12	1	7	0	37	2	0
546	466	0	0	0	0	1	6	0	40	2	0
547	455	69	0	5	73	0	0	0	0	0	0
547	622	0	0	0	0	2	9	0	56	0	0
548	679	62	4	2	69	0	0	0	0	0	0
548	449	0	0	0	0	1	10	0	40	0	0
511	514	0	0	0	0	1	6	1	38	1	1
505	381	0	0	0	0	2	7	0	52	3	0
510	406	0	0	0	1	0	0	0	0	0	0
510	635	9	0	2	13	0	7	0	37	0	0
509	455	29	0	5	31	0	0	0	0	0	0
509	459	70	1	4	82	0	0	0	0	0	0
509	534	0	0	0	0	4	9	1	49	4	1
514	635	32	1	2	41	1	5	0	34	0	0
514	382	4	0	1	3	0	0	0	0	0	0
507	498	20	0	3	24	0	0	0	0	0	0
507	437	0	0	0	0	2	7	1	19	1	0
512	507	12	0	1	19	0	0	0	0	0	0
512	414	15	0	2	25	2	6	0	67	1	0
513	485	17	0	3	27	0	0	0	0	0	0
513	438	26	0	5	31	0	0	0	0	0	0
513	636	0	0	0	0	1	10	0	37	0	0
516	522	77	2	7	83	0	0	0	0	0	0
516	578	0	0	0	0	0	3	0	21	0	0
508	517	4	0	0	7	0	0	0	0	0	0
508	504	40	1	5	37	0	0	0	0	0	0
515	553	9	0	2	15	2	4	0	19	3	0
515	459	11	0	1	21	0	0	0	0	0	0
515	466	0	0	0	0	0	10	0	64	3	0
518	687	2	0	0	9	1	9	0	53	0	0
518	388	0	0	0	0	0	7	1	36	1	0
522	554	15	0	1	25	0	0	0	0	0	0
522	594	0	0	0	0	1	10	1	34	0	0
519	677	6	0	0	12	0	0	0	0	0	0
519	412	0	0	0	0	2	6	1	34	2	0
517	511	17	1	1	13	0	0	0	0	0	0
517	400	11	0	1	16	0	0	0	0	0	0
517	400	0	0	0	0	1	10	0	70	1	0
524	450	49	1	4	47	0	0	0	0	0	0
524	578	15	0	0	31	0	0	0	0	0	0
524	447	0	0	0	0	0	6	0	33	2	0
521	496	0	0	0	1	2	10	0	62	2	0
521	512	4	0	0	14	1	7	0	45	3	0
525	521	22	0	2	28	0	0	0	0	0	0
525	382	0	0	0	0	2	10	0	38	0	0
520	554	41	2	5	24	0	0	0	0	0	0
520	634	58	3	3	39	0	0	0	0	0	0
520	554	0	0	0	0	1	10	0	62	0	0
523	461	9	1	0	6	1	10	3	26	0	0
523	466	0	0	0	0	4	7	0	23	2	0
526	502	81	7	3	74	0	0	0	0	0	0
526	416	0	0	0	0	0	7	0	47	1	0
527	458	1	0	0	4	0	0	0	0	0	0
527	466	4	0	0	24	0	0	0	0	0	0
527	620	0	0	0	0	1	7	0	30	2	0
527	455	0	0	0	0	0	3	0	12	1	0
528	511	53	4	2	30	0	0	0	0	0	0
528	484	7	0	1	11	0	0	0	0	0	0
528	505	0	0	0	0	2	6	0	41	5	0
529	697	0	0	0	1	0	0	0	0	0	0
529	524	0	0	0	0	0	9	0	66	1	0
530	498	4	0	1	9	0	0	0	0	0	0
530	472	0	0	0	0	0	6	0	50	2	0
531	397	10	0	0	13	0	0	0	0	0	0
531	400	29	0	4	19	0	0	0	0	0	0
531	388	1	0	0	1	0	0	0	0	0	0
531	589	0	0	0	0	1	10	1	48	1	0
532	439	77	2	7	87	0	0	0	0	0	0
532	504	7	0	1	11	0	0	0	0	0	0
533	408	1	0	0	2	0	0	0	0	0	0
533	434	0	0	0	0	4	10	1	43	0	0
534	698	0	0	0	0	0	0	0	0	0	0
534	409	15	2	0	7	0	0	0	0	0	0
534	405	0	0	0	0	0	10	1	39	1	0
535	679	22	2	1	18	0	0	0	0	0	0
535	554	0	0	0	0	1	10	0	55	1	1
536	422	11	0	2	16	0	0	0	0	0	0
536	461	1	0	0	3	2	10	0	67	2	1
537	525	1	0	0	2	0	0	0	0	0	0
537	632	43	2	5	31	0	0	0	0	0	0
538	383	15	0	3	30	0	0	0	0	0	0
538	514	0	0	0	0	0	10	0	40	0	0
539	408	36	0	6	34	0	0	0	0	0	0
539	386	0	0	0	0	2	10	0	61	1	1
540	578	8	1	0	6	0	0	0	0	0	0
540	501	16	1	2	14	2	10	0	74	1	0
541	455	35	0	6	32	0	0	0	0	0	0
541	455	0	0	0	0	0	3	0	25	1	0
542	443	117	2	9	113	0	0	0	0	0	0
542	484	9	0	1	10	0	0	0	0	0	0
542	449	0	0	0	0	1	10	0	56	0	0
543	553	0	0	0	6	0	0	0	0	0	0
543	515	0	0	0	0	2	10	0	42	5	0
544	393	137	4	15	120	0	0	0	0	0	0
544	447	0	0	0	0	1	7	0	45	0	0
545	492	0	0	0	0	4	10	0	71	4	1
546	648	39	0	4	43	1	7	0	31	0	0
546	622	4	0	0	7	0	0	0	0	0	0
546	620	0	0	0	0	1	6	0	30	1	0
547	636	36	2	3	17	0	0	0	0	0	0
547	466	4	0	1	3	0	0	0	0	0	0
548	678	16	1	1	12	2	8	0	57	1	0
548	443	55	0	6	56	0	0	0	0	0	0
511	504	0	0	0	0	1	2	0	27	0	0
505	382	0	0	0	0	0	8	0	55	0	0
510	408	16	0	4	17	0	0	0	0	0	0
510	632	89	4	6	67	0	1	0	11	0	0
509	620	59	1	1	75	0	0	0	0	0	0
509	524	0	0	0	0	4	9	0	50	7	0
514	473	25	1	2	12	0	0	0	0	0	0
514	636	7	0	1	5	0	0	0	0	0	0
514	677	0	0	0	0	0	8	1	41	0	0
507	642	2	0	0	5	0	4	0	31	0	0
507	609	0	0	0	0	2	6	0	34	0	0
512	406	22	1	3	44	0	0	0	0	0	0
512	505	0	0	0	0	3	10	0	62	2	1
513	636	1	0	0	2	0	0	0	0	0	0
513	439	33	0	6	29	0	0	0	0	0	0
516	426	28	0	6	25	0	0	0	0	0	0
516	525	65	1	7	54	0	0	0	0	0	0
508	455	13	0	1	25	0	0	0	0	0	0
508	509	28	0	4	28	0	0	0	0	0	0
508	514	9	1	0	6	0	0	0	0	0	0
515	399	104	3	11	93	0	0	0	0	0	0
515	614	4	0	1	7	2	10	0	115	2	1
515	622	0	0	0	0	0	5	0	41	1	0
518	553	52	0	9	51	0	0	0	0	0	0
518	557	0	0	0	0	0	2	0	11	0	0
522	400	6	0	0	20	0	0	0	0	0	0
522	397	0	0	0	0	1	8	0	31	3	0
519	678	9	0	1	16	0	9	0	48	0	0
519	413	0	0	0	0	0	1	0	7	0	0
517	514	0	0	0	1	0	0	0	0	0	0
517	388	2	0	0	2	0	0	0	0	0	0
524	438	9	0	1	13	0	0	0	0	0	0
524	426	16	1	2	17	0	0	0	0	0	0
524	589	0	0	0	0	3	10	2	45	0	0
521	642	43	2	3	36	0	0	0	0	0	0
521	661	20	1	2	14	3	9	1	43	8	2
525	522	46	0	5	60	0	0	0	0	0	0
525	383	39	1	4	57	0	0	0	0	0	0
525	524	0	0	0	0	1	10	0	48	2	0
520	399	81	6	5	65	0	0	0	0	0	0
520	635	116	5	9	89	0	8	0	56	0	0
520	634	0	0	0	0	1	2	0	32	0	0
523	620	23	1	2	16	0	0	0	0	0	0
523	416	0	0	0	0	2	10	1	36	1	0
526	412	1	0	0	4	0	4	1	25	1	0
527	614	3	0	0	6	0	0	0	0	0	0
527	394	0	0	0	0	0	5	0	36	2	0
527	622	0	0	0	0	1	5	0	27	0	0
528	636	7	0	1	18	0	0	0	0	0	0
528	661	0	0	0	0	3	8	1	31	2	1
529	598	35	1	1	24	1	0	0	4	0	0
529	532	0	0	0	6	0	0	0	0	0	0
529	449	0	0	0	0	0	2	0	3	0	0
530	635	108	1	15	94	0	0	0	0	0	0
530	496	0	0	0	0	1	10	0	85	2	0
530	484	0	0	0	0	1	5	0	27	0	0
531	426	50	1	4	64	0	0	0	0	0	0
531	428	20	1	1	15	2	10	0	38	0	0
531	430	0	0	0	0	2	10	0	70	3	0
532	443	101	0	10	121	0	0	0	0	0	0
532	517	13	0	1	32	0	0	0	0	0	0
532	514	0	0	0	0	1	10	1	48	0	0
533	416	3	0	0	9	0	0	0	0	0	0
534	408	9	0	2	5	0	0	0	0	0	0
534	532	0	0	0	0	0	8	0	54	2	0
535	393	0	0	0	2	0	0	0	0	0	0
535	557	0	0	0	0	0	1	0	2	0	0
536	590	51	1	5	45	1	7	0	19	2	0
536	455	0	0	0	2	0	0	0	0	0	0
536	614	10	0	2	12	3	10	0	74	0	0
536	455	0	0	0	0	0	7	0	31	0	0
537	534	19	0	2	48	0	6	0	58	1	0
537	636	0	0	0	0	2	10	2	22	0	0
538	509	10	0	1	13	0	0	0	0	0	0
538	677	0	0	0	0	2	10	1	35	0	0
539	553	177	9	17	132	0	4	0	48	3	1
540	422	30	2	2	17	0	0	0	0	0	0
540	489	25	1	3	23	2	10	1	72	0	0
541	458	4	0	0	5	0	0	0	0	0	0
541	620	0	0	0	0	0	10	0	107	1	0
541	447	0	0	0	0	2	6	1	29	1	0
542	474	13	0	3	15	0	0	0	0	0	0
542	472	0	0	0	0	1	10	0	86	2	0
543	509	47	2	4	48	0	0	0	0	0	0
543	554	1	0	0	5	0	0	0	0	0	0
543	504	0	0	0	0	1	10	0	24	0	0
544	598	9	0	0	22	0	10	0	43	2	0
544	554	2	0	0	1	0	0	0	0	0	0
545	523	0	0	0	4	0	0	0	0	0	0
545	533	25	0	3	34	0	4	0	36	0	0
545	496	0	0	0	0	2	10	0	64	1	0
546	642	32	1	2	34	1	8	0	45	1	0
546	623	10	0	1	18	0	2	0	15	0	0
547	485	70	2	7	80	0	0	0	0	0	0
547	459	29	0	3	34	0	0	0	0	0	0
547	636	0	0	0	0	5	10	0	59	0	0
548	442	47	2	5	47	0	0	0	0	0	0
544	439	4	0	1	3	0	0	0	0	0	0
544	446	6	0	1	10	0	0	0	0	0	0
544	397	0	0	0	0	3	10	0	55	4	0
545	520	122	6	14	77	0	0	0	0	0	0
545	687	10	0	1	8	0	10	0	62	0	0
545	642	0	0	0	0	1	8	0	55	0	0
546	496	16	1	2	14	3	9	0	43	2	0
546	620	28	1	3	28	0	0	0	0	0	0
547	635	51	1	3	51	1	10	0	46	1	1
547	622	1	0	0	6	0	0	0	0	0	0
547	475	0	0	0	0	0	8	0	32	0	0
548	383	22	0	4	28	0	0	0	0	0	0
548	439	25	1	1	23	0	0	0	0	0	0
548	677	0	0	0	0	0	4	0	32	0	0
549	523	7	0	1	15	0	0	0	0	0	0
546	461	1	0	0	2	1	10	0	48	2	0
547	632	48	2	5	47	0	0	0	0	0	0
547	473	5	0	0	13	0	0	0	0	0	0
547	464	12	0	1	20	0	1	0	9	0	0
547	461	11	1	0	20	2	10	2	62	5	0
548	384	2	0	0	8	0	0	0	0	0	0
548	609	0	0	0	0	2	7	0	43	3	0
549	517	108	2	13	110	0	0	0	0	0	0
549	687	0	0	0	1	1	10	0	81	2	0
547	486	10	1	0	4	3	8	0	40	0	0
547	466	0	0	0	0	2	9	0	59	1	1
548	382	10	0	2	12	0	0	0	0	0	0
548	447	0	0	0	0	0	9	0	76	1	0
549	510	106	3	14	54	0	0	0	0	0	0
549	524	33	1	4	31	0	0	0	0	0	0
549	524	0	0	0	0	1	10	1	90	2	0
548	437	0	0	0	0	4	10	0	39	3	0
549	506	100	3	12	84	0	0	0	0	0	0
549	525	23	1	3	19	0	0	0	0	0	0
548	598	0	0	0	0	0	8	0	38	1	1
549	533	11	0	1	14	0	4	0	39	1	0
549	514	0	0	0	0	2	7	0	50	3	1
548	382	0	0	0	0	0	8	0	64	7	0
549	661	12	1	0	7	2	10	0	92	3	0
549	504	0	0	0	0	2	10	0	62	6	0
548	679	0	0	0	0	0	4	0	34	1	0
549	522	0	0	0	3	0	0	0	0	0	0
549	505	0	0	0	0	3	9	0	68	1	0
549	511	39	2	3	21	0	0	0	0	0	0
549	534	4	0	1	2	2	10	0	86	4	1
549	512	0	0	0	0	1	8	1	49	2	0
549	529	5	0	1	16	1	10	0	95	13	0
\.


--
-- Data for Name: team; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.team (teamid, teamname, coachid, captainid, teampicpath, totalwins, totallosses, draws, wicketkeeperid) FROM stdin;
30	England	13	417	http://localhost:3000/1704256896219_eng.png	25	54	0	417
29	Bangladesh	19	403	http://localhost:3000/1704256790030_bangladesh.png	17	61	0	415
27	Australia	11	385	http://localhost:3000/1704252659457_aus.jpeg	81	17	0	390
24	Pakistan	9	487	http://localhost:3000/1704130636982_pak.png	34	45	0	497
31	Netherlands	16	454	http://localhost:3000/1704256951686_ned.png	18	60	0	454
26	India	12	443	http://localhost:3000/1704133826892_india.png	88	9	0	445
34	Sri Lanka	15	520	http://localhost:3000/1704260138724_sri.png	19	60	0	520
33	New Zealand	17	470	http://localhost:3000/1704257182437_nz.png	43	46	0	471
28	Afghanistan	10	379	http://localhost:3000/1704256678381_afg.png	36	43	0	433
32	South Africa	18	503	http://localhost:3000/1704257056571_sa.jpg	61	27	0	506
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
Paul Wilson	32	http://localhost:3000/1704258752018_wilson.webp	7	18
Paul Reiffel	34	http://localhost:3000/1704258487608_paul.webp	7	11
Adrian Holdstock	34	http://localhost:3000/1704258276338_adrian.jpg	12	6
Chris Brown	25	http://localhost:3000/1704258658584_brown.jpg	11	15
Chris Gaffaney	33	http://localhost:3000/1704258120432_chris gaffaney.jpg	11	4
Richard Illingworth	32	http://localhost:3000/1704258338191_richard.webp	9	7
Joel Wilson	38	http://localhost:3000/1704258572543_joel.webp	14	14
Alex Wharf	32	http://localhost:3000/1704258721237_alex.webp	9	17
Ahsan Raza	32	http://localhost:3000/1704258463169_ahsan.webp	24	10
Rod Tucker	29	http://localhost:3000/1704258518788_rod.webp	7	12
Kumar Dharmasena	32	http://localhost:3000/1704258020393_kumar.webp	13	2
Michael Gough	35	http://localhost:3000/1704258231452_gough.jpg	9	5
Marais Erasmus	31	http://localhost:3000/1704258077524_marais.webp	12	3
Richard Kettleborough	29	http://localhost:3000/1704258403923_kettle.webp	9	8
Nitin Menon	29	http://localhost:3000/1704258438196_menon.webp	10	9
Sharfuddoula	32	http://localhost:3000/1704258685558_sharf.jpg	8	16
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
47	projectdemo	http://localhost:3000/1704269073745_aus.jpeg	playermanager	$2b$10$/aUhRNpnyq6.d3uy.p.T9uEJl78YkPbmQAki7.wvvaZJtltbBOc2G	2024-01-03	$2b$10$/aUhRNpnyq6.d3uy.p.T9uEJl78YkPbmQAki7.wvvaZJtltbBOc2G
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

SELECT pg_catalog.setval('public.location_locationid_seq', 64, true);


--
-- Name: match_matchid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.match_matchid_seq', 550, true);


--
-- Name: player_playerid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.player_playerid_seq', 700, true);


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

SELECT pg_catalog.setval('public.users_userid_seq', 48, true);


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
GRANT USAGE ON SCHEMA public TO projectdemo;


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
GRANT SELECT ON SEQUENCE public.coach_coachid_seq TO projectdemo;


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
GRANT SELECT ON SEQUENCE public.country_countryid_seq TO projectdemo;


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
GRANT SELECT ON SEQUENCE public.location_locationid_seq TO projectdemo;


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
GRANT SELECT ON SEQUENCE public.match_matchid_seq TO projectdemo;


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
GRANT SELECT ON SEQUENCE public.player_playerid_seq TO projectdemo;


--
-- Name: TABLE playerrank; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.playerrank TO admin;
GRANT INSERT ON TABLE public.playerrank TO datamanager;
GRANT ALL ON TABLE public.playerrank TO playermanager;


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
GRANT ALL ON TABLE public.scorecard TO tournamentmanager;


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
GRANT SELECT ON SEQUENCE public.team_teamid_seq TO projectdemo;


--
-- Name: TABLE teamrank; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.teamrank TO admin;
GRANT INSERT ON TABLE public.teamrank TO datamanager;
GRANT ALL ON TABLE public.teamrank TO teammanager;


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
GRANT SELECT ON SEQUENCE public.tournament_tournamentid_seq TO projectdemo;


--
-- Name: TABLE tournament_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.tournament_view TO tournamentmanager;
GRANT SELECT ON TABLE public.tournament_view TO admin;


--
-- Name: SEQUENCE umpire_umpireid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public.umpire_umpireid_seq TO insertion;
GRANT SELECT ON SEQUENCE public.umpire_umpireid_seq TO projectdemo;


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
GRANT SELECT ON SEQUENCE public.users_userid_seq TO projectdemo;


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

