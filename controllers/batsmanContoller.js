import asyncHnalder from "express-async-handler"
import db from "../connection/connection.js"
export const getAllBatsman = asyncHnalder(async (req, res) => {
    try {
        const result = await db.query("select * from player as p left join batsman using (playerID) left join country on country.countryid=p.countryid left join team on p.teamid=team.teamid left join playerrank as r on p.playerid=r.playerid where lower(p.playertype)=$1 order by p.playerid desc", ["batsman"]);
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const getSingleBatsman = asyncHnalder(async (req, res) => {
    try {
        const result = await db.query("select p.*,batsman.*,team.teamname,team.teampicpath,r.*,country.* as team from player as p left join batsman using (playerID) left join country on country.countryid=p.countryid left join team on p.teamid=team.teamid left join playerrank as r on p.playerid=r.playerid where lower(p.playertype)=$1 and p.playerID=$2", ["batsman", req.params.playerId]);
        res.status(200).json(result.rows[0])
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
