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
    CONSTRAINT batsman_bathand_check CHECK (((bathand)::text = ANY ((ARRAY['Left'::character varying, 'Right'::character varying])::text[])))
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
    CONSTRAINT bowler_bowlhand_check CHECK (((bowlhand)::text = ANY ((ARRAY['Left'::character varying, 'Right'::character varying])::text[]))),
    CONSTRAINT bowler_bowltype_check CHECK (((bowltype)::text = ANY ((ARRAY['Fast'::character varying, 'Medium'::character varying, 'Leg-Spin'::character varying, 'Off-spin'::character varying])::text[])))
);


ALTER TABLE public.bowler OWNER TO postgres;

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
    START WITH 21
    INCREMENT BY 1
    MINVALUE 21
    MAXVALUE 99999
    CACHE 1
);


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
    locationid integer
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
    CONSTRAINT player_playerstatus_check CHECK (((playerstatus)::text = ANY ((ARRAY['active'::character varying, 'retired'::character varying])::text[]))),
    CONSTRAINT player_playertype_check CHECK (((playertype)::text = ANY ((ARRAY['Batsman'::character varying, 'Bowler'::character varying, 'Wicketkeeper'::character varying, 'Allrounder'::character varying])::text[])))
);


ALTER TABLE public.player OWNER TO postgres;

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
    battingrank integer,
    bowlingrank integer,
    allrounderrank integer
);


ALTER TABLE public.playerrank OWNER TO postgres;

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
    t20irank integer NOT NULL,
    odirank integer NOT NULL,
    testrank integer NOT NULL
);


ALTER TABLE public.teamrank OWNER TO postgres;

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
-- Name: umpire_umpireid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.umpire_umpireid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.umpire_umpireid_seq OWNER TO postgres;

--
-- Name: umpire_umpireid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.umpire_umpireid_seq OWNED BY public.umpire.umpireid;


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
    CONSTRAINT role_check CHECK ((lower((userrole)::text) = ANY (ARRAY['playermanager'::text, 'admin'::text, 'teammanager'::text, 'tournamentmanager'::text, 'datamanager'::text])))
);


ALTER TABLE public.users OWNER TO postgres;

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
-- Name: coach coachid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coach ALTER COLUMN coachid SET DEFAULT nextval('public.coach_coachid_seq'::regclass);


--
-- Name: tournament tournamentid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tournament ALTER COLUMN tournamentid SET DEFAULT nextval('public.tournament_tournamentid_seq'::regclass);


--
-- Name: umpire umpireid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.umpire ALTER COLUMN umpireid SET DEFAULT nextval('public.umpire_umpireid_seq'::regclass);


--
-- Name: users userid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN userid SET DEFAULT nextval('public.users_userid_seq'::regclass);


--
-- Data for Name: batsman; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.batsman (playerid, nosixes, nofours, noruns, bathand, ballsfaced, totalinningsbatted) FROM stdin;
37	20	0	200	Right	132	12
32	4	8	84	Left	40	12
31	0	0	0	Left	0	12
39	28	0	264	Right	120	12
36	0	0	0	Right	0	12
30	0	0	30	Left	17	12
2	1	4	40	Left	25	42
49	0	0	0	Right	0	0
47	8	0	92	Left	48	12
46	0	0	16	Right	28	12
41	3	0	60	Right	36	12
38	20	0	220	Left	132	8
29	0	2	11	Left	3	8
26	0	0	0	Right	0	0
27	0	8	50	Left	23	0
44	0	0	0	Right	0	0
45	0	0	0	Right	0	0
\.


--
-- Data for Name: bowler; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bowler (playerid, nowickets, bowlhand, bowltype, oversbowled, maidenovers, runsconceded, totalinningsbowled, dotballs, noballsbowled) FROM stdin;
35	9	Right	Leg-Spin	12	0	0	12	0	0
43	0	Right	Fast	0	0	0	12	0	72
42	0	Right	Leg-Spin	0	0	0	12	0	144
48	0	Right	Leg-Spin	0	0	0	12	0	0
40	0	Right	Fast	16	0	33	12	0	0
33	17	Right	Leg-Spin	21	0	53	12	0	0
38	0	Left	Leg-Spin	8	0	29	7	0	132
29	0	Right	Leg-Spin	0	0	0	7	0	0
2	3	Left	Leg-Spin	30	1	40	20	120	\N
\.


