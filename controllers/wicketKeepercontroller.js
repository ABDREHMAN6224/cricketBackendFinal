import asyncHandler from 'express-async-handler';
import db from '../connection/connection.js';
export const createWicketKeeper = asyncHandler(async (req, res) => {
    try {
        const {
            playerid,
            catches,
            stumpings,
        } = req.body;
        const result = await db.query('insert into wicketkeeper(playerid,totalcatches,totalstumps) values($1,$2,$3) returning *', [playerid,  catches, stumpings]);
        res.json(result.rows);
    } catch (error) {
        console.log(error);
        res.status(400).json(error.message);
    }
}
);

export const getWicketKeeper = asyncHandler(async (req, res) => {
    const { player_id } = req.params;
    const result = await db.query('select wk.*,player.*,team.teamname from wicketkeeper as wk join player using(playerID) left join team on wk.playerid=team.wicketkeeperid where playerid=$1', [player_id]);
    res.json(result.rows);
}
);

export const deleteWicketKeeper = asyncHandler(async (req, res) => {
    try {
        const { player_id } = req.params;
        await db.query('delete from wicketkeeper where playerid=$1', [player_id]);
        res.json({ message: 'WicketKeeper deleted successfully' });
    } catch (error) {
        res.status(400).json(error.message);
    }
}
);
export const getAllWicketKeeper = asyncHandler(async (req, res) => {
    const result = await db.query('select wk.*,player.*,team.teamname,country.* from wicketkeeper as wk join player on wk.playerid=player.playerid left join team on wk.playerid=team.wicketkeeperid left join country on player.countryid=country.countryid order by wk.playerid desc');
    res.json(result.rows);
}
);
export const updateWicketKeeper = asyncHandler(async (req, res) => {
    try {
        const { player_id } = req.params;
        const {
            catches,
            stumps,
            playername,
            playerpicpath
        } = req.body;
        await db.query('update player set playername=$1,playerpicpath=$2 where playerid=$3 returning *', [playername, playerpicpath, player_id]);
        const result = await db.query('update wicketkeeper set totalcatches=$1, totalstumps=$2 where playerid=$3 returning *', [catches, stumps, player_id]);
        res.json(result.rows);
    } catch (error) {
        res.status(400).json(error.message);
    }
}
);
