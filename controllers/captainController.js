import asyncHandler from 'express-async-handler'
import db from "../connection/connection.js"
export const getAllCaptains = asyncHandler(async (req, res) => {
    try {
        const result = await db.query("select * from captain join player using(playerID) left join team on captain.playerid=team.captainid left join country on player.countryid=country.countryid order by captain.playerid desc");
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const getSingleCaptain = asyncHandler(async (req, res) => {
    try {
        const result = await db.query("select * from captain join player using(playerID) left join team on captain.playerid=team.captainid where playerid=$1", [req.params.captainId]);
        res.status(200).json(result.rows[0])
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const createCaptain = asyncHandler(async (req, res) => {
    try {
        const { playerId,matchesascaptain,totalwins} = req.body;
        const found = await db.query("select * from captain where playerId=$1", [playerId]);
        if (found.rows.length > 0) {
            res.status(400).json({ message: "Captain already exists" })
        } else {
            const result = await db.query("insert into captain(playerid,matchesascaptain,totalwins) Values ($1,$2,$3)", [playerId,matchesascaptain,totalwins]);
            res.status(200).json(result.rows)
        }
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const updateCaptain = asyncHandler(async (req, res) => {
    try {
        const { captainId } = req.params;
        const { matches, wins,name,picpath } = req.body;
        await db.query("update player set playername=$1, playerpicpath=$2 where playerid=$3", [name,picpath, captainId]);
        const result = await db.query("update captain set matchesascaptain=$1, totalwins=$2 where playerid=$3", [matches, wins, captainId]);
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const deleteCaptain = asyncHandler(async (req, res) => {
    try {
        const { captainId } = req.params;
        const result = await db.query("delete from captain where playerid=$1 ", [captainId]);
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})