--
-- Data for Name: captain; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.captain (playerid, matchesascaptain, totalwins) FROM stdin;
29	0	0
31	0	0
32	0	0
2	6	5
9	5	0
30	8	8
33	9	1
\.


--
-- Data for Name: coach; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.coach (coachname, picture, coachid) FROM stdin;
Jonathan Trott	http://localhost:3000/1703447060031_intern.png	103
Alim Dar	http://localhost:3000/1703527702799_unsplash.png	3
Rahul Dravid	http://localhost:3000/1703447010250_unsplash.png	101
Faakhir	http://localhost:3000/1703570147285_unsplash.png	4
Abdul Rehman	http://localhost:3000/1703598573596_screenShot.jpg	5
AbdulRehman		6
AbdulRehman		7
\.


--
-- Data for Name: country; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.country (countryid, country) FROM stdin;
1	Australia
2	Bangladesh
3	England
4	India
5	New Zealand
6	Pakistan
7	South Africa
8	Sri Lanka
9	West Indies
10	Zimbabwe
11	Afghanistan
12	Ireland
13	Scotland
14	Netherlands
15	United Arab Emirates
16	Nepal
17	Canada
18	Kenya
19	Namibia
20	Papua New Guinea
21	Zimbabwe
22	Korea
23	testing coutry
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
\.


--
-- Data for Name: match; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.match (matchid, date, tournamentid, team1id, team2id, winnerteam, umpire, locationid) FROM stdin;
1	2023-12-27 00:00:00	1	2	1	2	9	1
2	2023-12-26 00:00:00	1	2	1	2	9	1
3	2023-12-25 00:00:00	1	2	1	2	9	1
4	2023-12-17 00:00:00	1	2	1	2	9	1
5	2023-12-14 00:00:00	1	2	1	1	9	1
6	2023-12-16 00:00:00	3	2	1	2	9	1
7	2023-12-11 00:00:00	1	2	1	2	9	1
8	2023-12-12 00:00:00	1	2	1	2	9	1
9	2023-12-23 00:00:00	1	2	1	2	9	1
10	2023-12-05 00:00:00	1	2	1	2	9	2
11	2023-12-27 00:00:00	1	15	1	2	9	1
12	2023-12-01 00:00:00	1	15	1	2	9	1
13	2023-12-28 00:00:00	1	1	15	15	9	1
14	2023-12-09 00:00:00	1	1	15	1	9	1
15	2023-12-20 00:00:00	1	1	15	1	9	1
16	2023-12-11 00:00:00	1	1	15	1	9	1
17	2023-11-29 00:00:00	1	1	15	1	9	1
18	2023-11-26 00:00:00	1	1	15	1	9	1
19	2023-12-05 00:00:00	1	1	15	\N	9	1
20	2023-10-25 00:00:00	1	1	15	1	9	1
21	2023-12-28 00:00:00	1	1	2	15	9	1
22	2023-12-28 00:00:00	1	2	15	1	9	1
23	2023-12-08 00:00:00	1	1	15	\N	9	1
24	2023-07-13 00:00:00	3	1	15	1	9	1
29	2023-12-29 00:00:00	35	15	1	1	303	1
30	2023-01-02 00:00:00	35	15	1	1	9	2
31	2023-03-28 19:00:00	35	15	1	15	303	1
32	2023-12-31 00:00:00	35	15	1	1	303	1
33	2023-10-12 00:00:00	35	15	1	1	303	1
34	2023-10-30 00:00:00	35	15	1	1	303	1
\.


