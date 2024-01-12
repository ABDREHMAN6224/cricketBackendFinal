import asyncHandler from 'express-async-handler';
import db from "../connection/connection.js";

export const appointCoach = asyncHandler(async (req, res) => {
    try {
        const { teamId } = req.params;
        const { coachId } = req.body;
        // const found = await db.query("select coachid from team where teamID=$1", [teamId]);
        // if (found.rows.length > 0) {
        //     res.status(400).json({ message: "Coach already exists" })
        // } else {
            //check if coach is already assigned to a team
            // const found = await db.query("select teamid from team where coachid=$1", [coachId]);
            // if (found.rows.length > 0) {
            //     res.status(400).json({ message: "Coach already assigned to a team" })
            // } 
            const result = await db.query("update team set coachid=$1 where teamid=$2", [coachId, teamId]);
            res.status(200).json(result.rows)
        // }
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const appointWicketKeeper = asyncHandler(async (req, res) => {
    try {
        const { teamId } = req.params;
        const { wicketKeeperId } = req.body;
        //check if wicketkeeper is already assigned to a team
        const found = await db.query("select teamid from team where wicketkeeperid=$1", [wicketKeeperId]);
        if (found.rows.length > 0) {
            res.status(400).json({ message: "WicketKeeper already assigned to a team" })
        }

        await db.query("update team set wicketkeeperid=$1 where teamid=$2", [wicketKeeperId, teamId]);
        res.status(200).json({ message: "WicketKeeper appointed" })

    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const appointCaptain = asyncHandler(async (req, res) => {
    try {
        const { teamId } = req.params;
        const { captainId } = req.body;
        // const found = await db.query("select captainid from team where teamID=$1", [teamId]);
        // if (found.rows.length > 0) {
        //     res.status(400).json({ message: "Captain already exists" })
        // } else {
            //check if captain is already assigned to a team
            // const found = await db.query("select teamid from team where captainid=$1", [captainId]);
            // if (found.rows.length > 0) {
            //     res.status(400).json({ message: "Captain already assigned to a team" })
            // }
            const result = await db.query("update team set captainid=$1 where teamid=$2", [captainId, teamId]);
            res.status(200).json(result.rows)
        // }
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const getTeamPlayers = asyncHandler(async (req, res) => {
    try {
        const { teamId } = req.params;
        const result = await db.query("select * from player left join country on player.countryid=country.countryid where teamid=$1", [teamId]);
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const getTeamPlayersSquad = asyncHandler(async (req, res) => {
    try {
        const { teamId } = req.params;
        const result = await db.query("select * from player left join country on player.countryid=country.countryid where country.country=$1", [teamId]);
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const createTeam = asyncHandler(async (req, res) => {
    try {
        const { teamName, coachId,captainId,wicketKeeperId, teamLogo,auto } = req.body;
        console.log(req.body);
            //check for empty fields
            // if (!teamName || !coachId || !teamLogo) {
            //    return res.status(400).json({ message: "Please fill all fields" })
            // }
            // //check if coach is already assigned to a team
            // const found = await db.query("select teamid from team where coachid=$1", [coachId]);
            // if (found.rows.length > 0) {
            //    return res.status(400).json({ message: "Coach already assigned to a team" })
            // }
            // //check if captain is already assigned to a team
            // const found2 = await db.query("select teamid from team where captainid=$1", [captainId]);
            // if (found2.rows.length > 0) {
            //    return res.status(400).json({ message: "Captain already assigned to a team" })
            // }
            // //check if wicketkeeper is already assigned to a team
            // const found3 = await db.query("select teamid from team where wicketkeeperid=$1", [wicketKeeperId]);
            // if (found3.rows.length > 0) {
            //    return res.status(400).json({ message: "WicketKeeper already assigned to a team" })
            // }

            const result = await db.query("insert into team(teamname,coachid,captainid,teampicpath,wicketkeeperid) Values ($1,$2,$3,$4,$5) returning *", [teamName, coachId,captainId,teamLogo,wicketKeeperId]);
            const teamId = result.rows[0].teamid;
            //set captain teamid to teamid
            // await db.query("update player set teamid=$1 where playerid=$2", [teamId, captainId]);
            // //set wicketkeeper teamid to teamid
            // await db.query("update player set teamid=$1 where playerid=$2", [teamId, wicketKeeperId]);
            let rank={}
            // if (!auto) {
            //     await db.query("insert into teamrank Values ($1,$2,$3,$4)", [teamId, rank.t20, rank.odi, rank.test]);
            //     await db.query("update teamrank set t20irank=t20irank+1 where t20irank>=$1 and teamid!=$2", [rank.t20i, teamId]);

            //     await db.query("update teamrank set odirank=odirank+1 where odirank>=$1 and teamid!=$2", [rank.odi, teamId]);

            //     await db.query("update teamrank set testrank=testrank+1 where testrank>=$1 and teamid!=$2", [rank.test, teamId]);
            // } else if(auto){
            //     const maxOdirank = await db.query("select max(odirank) from teamrank");
            //     const maxT20rank = await db.query("select max(t20irank) from teamrank");
            //     const maxTestrank = await db.query("select max(testrank) from teamrank");
            //     const maxOdi = maxOdirank.rows[0].max || 1;
            //     const maxT20 = maxT20rank.rows[0].max || 1;
            //     const maxTest = maxTestrank.rows[0].max || 1;
            //     await db.query("insert into teamrank Values ($1,$2,$3,$4)", [teamId, maxT20 + 1, maxOdi + 1, maxTest + 1]);
            // }

           return res.status(200).json(result.rows);
        
    } catch (error) {
        console.log('====================================');
        console.log(error);
        console.log('====================================');
        res.status(500).json({ message: error.message })
    }
})
export const getAllTeams = asyncHandler(async (req, res) => {
    try {
        const result = await db.query("select team.*,coach.coachname,teamrank.*,player.playername as captain,player.playerpicpath as captainpic from team left join coach using(coachid) left join captain on team.captainid=captain.playerid left join teamrank on teamrank.teamid=team.teamid left join player on player.playerid=team.captainid order by team.teamid desc");
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const getTeamById = asyncHandler(async (req, res) => {
    try {
        const { teamId } = req.params;
        const result = await db.query("select team.*,coach.coachname,coach.picture as coachpic,teamrank.*,player.playername as captain,player.playerpicpath as captainpic,wk.playername as keeper,wk.playerpicpath as keeperpic from team left join coach using(coachid) left join captain on team.captainid=captain.playerid left join teamrank on teamrank.teamid=team.teamid left join player on player.playerid=captain.playerid left join wicketkeeper on wicketkeeper.playerid=team.wicketkeeperid left join player as wk on wk.playerid=wicketkeeper.playerid where team.teamid=$1", [teamId]);
        const data = result.rows[0];
        res.status(200).json(data)
    } catch (error) {
        console.log(error.message);
        res.status(500).json({ message: error.message })
    }
})
export const deleteTeam = asyncHandler(async (req, res) => {
    try {
        const { teamId } = req.params;
        //get ranks of current team
        // const ranks = await db.query("select * from teamrank where teamid=$1", [teamId]);
        // const rank = ranks.rows[0];

        // //increase ranks of temas below it
        // if(rank?.t20irank){
        //     await db.query("update teamrank set t20irank=t20irank-1 where t20irank>$1", [rank.t20irank]);
        // }
        // if(rank?.odirank){
        //     await db.query("update teamrank set odirank=odirank-1 where odirank>$1", [rank.odirank]);
        // }
        // if(rank?.testrank){
        //     await db.query("update teamrank set testrank=testrank-1 where testrank>$1", [rank.testrank]);
        // }
        // //remove from ranks table
        // await db.query("delete from teamrank where teamid=$1", [Number(teamId)]);
        // //remove from captains
        // //set teamid to null for players
        // await db.query("update player set teamid=null where teamid=$1", [Number(teamId)]);
        //remove from scorecards
        //delete from team
        //delete all matches of team
        // await db.query("delete from match where team1id=$1 or team2id=$1", [Number(teamId)]);
        const result = await db.query("delete from team where teamid=$1", [Number(teamId)]);
        res.status(200).json(result.rows)
    } catch (error) {
        console.log(error);
        res.status(500).json({ message: error.message })
    }
})
export const updateTeam = asyncHandler(async (req, res) => {
    try {
        const { teamId } = req.params;
        const { teamName, coachId, teamLogo, wicketKeeperId,captainId } = req.body;
        if(!teamId || !teamName || !coachId || !teamLogo||!wicketKeeperId||!captainId){
           return res.status(400).json({ message: "Please fill all fields" })
        }
        await db.query("update team set teamname=$1,coachid=$2,teampicpath=$3,wicketkeeperid=$4,captainid=$5 where teamid=$6", [teamName, coachId, teamLogo, wicketKeeperId,captainId, teamId]);
       return res.status(200).json({ message: "Team updated" })
    } catch (error) {
        console.log(error);
       return res.status(500).json({ message: error.message })
    }
})
export const getWonTournameents = asyncHandler(async (req, res) => {
    try {
        const { teamId } = req.params;
        const result = await db.query("select * from tournament where winning_team=$1 order by tournamentid desc", [teamId]);
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const updatePlayerTeam = asyncHandler(async (req, res) => {
    try {
        let {teamId, playerId} = req.params;
        console.log("teamid",teamId,"playerid",playerId);
        if(teamId==-1){
            teamId=null;
        }
        const result = await db.query("update player set teamid=$1 where playerid=$2", [teamId, playerId]);
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const getTeamMatches = asyncHandler(async (req, res) => {
    try {
        const { teamId } = req.params;
        const result = await db.query("select match.*,location.*,t1.teamname as team1,t2.teamname as team2,t3.teamname as winner,t3.teampicpath as winnerpic from match join location on location.locationid=match.locationid join team as t1 on t1.teamid=match.team1id join team as t2 on t2.teamid=match.team2id join team as t3 on match.winnerteam=t3.teamid where match.team1id=$1 or match.team2id=$1 order by match.matchid desc", [teamId]);
        res.status(200).json(result.rows)
    } catch (error) {
        console.log(error);
        res.status(500).json({ message: error.message })
    }
})