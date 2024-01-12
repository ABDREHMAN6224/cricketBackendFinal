import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import bodyParser from 'body-parser';
import db from './connection/connection.js';
import playerRoutes from "./routers/playerRoutes.js";
import allRounderRoutes from "./routers/allRounderRoutes.js";
import batsmanRoutes from "./routers/batsmanRoutes.js";
import bowlerRoutes from "./routers/bowlerRoutes.js";
import wicketKeeperRoutes from "./routers/wicketKeeperRoutes.js";
import tournamentRoutes from "./routers/tournamentRoutes.js";
import matchRoutes from "./routers/matchRoutes.js";
import captainRoutes from "./routers/captainRoutes.js";
import umpireRoutes from "./routers/umpireRoute.js";
import teamRoutes from "./routers/teamRoutes.js";
import coachRoutes from "./routers/coachRoutes.js";
import scorecardRoutes from "./routers/scorecardRoutes.js";
import rankingRoutes from "./routers/rankRoutes.js";
import locationRoutes from "./routers/locationRoutes.js";
import countryRoutes from "./routers/countryRoutes.js";
import authRoutes from "./routers/authRoutes.js";
import { fileURLToPath } from "url";
import path from "path";
import { uploadFile } from './controllers/uploadFile.js';
import { upload } from './upload.js';
import { data, matches } from './utlis/scrapedData.js';
import dayjs from 'dayjs';
const app = express();
dotenv.config();
const __dirname = path.dirname(fileURLToPath(import.meta.url))
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, "public/")))

db.connect((err) => {
    if (err) {
        console.log('connection error')
    }
    console.log('Connected to database');
})
app.use("/auth", authRoutes);
app.use("/country", countryRoutes);
app.use("/player", playerRoutes);
app.use("/allrounder", allRounderRoutes);
app.use("/batsman", batsmanRoutes);
app.use("/bowler", bowlerRoutes);
app.use("/wicketkeeper", wicketKeeperRoutes);
app.use("/tournament", tournamentRoutes);
app.use("/match", matchRoutes);
app.use("/captain", captainRoutes);
app.use("/umpire", umpireRoutes);
app.use("/team", teamRoutes);
app.use("/coach", coachRoutes);
app.use("/scorecard", scorecardRoutes);
app.use("/rank", rankingRoutes);
app.use("/location", locationRoutes);
app.post("/fileupload", upload.single("file"), uploadFile);


app.get("/", (req, res) => {
    res.json(data)
});