--
-- Data for Name: player; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.player (playerid, playername, dob, teamid, totalt20i, totalodi, totaltest, playertype, playerstatus, playerpicpath, countryid) FROM stdin;
28	sadsa	2007-12-27	1	3	19	0	Bowler	active	http://localhost:3000/1703620222533_screenShot.jpg	4
42	kunal	2007-12-27	1	3	18	0	Bowler	active	http://localhost:3000/1703695656873_screenShot.jpg	4
43	arbaz	2007-12-27	1	3	18	0	Bowler	active	http://localhost:3000/1703695656873_screenShot.jpg	4
30	Raja	2007-12-27	1	3	18	0	Batsman	active	http://localhost:3000/1703622554711_screenShot.jpg	4
48	arbaaz	2007-12-27	1	3	18	0	Bowler	active	http://localhost:3000/1703700373753_screenShot.jpg	4
2	Abdul Rehman 	1980-11-11	1	53	35	50	Batsman	retired	http://localhost:3000/1703274210260_profile.jpg	4
37	faakhit	2007-12-27	15	3	20	0	Batsman	active	http://localhost:3000/1703664068927_unsplash.png	1
32	khalid	2007-12-27	15	3	20	0	Batsman	active	http://localhost:3000/1703644630273_screenShot.jpg	1
35	qwerty	2007-12-27	15	4	21	1	Bowler	active	http://localhost:3000/1703657109871_unsplash.png	1
41	harsh	2007-12-27	1	3	18	0	Batsman	active	http://localhost:3000/1703695656873_screenShot.jpg	4
33	Abdul Rehman	2007-12-27	15	3	20	0	Bowler	active	http://localhost:3000/1703644707902_screenShot.jpg	1
38	abdullah	2007-12-27	15	3	20	0	Allrounder	active	http://localhost:3000/1703684285880_screenShot.jpg	1
45	Kohli	2007-12-27	\N	0	0	0	Batsman	active	http://localhost:3000/1703695656873_screenShot.jpg	1
49	checking	2007-12-28	\N	0	0	0	Batsman	active	http://localhost:3000/1703747058692_screenShot.jpg	1
26	arman	2007-12-27	\N	0	0	0	Batsman	active	http://localhost:3000/1703617496631_screenShot.jpg	4
44	Kohli	2007-12-27	\N	0	0	0	Batsman	active	http://localhost:3000/1703695656873_screenShot.jpg	1
27	Hammad	2007-12-27	\N	0	2	0	Allrounder	active	http://localhost:3000/1703619898815_screenShot.jpg	6
15	Prasidh Krishna	1980-11-11	1	53	68	50	Bowler	active	https://bcciplayerimages.s3.ap-south-1.amazonaws.com/ipl/IPLHeadshot2023/6.png	4
40	Starc	2007-12-27	15	3	18	0	Bowler	active	http://localhost:3000/1703695495473_unsplash.png	1
31	Abdul	2007-12-27	15	3	20	0	Batsman	active	http://localhost:3000/1703644433645_screenShot.jpg	1
39	Marsh	2007-12-27	15	3	18	0	Batsman	active	http://localhost:3000/1703695495473_unsplash.png	1
34	wqrsads	2007-12-27	15	3	20	0	Bowler	active	http://localhost:3000/1703653616942_screenShot.jpg	1
36	Hmaza	2007-12-27	15	3	20	0	Batsman	active	http://localhost:3000/1703657237115_unsplash.png	1
9	Shardul Thakur	1980-11-11	15	53	70	50	Allrounder	active	https://bcciplayerimages.s3.ap-south-1.amazonaws.com/ipl/IPLHeadshot2023/6.png	1
47	Rohit	2007-12-27	1	3	18	0	Batsman	active	http://localhost:3000/1703695791652_unsplash.png	4
46	Kohli	2007-12-27	1	3	18	0	Batsman	active	http://localhost:3000/1703695791652_unsplash.png	4
29	Test AllRounder	2007-12-27	1	3	19	0	Allrounder	active	http://localhost:3000/1703620619090_unsplash.png	4
\.


--
-- Data for Name: playerrank; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.playerrank (playerid, battingrank, bowlingrank, allrounderrank) FROM stdin;
29	8	6	2
33	12	1	10
41	3	17	17
49	4	23	23
30	5	7	7
2	6	4	4
31	10	8	8
32	11	9	9
35	13	11	11
36	14	12	12
37	15	13	13
39	17	15	15
40	18	16	16
42	20	18	18
43	21	19	19
48	24	22	22
47	1	21	21
46	2	20	20
38	16	14	1
\.


