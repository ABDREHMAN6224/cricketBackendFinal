------------------------------------------------------------------------------------------------------------------------
-- TRIGGERS
------------------------------------------------------------------------------------------------------------------------
-- MATCH TABLE TRIGGERS
------------------------------------------------------------------------------------------------------------------------
create or replace function match_creation()
returns trigger as $$
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
$$ language plpgsql;

drop trigger if exists match_creation on match cascade;
create trigger match_creation
before insert on match
execute procedure match_creation();


--increase the number of matches for umpire when a match is assigned to him

drop function if exists umpire_match_increase() cascade;
create or replace function match_insertion()
returns trigger as $$
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
$$ language plpgsql;


drop trigger if exists umpire_match_increase on match cascade;
create trigger umpire_match_increase
after insert on match
for each row
execute procedure match_insertion();


create or replace function match_delete()
returns trigger as $$
begin
    --check if match data is in scorecard, if yes then delete from scorecard otherwise just delete match
    if exists(select * from scorecard where matchid=old.matchid) then
        delete from scorecard where matchid=old.matchid;
    end if;
    return old;
end;
$$ language plpgsql;

drop trigger if exists match_delete_trig on match cascade;
create trigger match_delete_trig
before delete on match
execute procedure match_delete();
------------------------------------------------------------------------------------------------------------------------
-- PLAYER TABLE TRIGGERS
------------------------------------------------------------------------------------------------------------------------
--after insert assign maximum rank to player in playerrank table for baatingrank,allrounderank,bowlingrank
create or replace function player_insertion()
returns trigger as $$
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
$$ language plpgsql;

drop trigger if exists player_insertion on player cascade;
create trigger player_insertion
after insert on player
for each row
execute procedure player_insertion();

--after delete delete from playerrank table and update playerrank table
--after delete delete from playerrank table and update playerrank table
create or replace function player_deletion()
returns trigger as $$
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
$$ language plpgsql;

drop trigger if exists player_deletion on player cascade;
create trigger player_deletion
before delete on player
for each row
execute procedure player_deletion();




------------------------------------------------------------------------------------------------------------------------
-- RANK TABLE TRIGGERS (STARTED TODAY)
------------------------------------------------------------------------------------------------------------------------

        // --write trigger for this
        create or replace function updatePlayerRank() returns trigger as $$
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
        $$ language plpgsql;

        create trigger updatePlayerRank after update on playerrank for each row execute procedure updatePlayerRank();

        drop trigger if exists player_rank_updation_trig on playerrank cascade;
        drop trigger if exists updatePlayerRank on playerrank cascade;

create or replace function team_rank_updation()
returns trigger as $$
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
$$ language plpgsql;

drop trigger if exists team_rank_updation_trig on teamrank cascade;
create trigger team_rank_updation_trig
after update on teamrank
execute procedure team_rank_updation();

--check that rank before insertio is not greater than max rank+1, if yes then raise exception 
create or replace function player_rank_insertion()
returns trigger as $$
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
$$ language plpgsql;

drop trigger if exists player_rank_insertion_trigger on playerrank cascade;
create trigger player_rank_insertion_trigger
before insert on playerrank
for each row
execute procedure player_rank_insertion();

--check that rank before insertio is not greater than max rank+1, if yes then raise exception
create or replace function team_rank_insertion()
returns trigger as $$
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
$$ language plpgsql;

drop trigger if exists team_rank_insertion_trigger on teamrank cascade;
create trigger team_rank_insertion_trigger
before insert on teamrank
for each row
execute procedure team_rank_insertion();



------------------------------------------------------------------------------------------------------------------------
-- TEAM TABLE TRIGGERS
------------------------------------------------------------------------------------------------------------------------
--while assigning coachid check that coachid is not already assigned to another team
create or replace function team_coachid_check()
returns trigger as $$
begin
    if exists(select * from team where coachid=new.coachid and teamid!=new.teamid) then
        raise exception 'Coach already assigned to another team';
    end if;
    return new;
end;
$$ language plpgsql;

drop trigger if exists team_coachid_check on team cascade;
create trigger team_coachid_check
before update on team
for each row
execute procedure team_coachid_check();

