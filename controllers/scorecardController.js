import asyncHandler from 'express-async-handler'
import db from "../connection/connection.js"

export const getPlayerInnings = asyncHandler(async (req, res) => {
    const { player_id } = req.params
    const query = "select s.*,player.playername,t.teamname,op1.teamname as op1,op2.teamname as op2 from scorecard as s join player using(playerID) left join team as t on t.teamID=player.teamID join match as m on m.matchid=s.matchid join team as op1 on op1.teamid=m.team1id join team as op2 on op2.teamid=m.team2id where playerid=$1"
    const result = await db.query(query, [player_id])
    res.json(result.rows)
})


export const getMatchScorecard = asyncHandler(async (req, res) => {
    try{

        const { match_id } = req.params
        const result = await db.query("select s.*,pl.* from scorecard as s left join player as pl using(playerID) where matchid=$1", [match_id])
        return res.status(200).json(result.rows)
    }catch(error){
        console.log(error);
        res.status(400).json(error.message)
    }
})

export const addRecord = asyncHandler(async (req, res) => {
    try {
        const {match_id,player_id}=req.params;
        const {runs, sixes, fours, balls, wickets, overs, maiden_overs, runs_given, extras, teamid, playertype,catches,stumps,isKeeper,noballs } = req.body;
        const result = await db.query("insert into scorecard values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) returning *", [match_id, player_id, runs, sixes, fours, balls, wickets, overs, maiden_overs, runs_given, extras,noballs]);
        // if (playertype === "Batsman" || playertype === "Allrounder") {
        //     const r=await db.query("update batsman set noruns=noruns+$1, nosixes=nosixes+$2, nofours=nofours+$3, ballsfaced=ballsfaced+$4, totalinningsbatted=totalinningsbatted+1 where playerid=$5 returning *", [runs, sixes, fours, balls, player_id]);
        // }
            //update avergae and strike rate in batsamn table
            
        // if (playertype === "Bowler" || playertype === "Allrounder") {
        //    const r= await db.query("update bowler set nowickets=nowickets+$1, oversbowled=oversbowled+$2, maidenovers=maidenovers+$3, runsconceded=runsconceded+$4, totalinningsbowled=totalinningsbowled+1,noballsbowled=noballsbowled+$5 where playerid=$6 returning *", [wickets, overs, maiden_overs, runs_given,balls, player_id]);
        // }
            //update economy rate in bowler table
            
            //updat ebowlstrikerate
        if(isKeeper){
        
            await db.query("update wicketkeeper set totalcatches=totalcatches+$1, totalstumps=totalstumps+$2 where playerid=$3",[catches,stumps,player_id]);
        }
        return res.json(result.rows)
    } catch (error) {
        console.log(error);
        res.status(400).json(error.message)
    }
})

export const deleteRecord = asyncHandler(async (req, res) => {
    try {
        const { match_id, player_id } = req.params;
        await db.query("delete from scorecard where match_id=$1 and playerid=$2", [match_id, player_id]);
        res.json({ message: "Record deleted" })
    } catch (error) {
        res.status(400).json(error.message)
    }
})