--
-- Data for Name: scorecard; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.scorecard (matchid, playerid, noruns, nosixes, nofours, noballsfaced, nowickets, oversbowled, maidenovers, runsconceded, extras, noballs) FROM stdin;
16	28	100	0	0	230	1	1	0	0	0	0
16	41	0	0	0	0	0	0	0	0	0	0
16	42	30	0	0	12	0	0	0	0	0	0
16	43	5	0	0	1	0	0	0	0	0	0
16	48	0	0	0	0	0	0	0	0	0	0
16	2	0	0	0	0	0	0	0	0	0	0
16	47	0	0	0	0	0	0	0	0	0	0
16	15	0	0	0	0	0	0	0	0	0	0
16	9	100	0	0	89	0	0	0	0	0	0
16	36	0	0	0	0	0	0	0	0	0	0
16	29	0	0	0	0	0	0	0	0	0	0
16	39	0	0	0	0	0	0	0	0	0	0
16	31	0	0	0	0	0	0	0	0	0	0
16	30	0	0	0	0	0	0	0	0	0	0
16	46	0	0	0	0	0	0	0	0	0	0
16	34	0	0	0	0	0	0	0	0	0	0
16	33	0	0	0	0	1	1	0	0	0	0
16	40	0	0	0	0	0	0	0	0	0	0
16	38	0	0	0	0	0	0	0	0	0	0
16	35	0	0	0	0	0	0	0	0	0	0
16	32	0	0	0	0	0	0	0	0	0	0
16	37	0	0	0	2	0	0	0	0	0	0
17	41	0	0	0	0	0	0	0	0	0	0
17	42	30	0	0	12	0	0	0	0	0	0
17	43	5	0	0	1	0	0	0	0	0	0
17	28	100	0	0	230	2	1	0	0	0	0
17	2	0	0	0	0	0	0	0	0	0	0
17	30	0	0	0	0	0	0	0	0	0	0
17	48	0	0	0	0	0	0	0	0	0	0
17	47	0	0	0	0	0	0	0	0	0	0
17	15	0	0	0	0	0	0	0	0	0	0
17	29	0	0	0	0	0	0	0	0	0	0
17	32	0	0	0	0	0	0	0	0	0	0
17	46	0	0	0	0	0	0	0	0	0	0
17	37	0	0	0	2	0	0	0	0	0	0
17	33	0	0	0	0	1	1	0	0	0	0
17	35	0	0	0	0	0	0	0	0	0	0
17	38	0	0	0	0	0	0	0	0	0	0
17	40	0	0	0	0	0	0	0	0	0	0
17	31	0	0	0	0	0	0	0	0	0	0
17	39	0	0	0	0	0	0	0	0	0	0
17	34	0	0	0	0	0	0	0	0	0	0
17	36	0	0	0	0	0	0	0	0	0	0
17	9	100	0	0	89	0	0	0	0	0	0
18	28	100	0	0	230	2	1	0	0	0	0
18	41	0	0	0	0	0	0	0	0	0	0
18	42	30	0	0	12	0	0	0	0	0	0
18	43	5	0	0	1	0	0	0	0	0	0
18	2	0	0	0	0	0	0	0	0	0	0
18	47	0	0	0	0	0	0	0	0	0	0
18	15	0	0	0	0	0	0	0	0	0	0
18	29	0	0	0	0	0	0	0	0	0	0
18	48	0	0	0	0	0	0	0	0	0	0
18	30	0	0	0	0	0	0	0	0	0	0
18	46	0	0	0	0	0	0	0	0	0	0
18	37	0	0	0	2	0	0	0	0	0	0
18	33	0	0	0	0	1	1	0	0	0	0
18	32	0	0	0	0	0	0	0	0	0	0
18	35	0	0	0	0	0	0	0	0	0	0
18	38	0	0	0	0	0	0	0	0	0	0
18	40	0	0	0	0	0	0	0	0	0	0
18	31	0	0	0	0	0	0	0	0	0	0
18	39	0	0	0	0	0	0	0	0	0	0
18	34	0	0	0	0	0	0	0	0	0	0
18	36	0	0	0	0	0	0	0	0	0	0
18	9	100	0	0	89	0	0	0	0	0	0
20	28	100	0	0	230	2	1	0	0	0	0
20	41	0	0	0	0	0	0	0	0	0	0
20	42	30	0	0	12	0	0	0	0	0	0
20	43	5	0	0	1	0	0	0	0	0	0
20	30	0	0	0	0	0	0	0	0	0	0
20	48	0	0	0	0	0	0	0	0	0	0
20	2	0	0	0	0	0	0	0	0	0	0
20	47	0	0	0	0	0	0	0	0	0	0
20	15	0	0	0	0	5	10	0	0	0	0
20	29	0	0	0	0	0	0	0	0	0	0
20	46	0	0	0	0	0	0	0	0	0	0
20	37	0	0	0	2	0	0	0	0	0	0
20	33	0	0	0	0	1	1	0	0	0	0
20	32	0	0	0	0	0	0	0	0	0	0
20	35	0	0	0	0	0	0	0	0	0	0
20	38	0	0	0	0	0	0	0	0	0	0
20	31	0	0	0	0	0	0	0	0	0	0
20	40	0	0	0	0	0	0	0	0	0	0
20	39	0	0	0	0	0	0	0	0	0	0
20	36	0	0	0	0	0	0	0	0	0	0
20	9	100	0	0	89	0	0	0	0	0	0
20	34	0	0	0	0	0	0	0	0	0	0
24	28	100	0	0	230	2	1	0	0	0	0
24	41	0	0	0	0	0	0	0	0	0	0
24	42	30	0	0	12	0	0	0	0	0	0
24	43	5	0	0	1	0	0	0	0	0	0
24	48	0	0	0	0	0	0	0	0	0	0
24	2	0	0	0	0	0	0	0	0	0	0
24	47	0	0	0	0	0	0	0	0	0	0
24	15	0	0	0	0	5	10	0	0	0	0
24	46	0	0	0	0	0	0	0	0	0	0
24	29	0	0	0	0	0	0	0	0	0	0
24	40	0	0	0	0	0	0	0	0	0	0
24	32	0	0	0	0	0	0	0	0	0	0
24	36	0	0	0	0	0	0	0	0	0	0
24	38	0	0	0	0	0	0	0	0	0	0
24	35	0	0	0	0	0	0	0	0	0	0
24	34	0	0	0	0	0	0	0	0	0	0
24	31	0	0	0	0	0	0	0	0	0	0
24	33	0	0	0	0	1	1	0	0	0	0
24	9	100	0	0	89	0	0	0	0	0	0
24	37	0	0	0	2	0	0	0	0	0	0
24	30	0	0	0	0	0	0	0	0	0	0
24	39	0	0	0	0	0	0	0	0	0	0
29	37	50	5	0	29	0	0	0	0	0	0
29	33	0	0	0	0	3	4	0	32	4	0
29	32	21	1	2	10	0	0	0	0	0	0
29	35	0	0	0	0	2	3	0	0	0	0
29	40	0	0	0	0	0	4	0	0	0	0
29	31	0	0	0	0	0	0	0	0	0	0
29	39	66	7	0	30	0	0	0	0	0	0
29	9	10	0	2	8	0	0	0	0	0	0
29	34	0	0	0	0	0	0	0	0	0	0
29	28	100	0	0	60	2	1	0	0	0	0
29	42	30	0	0	12	0	0	0	0	0	0
29	43	45	5	0	16	0	0	0	0	0	0
29	30	0	0	0	1	0	0	0	0	0	0
29	48	0	0	0	0	0	0	0	0	0	0
29	2	0	0	0	0	0	0	0	0	0	0
29	47	23	2	0	12	0	0	0	0	0	0
29	15	0	0	0	6	4	4	0	0	0	0
29	29	0	0	0	0	0	0	0	0	0	0
29	46	4	0	0	7	0	0	0	0	0	0
29	41	20	1	0	12	0	0	0	0	0	0
29	38	55	5	0	33	0	2	0	2	0	1
29	36	0	0	0	0	0	0	0	0	0	0
30	37	50	5	0	29	0	0	0	0	0	0
30	33	0	0	0	0	3	4	0	7	4	0
30	32	21	1	2	10	0	0	0	0	0	0
30	35	0	0	0	0	2	3	0	0	0	0
30	31	0	0	0	0	0	0	0	0	0	0
30	39	66	7	0	30	0	0	0	0	0	0
30	9	10	0	2	8	0	0	0	0	0	0
30	34	0	0	0	0	0	0	0	0	0	0
30	36	0	0	0	0	0	0	0	0	0	0
30	28	100	0	0	60	2	1	0	0	0	0
30	41	20	1	0	12	0	0	0	0	0	0
30	42	30	0	0	12	0	0	0	0	0	0
30	43	45	5	0	16	0	0	0	0	0	0
30	30	0	0	0	1	0	0	0	0	0	0
30	48	0	0	0	0	0	0	0	0	0	0
30	2	0	0	0	0	0	0	0	0	0	0
30	47	23	2	0	12	0	0	0	0	0	0
30	15	0	0	0	6	4	4	0	0	0	0
30	29	0	0	0	0	0	0	0	0	0	0
30	46	4	0	0	7	0	0	0	0	0	0
30	38	55	5	0	33	0	2	0	3	0	1
30	40	0	0	0	0	0	4	0	0	0	0
31	37	50	5	0	29	0	0	0	0	0	0
31	33	0	0	0	0	3	4	0	4	4	0
31	32	21	1	2	10	0	0	0	0	0	0
31	35	0	0	0	0	3	3	0	0	0	0
31	38	55	5	0	33	0	2	0	1	0	1
31	31	0	0	0	0	0	0	0	0	0	0
31	39	66	7	0	30	0	0	0	0	0	0
31	9	10	0	2	8	0	0	0	0	0	0
31	34	0	0	0	0	0	0	0	0	0	0
31	36	0	0	0	0	0	0	0	0	0	0
31	28	100	0	0	60	2	1	0	0	0	0
31	41	20	1	0	12	0	0	0	0	0	0
31	42	30	0	0	12	0	0	0	0	0	0
31	43	45	5	0	16	0	0	0	0	0	0
31	30	30	0	0	14	0	0	0	0	0	0
31	48	0	0	0	0	0	0	0	0	0	0
31	2	0	0	0	0	0	0	0	0	0	0
31	47	23	2	0	12	0	0	0	0	0	0
31	15	0	0	0	6	4	4	0	0	0	0
31	46	4	0	0	7	0	0	0	0	0	0
31	29	0	0	0	0	0	0	0	0	0	0
31	40	0	0	0	0	0	4	0	0	0	0
\.