--while assigning captainid check that captainid is not already assigned to another team
create or replace function team_captainid_check()
returns trigger as $$
begin
    --check if captain is assigned to another team but not check the same team
    if exists(select * from team where captainid=new.captainid and teamid!=new.teamid) then
        raise exception 'Captain already assigned to another team';
    end if;
    return new;
end;
$$ language plpgsql;

drop trigger if exists team_captainid_check on team cascade;
create trigger team_captainid_check
before update on team
for each row
execute procedure team_captainid_check();

--while assigning wicketkeeperid check that wicketkeeperid is not already assigned to another team
create or replace function team_wicketkeeperid_check()
returns trigger as $$
begin
    if exists(select * from team where wicketkeeperid=new.wicketkeeperid and teamid!=new.teamid) then
        raise exception 'Wicketkeeper already assigned to another team';
    end if;
    return new;
end;
$$ language plpgsql;

drop trigger if exists team_wicketkeeperid_check on team cascade;
create trigger team_wicketkeeperid_check
before update on team
for each row
execute procedure team_wicketkeeperid_check();

--before insertion into team check all the constraints
create or replace function team_insertion()
returns trigger as $$
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
$$ language plpgsql;

drop trigger if exists team_insertion on team cascade;
create trigger team_insertion
before insert on team
for each row
execute procedure team_insertion();

create or replace function team_after_insertion()
returns trigger as $$
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
$$ language plpgsql;

drop trigger if exists team_after_insertion on team cascade;
create trigger team_after_insertion
after insert on team
for each row
execute procedure team_after_insertion();


--before delte set players teamid to null, delte matches,delete rank and updat eother ranks
create or replace function team_deletion()
returns trigger as $$
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
$$ language plpgsql;

drop trigger if exists team_deletion on team cascade;
create trigger team_deletion
before delete on team
for each row
execute procedure team_deletion();

------------------------------------------------------------------------------------------------------------------------
-- SCORECARD TABLE TRIGGERS
------------------------------------------------------------------------------------------------------------------------
create or replace function scorecard_insertion()
returns trigger as $$
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
$$ language plpgsql;

drop trigger if exists scorecard_insertion on scorecard cascade;
create trigger scorecard_insertion
after insert on scorecard
for each row
execute procedure scorecard_insertion();
    
    
------------------------------------------------------------------------------------------------------------------------
-- TOURNAMENT TABLE TRIGGERS
------------------------------------------------------------------------------------------------------------------------
--before deletion delete any matches that have sam etournamentid
create or replace function tournament_deletion()
returns trigger as $$
begin
    delete from match where tournamentid=old.tournamentid;
    return old;
end;
$$ language plpgsql;

drop trigger if exists tournament_deletion on tournament cascade;
create trigger tournament_deletion
before delete on tournament
for each row
execute procedure tournament_deletion();

------------------------------------------------------------------------------------------------------------------------
-- USERS TABLE TRIGGERS
------------------------------------------------------------------------------------------------------------------------
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
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--CREATE ALL POSSIBLE VIEWS ON DATA
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--create player view
create or replace view player_view as
select playername,playertype,teamname,battingrank,bowlingrank,allrounderrank,noruns,nosixes,nofours,ballsfaced,totalinningsbatted,nowickets,oversbowled,maidenovers,runsconceded,totalinningsbowled,noballsbowled from player natural join team natural join playerrank natural left join batsman natural left join bowler;

--create team view
--team captainid joins with player playerid to get playername as captain, team wicketkeeperid joins with player playerid to get playername as wicketkeeper,team coahid joins with coach coachid to get coachname as coach

create or replace view team_view as
select team.teamname,totalwins,totallosses,draws,odirank,t20irank,testrank,captain.playername as captain,wicketkeeper.playername as keeper,coachname as coach from team natural join teamrank natural join coach join player as captain on captain.playerid=team.captainid join player as wicketkeeper on wicketkeeper.playerid=team.wicketkeeperid;


--create umpire view
create or replace view umpire_view as
select umpirename,nomatches from umpire;

--create coach view
create or replace view coach_view as
select coachname,teamname from coach natural join team;

--create captain view
create or replace view captain_view as
select playername,matchesascaptain,totalwins from captain natural join player;