app.get("/populateKeeper",async (req, res) => {
    // query to loop over scraped data and insert into database player table
    data.forEach(async (teamPlayersObj) => {
        let team=Object.keys(teamPlayersObj)[0];
        console.log("Start of team "+team+"............");
        //iterate over team players
        teamPlayersObj[team].forEach(async (playerObj) => {
            if(playerObj?.playername==null){
                return;
            }
            let {dob,playertype,bathand,bowlhand,bowltype,playerpicpath,playername}=playerObj;
            //remove "\n" from all the fields if present
            dob=dob.replace("\n","").trim();
            playertype=playertype.replace("\n","").trim();
            bathand=bathand.replace("\n","").trim();
            bowlhand=bowlhand.replace("\n","").trim();
            bowltype=bowltype.replace("\n","").trim();
            playerpicpath=playerpicpath.replace("\n","").trim();
            playername=playername.replace("\n","").trim();

            if(playertype.trim().toLowerCase().includes("wicket")){
                let playerid=await db.query("select playerid from player where playername=$1",[playername]);
                if(playerid.rows.length==0){
                    return;
                }
                playerid=playerid.rows[0].playerid;
                await db.query("insert into wicketkeeper(playerid,totalcatches,totalstumps) Values ($1, $2, $3) returning *", [playerid, 0, 0]);
            }
            
        })
        console.log("End of team "+team+"............");
        console.log("---------------------------------");

    });
    res.json(data);
});
app.get("/populatePlayers",async (req, res) => {
    // query to loop over scraped data and insert into database player table
    // await db.query("insert into player(playername, dob, teamid, totalt20i, totalodi, totaltest, playertype, playerstatus, playerpicpath,countryid) Values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) returning *", [playername, doB, null, totalt20i, totalOdi, totalTest, type, status, picturePath, countryid]);
    const totalODi=0;
    const totalTest=0;
    const totalT20i=0;
    const status="active";
    let countryid;
    data.forEach(async (teamPlayersObj) => {
        let team=Object.keys(teamPlayersObj)[0];
        console.log("Start of team "+team+"............");
        //iterate over team players
        teamPlayersObj[team].forEach(async (playerObj) => {
            if(playerObj?.playername==null){
                return;
            }
            let {dob,playertype,bathand,bowlhand,bowltype,playerpicpath,playername}=playerObj;
            //remove "\n" from all the fields if present
            dob=dob.replace("\n","").trim();
            playertype=playertype.replace("\n","").trim();
            bathand=bathand.replace("\n","").trim();
            bowlhand=bowlhand.replace("\n","").trim();
            bowltype=bowltype.replace("\n","").trim();
            playerpicpath=playerpicpath.replace("\n","").trim();
            playername=playername.replace("\n","").trim();

            let countryResult = await db.query("select countryid from country where lower(country)=$1", [team.toLowerCase()]);
            if (countryResult.rows.length == 0) {
                await db.query("insert into country(country) Values ($1) returning *", [team]);
                countryResult = await db.query("select countryid from country where lower(country)=$1", [team.toLowerCase()]);
            }
            countryid = countryResult.rows[0].countryid;
            if(playertype.trim().toLowerCase().includes("wicket")){
                playertype="batsman";
            }
            if(playertype.trim().includes("rounder")){
                playertype="allrounder";
            }
            const result = await db.query("insert into player(playername, dob, teamid, totalt20i, totalodi, totaltest, playertype, playerstatus, playerpicpath,countryid) Values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) returning *", [playername, dob, null, totalT20i, totalODi, totalTest, playertype, status, playerpicpath.slice(0,254), countryid]);
            console.log("Player "+playername+" inserted into database");
            if (playertype.trim().includes("allrounder")) {
                await db.query("update batsman set bathand=$1 where playerid=$2", [bathand,result.rows[0].playerid]);
            }
            if (playertype.trim().includes("allrounder")) {
                // 'fast', 'medium', 'leg-spin', 'off-spin'
                if (bowltype.includes("off")){
                    bowltype="off-spin";
                }
                else if (bowltype.includes("leg")){
                    bowltype="leg-spin";
                }
                else if ( bowltype.includes("fast")){
                    bowltype="fast";
                }
                else if (bowltype.includes("medium")){
                    bowltype="medium";
                }
                else{
                    bowltype="medium";
                }
                if(bowlhand.trim()=="Right"){
                    bowlhand="right";
                }
                else if(bowlhand.trim()=="Left"){
                    bowlhand="left";
                }
                else{
                    bowlhand="right";
                }
                await db.query("update bowler set bowlhand=$1, bowltype=$2 where playerid=$3", [bowlhand,bowltype,result.rows[0].playerid]);
            }
        })
        console.log("End of team "+team+"............");
        console.log("---------------------------------");

    });
    res.json(data);
});

