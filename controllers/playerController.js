import asyncHandler from 'express-async-handler';
import db from "../connection/connection.js";

export const getPlayer = asyncHandler(async (req, res) => {
    try {
        const { playerId } = req.params;
        const result = await db.query(`select * from player where playerID=${playerId}`)
        res.status(200).json(result.rows);
    } catch (error) {
        res.status(404).json({ err: "cannot find player" })
    }
})
export const getAllPlayers = asyncHandler(async (req, res) => {
    try {
        const result = await db.query(`select * from player left join playerrank using(playerid) left join country using(countryid)`);
        res.status(200).json(result.rows);
    } catch (error) {
        res.status(404).json({ err: error })
    }
})
export const createPlayer = asyncHandler(async (req, res) => {
    try {
        const { playername, doB, teamid,countryid, totalt20i, totalOdi, totalTest, type, status, picturePath } = req.body;
        console.log(req.body);
        const result = await db.query("insert into player(playername, dob, teamid, totalt20i, totalodi, totaltest, playertype, playerstatus, playerpicpath,countryid) Values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) returning *", [playername, doB,null, totalt20i, totalOdi, totalTest, type, status, picturePath, countryid]);
        //get playerid
        const { playerid } = result.rows[0];
        if (type.toLowerCase() == "batsman" || type.toLowerCase() == "allrounder") {
            const { sixes, fours, totalRuns, bathand, ballsfaced, totalInnings } = req.body;
            // await db.query("insert into batsman Values($1, $2, $3, $4, $5, $6, $7)", [playerid, sixes, fours, totalRuns,bathand, ballsfaced, totalInnings]);
            // update batsman table with playerid with values
            await db.query("update batsman set nosixes=$1, nofours=$2, noruns=$3, bathand=$4, ballsfaced=$5, totalinningsbatted=$6 where playerid=$7", [sixes, fours, totalRuns, bathand, ballsfaced, totalInnings, playerid]);
            
        }
        if (type.toLowerCase() == "bowler" || type.toLowerCase() == "allrounder") {
            const { noOfWickets,bowlhand, bowltype, oversbowled, maidenovers, runsconceded, totalInnings, dotBalls,noballs } = req.body;
        // await db.query("insert into bowler Values($1, $2, $3, $4, $5, $6, $7,$8,$9,$10)", [playerid, noOfWickets, bowlhand, bowltype, oversbowled, maidenovers, runsconceded, totalInnings, dotBalls,noballs]);
        //update bowler table with playerid with values
        await db.query("update bowler set nowickets=$1, bowlhand=$2, bowltype=$3, oversbowled=$4, maidenovers=$5, runsconceded=$6, totalinningsbowled=$7, dotballs=$8, noballsbowled=$9 where playerid=$10", [noOfWickets, bowlhand, bowltype, oversbowled, maidenovers, runsconceded, totalInnings, dotBalls,noballs,playerid]);
        }
        //insert into playerrank
        // const result1 = await db.query("select * from playerrank");
        // let maxBattingRank = Math.max(...result1.rows.map((row) => Number(row.battingrank)))||1;
        // let maxBowlingRank = Math.max(...result1.rows.map((row) => Number(row.bowlingrank)))||1;
        // let maxAllrounderRank = Math.max(...result1.rows.map((row) => Number(row.allrounderrank)))||1;
        // let battingRank = 0, bowlingRank = 0, allrounderRank = 0;
        //     battingRank = maxBattingRank + 1;
        //     bowlingRank = maxBowlingRank + 1;
        //     allrounderRank = maxAllrounderRank + 1;
        // await db.query("insert into playerrank Values ($1, $2, $3, $4)", [playerid, battingRank, bowlingRank, allrounderRank]);
        //check that team has max 11 players

        // const result2 = await db.query("select * from player where teamid=$1", [teamid]);
        // if (result2.rows.length > 11) {
        //     res.status(400).json({ message: "Team already has 11 players" })
        // }

        //check that team has max 5 batsmen
        // const result3 = await db.query("select * from player where teamid=$1 and playertype='batsman'", [teamid]);
        // if (result3.rows.length > 5) {
        //     res.status(400).json({ message: "Team already has 5 batsmen" })
        // }
        // //check that team has max 5 bowlers
        // const result4 = await db.query("select * from player where teamid=$1 and playertype='bowler'", [teamid]);
        // if (result4.rows.length > 5) {
        //     res.status(400).json({ message: "Team already has 5 bowlers" })
        // }
        // //check that team has max 5 allrounders
        // const result5 = await db.query("select * from player where teamid=$1 and playertype='allrounder'", [teamid]);
        // if (result5.rows.length > 5) {
        //     res.status(400).json({ message: "Team already has 5 allrounders" })
        // }

        res.status(200).json(result.rows);
    } catch (error) {
        console.log(error);
        res.status(404).json({ err: error.message })
    }
})
export const deletePlayer = asyncHandler(async (req, res) => {
    try {
        const { playerId } = req.params;
        let {type}=req.body;
        type=type.toLowerCase();
        // //increase ranks of players below him
        // await db.query("update playerrank set battingrank=battingrank-1 where battingrank>$1", [playerId]);
        // await db.query("update playerrank set bowlingrank=bowlingrank-1 where bowlingrank>$1", [playerId]);
        // await db.query("update playerrank set allrounderrank=allrounderrank-1 where allrounderrank>$1", [playerId]);
        // //remove from ranks table
        // await db.query("delete from playerrank where playerid=$1", [playerId]);
        // if(type=="batsman" || type=="allrounder"){
        //     const r=await db.query("delete from batsman where playerid=$1 returning *", [playerId]);
        //     console.log(r.rows);
        // }
        // if(type=="bowler" || type=="allrounder"){
        //     await db.query("delete from bowler where playerid=$1", [playerId]);
        // }
        //set captain id to null where captain id is playerId
        // await db.query("update team set captainid=null where captainid=$1", [playerId]);
        //set wicketkeeper id to null where wicketkeeper id is playerId
        // await db.query("update team set wicketkeeperid=null where wicketkeeperid=$1", [playerId]);
        //remove from captains
        // await db.query("delete from captain where playerid=$1", [playerId]);
        //remove from scorecards
        // await db.query("delete from scorecard where playerid=$1", [playerId]);
        //delete from wicketkeeper
        // await db.query("delete from wicketkeeper where playerid=$1", [playerId]);
        await db.query("delete from player where playerid=$1", [playerId]);
        res.status(200).json({ message: "deleted" });
    } catch (error) {
        console.log(error);
        res.status(404).json({ err: error.message })

    }
})
export const updatePlayer = asyncHandler(async (req, res) => {
    try {
        let { totalT20, totalOdi, totalTest, status, name, type } = req.body;
        type=type.toLowerCase();
        const { playerId } = req.params
        if (type == "batsman" || type == "allrounder") {
            const { hand } = req.body;
            await db.query("update batsman set bathand=$1 where playerid=$2", [hand.charAt(0).toUpperCase() + hand.slice(1), playerId]);
        }
        if (type == "bowler" || type == "allrounder") {
            const { bowlhand, bowltype } = req.body;
            await db.query("update bowler set bowlhand=$1, bowltype=$2 where playerID=$3", [bowlhand.charAt(0).toUpperCase() + bowlhand.slice(1), bowltype, playerId]);
        }
        await db.query("update player set totalt20i=$1,totalodi=$2,totaltest=$3,playerstatus=$4,playername=$5 where playerID=$6", [Number(totalT20), Number(totalOdi), Number(totalTest), status, name, playerId]);
        res.status(200).json({ message: "updated" });
    } catch (error) {
        console.log(error);
        res.status(404).json({ err: error.message })
    }
})