--
-- Data for Name: team; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.team (teamid, teamname, coachid, captainid, teampicpath, totalwins, totallosses, draws, wicketkeeperid) FROM stdin;
2	Pakistan	103	\N	https://upload.wikimedia.org/wikipedia/commons/a/ad/Pakistan_cricket_team_logo.png	5	7	3	2
1	India	101	30	http://localhost:3000/1703405576663_download.png	16	3	1	46
15	Australia	3	33	http://localhost:3000/1703685280291_screenShot.jpg	2	9	5	9
\.


--
-- Data for Name: teamrank; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.teamrank (teamid, t20irank, odirank, testrank) FROM stdin;
2	3	3	3
1	2	2	4
15	4	4	5
\.


--
-- Data for Name: tournament; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tournament (name, startdate, enddate, winning_team, winningpic, tournamentlogo, tournamentid) FROM stdin;
2023 ODI World Cup	2023-10-05 00:00:00	2023-11-19 00:00:00	1	http://localhost:3000/1703433969390_screenShot.jpg	http://localhost:3000/1703792885392_download.jpeg	3
2015 ODI World Cup	2023-02-14 00:00:00	2023-03-29 00:00:00	2	http://localhost:3000/1703793739554_download (1).jpeg	http://localhost:3000/1703793525700_download.jpeg	1
Asia Cup 2023	2023-12-02 00:00:00	2023-12-29 00:00:00	1	http://localhost:3000/1703795212108_download (1).jpeg	http://localhost:3000/1703791388537_download.jpeg	35
\.


