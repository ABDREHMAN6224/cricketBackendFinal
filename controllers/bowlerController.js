import asyncHnalder from "express-async-handler"
import db from "../connection/connection.js"
export const getAllBolwers = asyncHnalder(async (req, res) => {
    try {
        const result = await db.query("select * from player as p left join bowler on p.playerid=bowler.playerid left join country on country.countryid=p.countryid left join team on p.teamid=team.teamid left join playerrank as r on p.playerID=r.playerID where lower(p.playertype)=$1 order by p.playerid desc",["bowler"]);
        res.status(200).json(result.rows)
    } catch (error) {
        console.log(error);
        res.status(500).json({ message: error.message })
    }
})
export const getSingleBowler = asyncHnalder(async (req, res) => {
    try {
        const result = await db.query("select * from player as p left join bowler on p.playerid=bowler.playerid left join country on country.countryid=p.countryid left join team on p.teamid=team.teamid left join playerrank as r on p.playerID=r.playerID where lower(p.playertype)=$1 and p.playerID=$2", ["bowler", req.params.playerId]);
        res.status(200).json(result.rows[0])
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})