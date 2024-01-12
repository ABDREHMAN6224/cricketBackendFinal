import asyncHandler from 'express-async-handler'
import db from "../connection/connection.js"
export const createMatch = asyncHandler(async (req, res) => {
    try {
        const {date, location, tournamentId, team1id, team2id, winner, umpire,type} = req.body;
            // if (team1id === team2id) {
            //     return res.status(400).json({ message: "Team1 and Team2 cannot be same" })
            // }
            //check if same match with team1 and team2 exists on same date
            // const match = await db.query("select * from match where date=$1 and ((team1id=$2 and team2id=$3) or (team1id=$3 and team2id=$2))", [date, team1id, team2id]);
            // if (match.rows.length > 0) {
            //     return res.status(400).json({ message: "Match already exists" })
            // }
            //check if tournament exists or not
            // const tournament = await db.query("select * from tournament where tournamentid=$1", [tournamentId]);
            // if (tournament.rows.length === 0) {
            //     return res.status(400).json({ message: "Tournament does not exist" })
            // }
            //check if team1 exists or not
            // const team = await db.query("select * from team where teamid=$1", [team1id]);
            // if (team.rows.length === 0) {
            //     return res.status(400).json({ message: "Team1 does not exist" })
            // }
            //check if team2 exists or not
            // const team2 = await db.query("select * from team where teamid=$1", [team2id]);
            // if (team2.rows.length === 0) {
            //     return res.status(400).json({ message: "Team2 does not exist" })
            // }
            //check if umpire exists or not
            // const ump = await db.query("select * from umpire where umpireid=$1", [umpire]);
            // if (ump.rows.length === 0) {
            //     return res.status(400).json({ message: "Umpire does not exist" })
            // }
            //update umpire matches

            // await db.query("update umpire set nomatches=nomatches+1 where umpireid=$1", [umpire]);

            //update team stats
            // if(winner){

                // if (winner === team1id) {
                //     const r1=await db.query("update team set totalwins=totalwins+1 where teamid=$1 returning *", [team1id]);
                //     await db.query("update team set totallosses=totallosses+1 where teamid=$1", [team2id]);
                //     const captaint1 = await db.query("select captainid from team where teamid=$1", [team1id]);
                //     const captaint2 = await db.query("select captainid from team where teamid=$1", [team2id]);
                //     await db.query("update captain set matchesascaptain=matchesascaptain+1,totalwins=totalwins+1 where playerid=$1", [captaint1.rows[0].captainid]);
                //     await db.query("update captain set matchesascaptain=matchesascaptain+1 where playerid=$1", [captaint2.rows[0].captainid]);
                    
                // }
                // else if (winner === team2id) {
                //     const r1=await db.query("update team set totalwins=totalwins+1 where teamid=$1 returning *", [team2id]);
                //     console.log(r1.rows[0]);
                //     await db.query("update team set totallosses=totallosses+1 where teamid=$1", [team1id]);
                //     const captain = await db.query("select captainid from team where teamid=$1", [team2id]);
                //     await db.query("update captain set matchesascaptain=matchesascaptain+1,totalwins=totalwins+1 where playerid=$1", [captain.rows[0].captainid]);
                //     const captaint2 = await db.query("select captainid from team where teamid=$1", [team1id]);
                //     await db.query("update captain set matchesascaptain=matchesascaptain+1 where playerid=$1", [captaint2.rows[0].captainid]);
                // }
            // }
            // else {
            //     await db.query("update team set draws=draws+1 where teamid=$1", [team1id]);
            //     await db.query("update team set draws=draws+1 where teamid=$1", [team2id]);
            // }
            const resultt = await db.query("insert into match(date,locationid,tournamentid,team1id,team2id,winnerteam,umpire,matchtype) Values ($1,$2,$3,$4,$5,$6,$7,$8) returning *", [date, location, tournamentId, team1id, team2id, winner, umpire,type]);
            //increase mathces played by all player associated with this match
            // totalt20i, totalodi, totaltest
            // if(type==="ODI"){
            //     await db.query("update player set totalodi=totalodi+1 where teamid=$1 or teamid=$2",[team1id,team2id]);
            // }
            // else if(type==="T20"){
            //     await db.query("update player set totalt20i=totalt20i+1 where teamid=$1 or teamid=$2",[team1id,team2id]);
            // }
            // else{
            //     await db.query("update player set totaltest=totaltest+1 where teamid=$1 or teamid=$2",[team1id,team2id]);
            // }
            return res.status(200).json(resultt.rows[0]);
        
    } catch (error) {
        console.log(error);
        return res.status(500).json({ message: error.message })
    }
})
export const getAllMatches = asyncHandler(async (req, res) => {
    try {
        const result = await db.query("select match.*,location.*,umpire.*,t1.teamname as team1,t1.teampicpath as team1pic,t2.teampicpath as team2pic,t2.teamname as team2,t3.teamname as winner,t3.teampicpath as winnerpic,tour.name as tournamentname from match join location on location.locationid=match.locationid join team as t1 on t1.teamid=match.team1id join team as t2 on t2.teamid=match.team2id left join team as t3 on match.winnerteam=t3.teamid join tournament as tour on tour.tournamentid=match.tournamentid join umpire on umpire.umpireid=match.umpire order by match.matchid desc");
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const getSingleMatch = asyncHandler(async (req, res) => {
    try {
        const result = await db.query("select match.*,location.*,umpire.*,t1.teamname as team1,t1.teampicpath as team1pic,t2.teampicpath as team2pic,t2.teamname as team2,t3.teamname as winner,t3.teampicpath as winnerpic,tour.name as tournamentname from match join location on location.locationid=match.locationid join team as t1 on t1.teamid=match.team1id join team as t2 on t2.teamid=match.team2id join team as t3 on match.winnerteam=t3.teamid join tournament as tour on tour.tournamentid=match.tournamentid join umpire on umpire.umpireid=match.umpire where matchid=$1", [req.params.matchId]);
        res.status(200).json(result.rows[0])
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const deleteMatch = asyncHandler(async (req, res) => {
    try {
        const { matchId } = req.params;
        //remove records from scorecard
        await db.query("delete from scorecard where matchid=$1", [matchId]);
        //remove records from match
        const result = await db.query("delete from match where matchid=$1", [matchId]);
        res.status(200).json(result.rows)
    } catch (error) {
        console.log(error);
        res.status(500).json({ message: error.message })
    }
})
export const updateMatch = asyncHandler(async (req, res) => {
    try {
        const { date, location, tournamentId, team1id, team2id, winner, umpire } = req.body;
        const {matchId} = req.params;
        // const tournament = await db.query("select * from tournament where tournamentid=$1", [tournamentId]);
        // if (tournament.rows.length === 0) {
        //     res.status(400).json({ message: "Tournament does not exist" })
        // }
        //check if team1 exists or not
        // const team = await db.query("select * from team where teamid=$1", [team1id]);
        // if (team.rows.length === 0) {
        //     res.status(400).json({ message: "Team1 does not exist" })
        // }
        //check if team2 exists or not
        // const team2 = await db.query("select * from team where teamid=$1", [team2id]);
        // if (team2.rows.length === 0) {
        //     res.status(400).json({ message: "Team2 does not exist" })
        // }
        //check if umpire exists or not
        // const ump = await db.query("select * from umpire where umpireid=$1", [umpire]);
        // if (ump.rows.length === 0) {
        //     res.status(400).json({ message: "Umpire does not exist" })
        // }
        const result = await db.query("update match set date=$1,locationid=$2,tournamentid=$3,team1id=$4,team2id=$5,winnerteam=$6,umpire=$7 where matchid=$8",[date, location, tournamentId, team1id, team2id, winner, umpire,matchId]);
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const getMatchesByTournament = asyncHandler(async (req, res) => {
    try {
        const { tournamentId } = req.params;
        const result = await db.query("select match.*,t1.teamname as team1,t2.teamname as team2 from match join team as t1 on t1.teamid=match.team1id join team as t2 on t2.teamid=match.team2id where tournamentid=$1 order by match.matchid desc", [tournamentId]);
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const getMatchesByTeam = asyncHandler(async (req, res) => {
    try {
        const { teamId } = req.params;
        const result = await db.query("select match.*,t1.teamname as team1,t2.teamname as team2 from match join team as t1 on t1.teamid=match.team1id join team as t2 on t2.teamid=match.team2id where team1id=$1 or team2id=$1 order by match.matchid desc", [teamId]);
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const getMatchesByTwoTeams = asyncHandler(async (req, res) => {
    try {
        const { team1Id, team2Id } = req.params;
        const result = await db.query("select match.*,t1.teamname as team1,t2.teamname as team2 from match join team as t1 on t1.teamid=match.team1id join team as t2 on t2.teamid=match.team2id where team1id=$1 and team2id=$2 order by match.matchid desc", [team1Id, team2Id]);
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const getMatchesByLocation = asyncHandler(async (req, res) => {
    try {
        const { location } = req.params;
        const result = await db.query("select match.*,t1.teamname as team1,t2.teamname as team2 from match join team as t1 on t1.teamid=match.team1id join team as t2 on t2.teamid=match.team2id where location=$1 order by match.matchid desc", [location]);
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