--
-- Data for Name: umpire; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.umpire (umpirename, nomatches, umpirepicpath, countryid, umpireid) FROM stdin;
Kumar Dharmasena	121	http://localhost:3000/1703442812846_screenShot.jpg	17	301
Marais Erasmu	117	http://localhost:3000/1703442867500_unsplash.png	2	302
Faakhir	2	http://localhost:3000/1703572816225_unsplash.png	3	5
Mash	0	http://localhost:3000/1703574451236_screenShot.jpg	1	6
Abdul Rehman memon	31	http://localhost:3000/1703601351493_screenShot.jpg	1	9
Chris Gaffaney	89	http://localhost:3000/1703442886336_profile.jpg	3	303
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (userid, username, userpicpath, userrole, password, datejoined) FROM stdin;
26	abddulrehman	http://localhost:3000/1703943986874_profile.jpg	Admin	12345678	2023-12-30
32	qwerty	http://localhost:3000/1703953654489_screenShot.jpg	tournamentmanager	12345678	2023-12-30
35	check2	http://localhost:3000/1703960047154_unsplash.png	datamanager	12345678	2023-12-30
36	abbas	http://localhost:3000/1704001436796_screenShot.jpg	playermanager	12345678	2023-12-31
\.


--
-- Data for Name: wicketkeeper; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.wicketkeeper (totalcatches, totalstumps, playerid) FROM stdin;
2	0	2
0	0	46
0	4	9
\.