export const updateStats = asyncHandler(async (req, res) => {
    try {
        const { playerId } = req.params
        const { type } = req.body;
        if (type == "batsman" || type == "allrounder") {
            const { sixes, fours, totalRuns, avg, strikeRate, bathand, ballsfaced, totalInnings } = req.body;
            await db.query("update batsman set sixes=$1, fours=$2, totalRuns=$3, avg=$4, strikeRate=$5, bathand=$6, ballsfaced=$7, totalInnings=$8 where playerID=$9", [sixes, fours, totalRuns, avg, strikeRate, bathand, ballsfaced, totalInnings, playerId]);
        }
        if (type == "bowler" || type == "allrounder") {
            const { noOfWickets, economy, bowlStrikerate, bowlhand, bowltype, oversbowled, maidenovers, runsconceded, totalInnings, dotBalls } = req.body;
            await db.query("update bowler set noOfWickets=$1, economy=$2, bowlStrikerate=$3, bowlhand=$4, bowltype=$5, oversbowled=$6, maidenovers=$7, runsconceded=$8, totalInnings=$9, dotBalls=$10 where playerID=$11", [noOfWickets, economy, bowlStrikerate, bowlhand, bowltype, oversbowled, maidenovers, runsconceded, totalInnings, dotBalls, playerId]);
        }
        res.status(200).json({ message: "updated" });
    } catch (error) {
        res.status(404).json({ err: error.message })
    }
})
export const updatePlayerPicture = asyncHandler(async (req, res) => {
    try {
        const { playerId } = req.params
        const { picturePath } = req.body;
        const result = await db.query("update player set playerpicpath=$1 where playerID=$2", [picturePath, playerId]);
        res.status(200).json(result.rows);
    } catch (error) {
        res.status(404).json({ err: error.message })
    }
})
export const getPlayersWithNoTeam = asyncHandler(async (req, res) => {
    try {
        const result = await db.query("select * from player left join country on player.countryid=country.countryid where teamid is null");
        res.status(200).json(result.rows);
    } catch (error) {
        console.log(error);
        res.status(404).json({ err: error.message })
    }
})