--create wicketkeeper view
create or replace view wicketkeeper_view as
select playername,totalcatches,totalstumps from wicketkeeper natural join player;

--create batsman view
create or replace view batsman_view as
select playername,noruns,nosixes,nofours,ballsfaced,totalinningsbatted from batsman natural join player;

--create bowler view
create or replace view bowler_view as
select playername,nowickets,oversbowled,maidenovers,runsconceded,totalinningsbowled,noballsbowled from bowler natural join player;

--create allrounder view
create or replace view allrounder_view as
select playername,noruns,nosixes,nofours,ballsfaced,totalinningsbatted,nowickets,oversbowled,maidenovers,runsconceded,totalinningsbowled,noballsbowled from batsman natural join bowler natural join player;

--create match view
create or replace view match_view as
select matchid,team1.teamname as team1,team2.teamname as team2,date,location,umpirename,winner.teamname as winner from match join team as team1 on team1.teamid=match.team1id join team as team2 on team2.teamid=match.team2id join location on location.locationid=match.locationid join umpire on umpire.umpireid=match.umpire join team as winner on winner.teamid=match.winnerteam;

--create tournament view
--view tournament name winner teamname startdate enddate
create or replace view tournament_view as
select name as tournamentname,teamname,startdate,enddate from tournament join team on team.teamid=tournament.winning_team;

--create scorecard view
create or replace view scorecard_view as
select matchid,playername,noruns,nosixes,nofours,noballsfaced,nowickets,oversbowled,maidenovers,runsconceded from scorecard natural join player;

--create playerrank view
create or replace view playerrank_view as
select playername,battingrank,bowlingrank,allrounderrank from playerrank natural join player;

--create teamrank view
create or replace view teamrank_view as
select teamname,t20irank,odirank,testrank from teamrank natural join team;


------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--GRANT ACCESS TO ALL VIEWS TO USERS ACCORDING TO THEIR ROLES
--datamanager can access no views
--playermanager can access player_view,playerrank_view,allrounder_view,batsman_view,bowler_view,scorecard_view
--teammanager can access team_view,teamrank_view,coach_view,captain_view,wicketkeeper_view
--tournamentmanager can access tournament_view,match_view,scorcard_view,umpire_view
--admin can access all views
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
GRANT SELECT ON player_view TO playermanager;
GRANT SELECT ON playerrank_view TO playermanager;
GRANT SELECT ON allrounder_view TO playermanager;
GRANT SELECT ON batsman_view TO playermanager;
GRANT SELECT ON bowler_view TO playermanager;
GRANT SELECT ON scorecard_view TO playermanager;

GRANT SELECT ON team_view TO teammanager;
GRANT SELECT ON teamrank_view TO teammanager;
GRANT SELECT ON coach_view TO teammanager;
GRANT SELECT ON captain_view TO teammanager;
GRANT SELECT ON wicketkeeper_view TO teammanager;

GRANT SELECT ON tournament_view TO tournamentmanager;
GRANT SELECT ON match_view TO tournamentmanager;
GRANT SELECT ON scorecard_view TO tournamentmanager;
GRANT SELECT ON umpire_view TO tournamentmanager;

GRANT SELECT ON player_view TO admin;
GRANT SELECT ON playerrank_view TO admin;
GRANT SELECT ON allrounder_view TO admin;
GRANT SELECT ON batsman_view TO admin;
GRANT SELECT ON bowler_view TO admin;
GRANT SELECT ON captain_view TO admin;
GRANT SELECT ON scorecard_view TO admin;
GRANT SELECT ON team_view TO admin;
GRANT SELECT ON teamrank_view TO admin;
GRANT SELECT ON coach_view TO admin;
GRANT SELECT ON captain_view TO admin;
GRANT SELECT ON wicketkeeper_view TO admin;
GRANT SELECT ON tournament_view TO admin;
GRANT SELECT ON match_view TO admin;
GRANT SELECT ON scorecard_view TO admin;
GRANT SELECT ON umpire_view TO admin;


--query to delete duplicate rows from table based on playername, only keep one instance of playername
delete from player as p1 where playername in (select playername from player as p2 where p1.playerid!=p2.playerid and p1.playername=p2.playername);