--
-- Name: coach_coachid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.coach_coachid_seq', 7, true);


--
-- Name: country_countryid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.country_countryid_seq', 23, true);


--
-- Name: location_locationid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.location_locationid_seq', 26, true);


--
-- Name: match_matchid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.match_matchid_seq', 34, true);


--
-- Name: player_playerid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.player_playerid_seq', 49, true);


--
-- Name: team_teamid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.team_teamid_seq', 15, true);


--
-- Name: tournament_tournamentid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tournament_tournamentid_seq', 35, true);


--
-- Name: umpire_umpireid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.umpire_umpireid_seq', 10, true);


--
-- Name: users_userid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_userid_seq', 36, true);


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
-- Name: TABLE captain; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.captain TO teammanager;
GRANT ALL ON TABLE public.captain TO admin;
GRANT INSERT ON TABLE public.captain TO datamanager;


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


--
-- Name: TABLE player; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.player TO playermanager;
GRANT ALL ON TABLE public.player TO admin;
GRANT INSERT ON TABLE public.player TO datamanager;


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


--
-- Name: TABLE playerrank; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.playerrank TO admin;
GRANT INSERT ON TABLE public.playerrank TO datamanager;


--
-- Name: TABLE scorecard; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.scorecard TO admin;
GRANT INSERT ON TABLE public.scorecard TO datamanager;


--
-- Name: TABLE team; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.team TO admin;
GRANT INSERT ON TABLE public.team TO datamanager;
GRANT ALL ON TABLE public.team TO teammanager;


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


--
-- Name: TABLE teamrank; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.teamrank TO admin;
GRANT INSERT ON TABLE public.teamrank TO datamanager;


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


--
-- Name: TABLE umpire; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.umpire TO admin;
GRANT ALL ON TABLE public.umpire TO tournamentmanager;
GRANT INSERT ON TABLE public.umpire TO datamanager;


--
-- Name: SEQUENCE umpire_umpireid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public.umpire_umpireid_seq TO abddulrehman;
GRANT ALL ON SEQUENCE public.umpire_umpireid_seq TO admin;
GRANT ALL ON SEQUENCE public.umpire_umpireid_seq TO playermanager;
GRANT ALL ON SEQUENCE public.umpire_umpireid_seq TO teammanager;
GRANT ALL ON SEQUENCE public.umpire_umpireid_seq TO tournamentmanager;
GRANT SELECT ON SEQUENCE public.umpire_umpireid_seq TO qwerty;
GRANT ALL ON SEQUENCE public.umpire_umpireid_seq TO datamanager;
GRANT SELECT ON SEQUENCE public.umpire_umpireid_seq TO check2;
GRANT SELECT ON SEQUENCE public.umpire_umpireid_seq TO abbas;


--
-- Name: TABLE users; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.users TO admin;
GRANT INSERT ON TABLE public.users TO datamanager;


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


--
-- Name: TABLE wicketkeeper; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.wicketkeeper TO teammanager;
GRANT ALL ON TABLE public.wicketkeeper TO admin;
GRANT INSERT ON TABLE public.wicketkeeper TO datamanager;


--
-- PostgreSQL database dump complete
--