app.get("/populateMatches",async (req, res) => {
    matches.forEach(async (matchObj) => {
        let moveToNext=false;
        let {team1,team2,date,matchType,tournamentid,location,winnerteam,scorecard}=matchObj;
        tournamentid=Number(tournamentid);
        console.log("Start of match "+team1+" vs "+team2+"............");
        team2=team2.split(",")[0];
        // remove "\n" from all the fields if present
        team1=team1.replace("\n","").trim();
        team2=team2.replace("\n","").trim();
        location=location.replace("\n","").trim();
        date=date.replace("\n","").trim();
        // "Oct 05, Thu" convert to 2021-10-05
        //date is in string format
        let month=date.split(" ")[0];
        let year=2023;
        let day=date?.split(" ")[1]?.split(",")[0];
        date=year+"-"+month+"-"+day;

        date=dayjs(date).format('YYYY-MM-DD');
        if(date==null || date==undefined || date=="" || typeof date=="undefined" || date=="Invalid Date"){
            //assign random date between 2023-10-01 and 2023-11-30
            let randomMonth=Math.floor(Math.random() * 2) + 10;
            let randomDay=Math.floor(Math.random() * 30) + 1;
            date=2023+"-"+randomMonth+"-"+randomDay;
            date=dayjs(date).format('YYYY-MM-DD');
        }
        console.log("Date "+date);
        let matchtype=matchType.replace("\n","").trim();
        winnerteam=winnerteam.replace("\n","").trim();
        
        let team1id=await db.query("select teamid from team where lower(teamname)=$1",[`${team1.toLowerCase()}`]);
        let team2id=await db.query("select teamid from team where lower(teamname)=$1",[`${team2.toLowerCase()}`]);
        if(team1id.rows.length==0 || team2id.rows.length==0){
            return;
        }
        team1id=team1id.rows[0].teamid;
        team2id=team2id.rows[0].teamid;
        //find winnerteamid
        let winnerteamid=await db.query("select teamid from team where lower(teamname) like $1",[`${winnerteam.toLowerCase()}`]);
        winnerteamid=winnerteamid.rows[0].teamid;
        //check if location exists is location table, if not insert and get locationid
        let locationid=await db.query("select locationid from location where lower(location)=$1",[location.toLowerCase()]);
        if(locationid.rows.length==0){
            location=await db.query("insert into location(location) Values ($1) returning *", [location]);
            locationid=location.rows[0].locationid;
            locationid=await db.query("select locationid from location where locationid=$1",[locationid]);
        }
        locationid=locationid.rows[0].locationid;
        //     //select random umpireid from umpire table
        let umpireid=await db.query("select umpireid from umpire order by random() limit 1");
        umpireid=umpireid.rows[0].umpireid;
        const match=await db.query("insert into match(team1id,team2id,date,matchtype,tournamentid,locationid,winnerteam,umpire) Values ($1, $2, $3, $4, $5, $6, $7, $8) returning *", [team1id,team2id,date,matchtype,tournamentid,locationid,winnerteamid,umpireid]);
        console.log("Match inserted into database"+team1+" vs "+team2);

        const playerNames=Object.keys(scorecard);
        playerNames.forEach(async (playerName) => {
            let {noruns,noballsfaced,nofours,nosixes,nowickets,oversbowled,maidenovers,runsconceded,extras,noballs}=scorecard[playerName];
            noruns=Number(noruns);
            noballsfaced=Number(noballsfaced);
            nofours=Number(nofours);
            nosixes=Number(nosixes);
            nowickets=Number(nowickets);
            oversbowled=Number(oversbowled);
            maidenovers=Number(maidenovers);
            runsconceded=Number(runsconceded);
            extras=Number(extras);
            noballs=Number(noballs);
            noruns=Math.floor(noruns)
            noballsfaced=Math.floor(noballsfaced)
            nofours=Math.floor(nofours)
            nosixes=Math.floor(nosixes)
            nowickets=Math.floor(nowickets)
            oversbowled=Math.floor(oversbowled)
            maidenovers=Math.floor(maidenovers)
            runsconceded=Math.floor(runsconceded)
            extras=Math.floor(extras)
            noballs=Math.floor(noballs)              
            let name=playerName
            if(playerName.includes("(")){ 
            name=playerName.split("(")[0].trim();
    }
                let playerid = await db.query("select playerid from player where lower(playername) like $1", [`%${playerName.toLowerCase()}%`]);
                if(playerid.rows.length==0){
                    return;
                }
                playerid=playerid.rows[0].playerid;
            try {
                
                await db.query("insert into scorecard(matchid,playerid,noruns,noballsfaced,nofours,nosixes,nowickets,oversbowled,maidenovers,runsconceded,extras,noballs) Values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10,$11,$12) returning *", [match.rows[0].matchid,playerid,noruns,noballsfaced,nofours,nosixes,nowickets,oversbowled,maidenovers,runsconceded,extras,noballs]);
                console.log("Scorecard inserted into database for player "+playerName);
            } catch (error) {
                console.log(error);
            }
        });
    });
    return res.json(matches);
})

const port = process.env.PORT || 3000;
app.listen(port, () => {
    console.log(`App running on port ${port}.`);
});
