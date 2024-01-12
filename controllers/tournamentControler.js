import asyncHandler from 'express-async-handler';
import db from '../connection/connection.js';

export const getAllTournaments = asyncHandler(async (req, res) => {
    try {
        const result = await db.query('SELECT t.*,team.teamname,team.teampicpath FROM tournament as t left join team on t.winning_team=team.teamID order by t.tournamentId desc');
        res.status(200).json(result.rows);
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const updateTournament = asyncHandler(async (req, res) => {
    try {
        const { tournamentID } = req.params;
        const { tournamentname, startdate, enddate, winningteam, winningpic,winningpicture } = req.body;
        const result = await db.query('UPDATE tournament SET name=$1, winning_team=$2,startdate=$3,enddate=$4,tournamentlogo=$5,winningpic=$6 WHERE tournamentId=$7', [tournamentname, winningteam, startdate, enddate, winningpic,winningpicture, tournamentID]);
        res.status(200).json(result.rows);
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const deleteTournament = asyncHandler(async (req, res) => {
    try {
        const { tournamentID } = req.params;
        //delete all matches of tournament
        // await db.query('DELETE FROM match WHERE tournamentid=$1', [tournamentID]);
        await db.query('DELETE FROM tournament WHERE tournamentId=$1', [tournamentID]);
        res.status(200).json({ message: "deleted" });
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const createTournament = asyncHandler(async (req, res) => {
    try {
        const {tournamentname, startdate, enddate, winningteam,logo, winningpic } = req.body;
        const result = await db.query('INSERT INTO tournament(name,startdate,enddate,winning_team,winningpic,tournamentlogo) VALUES($1,$2,$3,$4,$5,$6)', [tournamentname, startdate, enddate, winningteam, winningpic,logo]);
        res.status(200).json(result.rows);
    } catch (error) {
        console.log(error);
        res.status(500).json({ message: error.message })
    }
})
export const getTournamentMatches = asyncHandler(async (req, res) => {
    try {
        const { tournamentID } = req.params;
        const result = await db.query("select match.*,location.*,t1.teamname as team1,t2.teamname as team2,t3.teamname as winner,t3.teampicpath as winnerpic from match join location on location.locationid=match.locationid join team as t1 on t1.teamid=match.team1id join team as t2 on t2.teamid=match.team2id join team as t3 on match.winnerteam=t3.teamid where tournamentid=$1 order by tournamentid desc", [tournamentID]);
        res.status(200).json(result.rows);
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const getTournamentById = asyncHandler(async (req, res) => {
    try {
        const { tournamentID } = req.params;
        const result = await db.query('SELECT t.*,team.teamname,team.teampicpath FROM tournament as t join team on t.winning_team=team.teamID WHERE t.tournamentId=$1', [tournamentID]);
        res.status(200).json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})